import csv
import io
import uuid
from datetime import datetime, date, timezone
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func, desc, cast, String
from sqlalchemy.orm import aliased

from app.db.session import get_db
from app.core.dependencies import get_current_user, require_super_admin
from app.models.user import User
from app.models.customer import Customer
from app.models.delivery_partner import DeliveryPartner
from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus, DeliveryAssignmentHistory
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus, SubscriptionDeliveryHistory
from app.models.subscription import Subscription, SubscriptionItem, SubscriptionStatus
from app.models.product import Product
from app.models.address import Address
from app.schemas.admin_deliveries import (
    AdminDeliveryListItem,
    AdminDeliveryDetail,
    AdminDeliveryCustomer,
    AdminDeliveryPartner,
    AdminDeliveryAddress,
    AdminDeliveryProduct,
    AdminDeliveryTimelineStep,
    AdminDeliveryAssignmentLog,
    AdminDeliveryStatusUpdate,
    AdminDeliveryAssignRequest,
    AdminDeliveryAnalytics
)
from app.schemas.common import MessageResponse
from app.services import subscription_engine
from app.services.notification_service import NotificationService

router = APIRouter(prefix="/admin/deliveries", tags=["Admin Deliveries"])

# Alias Users to avoid joins collision
CustomerUser = aliased(User, name="customer_user")
PartnerUser = aliased(User, name="partner_user")


async def get_filtered_deliveries_query(
    selected_date: Optional[date] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    status: Optional[str] = None,
    delivery_partner_id: Optional[uuid.UUID] = None,
    search: Optional[str] = None,
):
    stmt = (
        select(
            SubscriptionDelivery,
            Subscription,
            Customer,
            CustomerUser,
            DeliveryAssignment,
            DeliveryPartner,
            PartnerUser,
            Address,
        )
        .join(Subscription, Subscription.id == SubscriptionDelivery.subscription_id)
        .join(Customer, Customer.id == Subscription.customer_id)
        .join(CustomerUser, CustomerUser.id == Customer.user_id)
        .outerjoin(Address, Address.id == Subscription.address_id)
        .outerjoin(DeliveryAssignment, DeliveryAssignment.subscription_delivery_id == SubscriptionDelivery.id)
        .outerjoin(DeliveryPartner, DeliveryPartner.id == DeliveryAssignment.delivery_partner_id)
        .outerjoin(PartnerUser, PartnerUser.id == DeliveryPartner.user_id)
    )

    # Date filters
    if start_date and end_date:
        stmt = stmt.where(SubscriptionDelivery.scheduled_date.between(start_date, end_date))
    elif selected_date:
        stmt = stmt.where(SubscriptionDelivery.scheduled_date == selected_date)
    else:
        stmt = stmt.where(SubscriptionDelivery.scheduled_date == date.today())

    # Status filter
    if status:
        if status == "failed":
            db_status = "missed"
        elif status == "cancelled":
            db_status = "skipped"
        else:
            db_status = status
        stmt = stmt.where(SubscriptionDelivery.status == db_status)

    # Delivery Partner ID filter
    if delivery_partner_id:
        stmt = stmt.where(DeliveryAssignment.delivery_partner_id == delivery_partner_id)

    # Search filter
    if search:
        stmt = stmt.where(
            or_(
                cast(SubscriptionDelivery.id, String).ilike(f"%{search}%"),
                cast(Subscription.id, String).ilike(f"%{search}%"),
                CustomerUser.full_name.ilike(f"%{search}%"),
                PartnerUser.full_name.ilike(f"%{search}%"),
            )
        )

    stmt = stmt.order_by(SubscriptionDelivery.scheduled_date.desc(), SubscriptionDelivery.created_at.desc())
    return stmt


@router.get("/", response_model=List[AdminDeliveryListItem])
async def list_deliveries(
    selected_date: Optional[date] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    status: Optional[str] = Query(None),
    delivery_partner_id: Optional[uuid.UUID] = Query(None),
    search: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    """List deliveries for selected date or range with search and filters."""
    query = await get_filtered_deliveries_query(
        selected_date=selected_date,
        start_date=start_date,
        end_date=end_date,
        status=status,
        delivery_partner_id=delivery_partner_id,
        search=search,
    )
    result = await db.execute(query)
    rows = result.all()

    items = []
    for row in rows:
        deliv, sub, cust, c_user, assign, partner, p_user, addr = row

        # Build address label
        addr_str = "No address provided"
        if addr:
            addr_str = f"{addr.address_line1}"
            if addr.address_line2:
                addr_str += f", {addr.address_line2}"
            addr_str += f", {addr.city} - {addr.pincode}"

        pay_status = "Paid" if sub.status in [SubscriptionStatus.ACTIVE, SubscriptionStatus.COMPLETED] else "Pending"

        items.append(AdminDeliveryListItem(
            id=deliv.id,
            order_type="subscription",
            subscription_id=sub.id,
            fruit_order_id=None,
            customer_name=c_user.full_name,
            phone=c_user.phone,
            delivery_partner_id=partner.id if partner else None,
            delivery_partner_name=p_user.full_name if p_user else None,
            delivery_partner_phone=p_user.phone if p_user else None,
            delivery_address=addr_str,
            scheduled_date=deliv.scheduled_date,
            delivery_time=sub.preferred_delivery_time,
            amount=float(sub.price_per_delivery) if sub.price_per_delivery is not None else 0.0,
            payment_status=pay_status,
            status=deliv.status.value if hasattr(deliv.status, "value") else str(deliv.status),
            item_summary="Subscription Package",
        ))

    from app.models.fruit import FruitOrder, FruitOrderStatus
    fruit_stmt = (
        select(
            FruitOrder,
            Customer,
            CustomerUser,
            DeliveryAssignment,
            DeliveryPartner,
            PartnerUser,
            Address,
        )
        .join(Customer, Customer.id == FruitOrder.customer_id)
        .join(CustomerUser, CustomerUser.id == Customer.user_id)
        .outerjoin(Address, Address.id == FruitOrder.address_id)
        .outerjoin(DeliveryAssignment, DeliveryAssignment.fruit_order_id == FruitOrder.id)
        .outerjoin(DeliveryPartner, DeliveryPartner.id == DeliveryAssignment.delivery_partner_id)
        .outerjoin(PartnerUser, PartnerUser.id == DeliveryPartner.user_id)
    )

    if start_date and end_date:
        fruit_stmt = fruit_stmt.where(FruitOrder.delivery_date.between(start_date, end_date))
    elif selected_date:
        fruit_stmt = fruit_stmt.where(FruitOrder.delivery_date == selected_date)
    else:
        fruit_stmt = fruit_stmt.where(FruitOrder.delivery_date == date.today())

    if status:
        if status in ("failed", "missed", "cancelled", "skipped"):
            fruit_status = "cancelled"
        else:
            fruit_status = status
            
        try:
            valid_status = FruitOrderStatus(fruit_status)
            fruit_stmt = fruit_stmt.where(FruitOrder.order_status == valid_status)
        except ValueError:
            fruit_stmt = fruit_stmt.where(False)

    if delivery_partner_id:
        fruit_stmt = fruit_stmt.where(DeliveryAssignment.delivery_partner_id == delivery_partner_id)

    if search:
        fruit_stmt = fruit_stmt.where(
            or_(
                cast(FruitOrder.id, String).ilike(f"%{search}%"),
                FruitOrder.order_number.ilike(f"%{search}%"),
                CustomerUser.full_name.ilike(f"%{search}%"),
                PartnerUser.full_name.ilike(f"%{search}%"),
            )
        )

    fruit_stmt = fruit_stmt.order_by(FruitOrder.delivery_date.desc().nulls_last(), FruitOrder.created_at.desc())
    fruit_res = await db.execute(fruit_stmt)
    fruit_rows = fruit_res.all()

    for row in fruit_rows:
        f_order, cust, c_user, assign, partner, p_user, addr = row

        addr_str = "No address provided"
        if addr:
            addr_str = f"{addr.address_line1}"
            if addr.address_line2:
                addr_str += f", {addr.address_line2}"
            addr_str += f", {addr.city} - {addr.pincode}"

        pay_status = "Paid" if f_order.payment_status.value == "paid" else "Pending"

        items.append(AdminDeliveryListItem(
            id=f_order.id,
            order_type="fruit",
            subscription_id=None,
            fruit_order_id=f_order.id,
            customer_name=c_user.full_name,
            phone=c_user.phone,
            delivery_partner_id=partner.id if partner else None,
            delivery_partner_name=p_user.full_name if p_user else None,
            delivery_partner_phone=p_user.phone if p_user else None,
            delivery_address=addr_str,
            scheduled_date=f_order.delivery_date or f_order.created_at.date(),
            delivery_time=f_order.delivery_slot or "Standard",
            amount=float(f_order.total_amount),
            payment_status=pay_status,
            status=f_order.order_status.value if hasattr(f_order.order_status, "value") else str(f_order.order_status),
            item_summary=f"Fruit Order #{f_order.order_number}",
        ))

    # Re-sort combined list by date desc
    items.sort(key=lambda x: x.scheduled_date, reverse=True)

    return items


@router.get("/analytics", response_model=AdminDeliveryAnalytics)
async def get_analytics(
    selected_date: Optional[date] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    """Get summarized analytics for the selected date or range."""
    base_filters = []
    if start_date and end_date:
        base_filters.append(SubscriptionDelivery.scheduled_date.between(start_date, end_date))
    elif selected_date:
        base_filters.append(SubscriptionDelivery.scheduled_date == selected_date)
    else:
        base_filters.append(SubscriptionDelivery.scheduled_date == date.today())

    # 1. Counts by status
    status_counts_stmt = (
        select(SubscriptionDelivery.status, func.count(SubscriptionDelivery.id))
        .where(and_(*base_filters))
        .group_by(SubscriptionDelivery.status)
    )
    result = await db.execute(status_counts_stmt)
    status_map = {row[0]: row[1] for row in result.all()}

    # Map database statuses to analytics
    delivered = status_map.get(DeliveryStatus.DELIVERED, 0)
    pending = status_map.get(DeliveryStatus.PENDING, 0)
    assigned = status_map.get(DeliveryStatus.ASSIGNED, 0)
    out_for_delivery = status_map.get(DeliveryStatus.OUT_FOR_DELIVERY, 0)
    failed = status_map.get(DeliveryStatus.MISSED, 0)
    cancelled = status_map.get(DeliveryStatus.SKIPPED, 0)
    carry_forward = status_map.get(DeliveryStatus.CARRY_FORWARD, 0)

    # Let's count carry forwards as pending or separate, let's include it in total
    total = sum(status_map.values())

    # Success rate
    total_completed = delivered + failed
    success_rate = (delivered / total_completed * 100) if total_completed > 0 else 0.0

    # 2. Average delivery time in minutes (out_at to delivered_at)
    time_stmt = (
        select(DeliveryAssignment.out_at, DeliveryAssignment.delivered_at)
        .join(SubscriptionDelivery, SubscriptionDelivery.id == DeliveryAssignment.subscription_delivery_id)
        .where(
            and_(
                *base_filters,
                SubscriptionDelivery.status == DeliveryStatus.DELIVERED,
                DeliveryAssignment.out_at != None,
                DeliveryAssignment.delivered_at != None,
            )
        )
    )
    time_res = await db.execute(time_stmt)
    time_rows = time_res.all()
    total_minutes = 0.0
    count_deliveries = 0
    for out_at, del_at in time_rows:
        if out_at and del_at:
            diff = (del_at - out_at).total_seconds() / 60.0
            if diff > 0:
                total_minutes += diff
                count_deliveries += 1
    avg_time = (total_minutes / count_deliveries) if count_deliveries > 0 else 0.0

    # 3. Top performing delivery partner name
    top_partner_stmt = (
        select(PartnerUser.full_name, func.count(DeliveryAssignment.id))
        .join(DeliveryPartner, DeliveryPartner.id == DeliveryAssignment.delivery_partner_id)
        .join(PartnerUser, PartnerUser.id == DeliveryPartner.user_id)
        .join(SubscriptionDelivery, SubscriptionDelivery.id == DeliveryAssignment.subscription_delivery_id)
        .where(
            and_(
                *base_filters,
                SubscriptionDelivery.status == DeliveryStatus.DELIVERED,
            )
        )
        .group_by(PartnerUser.full_name)
        .order_by(desc(func.count(DeliveryAssignment.id)))
        .limit(1)
    )
    top_res = await db.execute(top_partner_stmt)
    top_row = top_res.first()
    top_partner_name = top_row[0] if top_row else None

    return AdminDeliveryAnalytics(
        total_deliveries=total,
        delivered=delivered,
        pending=pending + carry_forward,  # combine carry forward into pending
        assigned=assigned,
        out_for_delivery=out_for_delivery,
        failed=failed,
        cancelled=cancelled,
        success_rate=round(success_rate, 2),
        average_delivery_time=round(avg_time, 2),
        top_partner_name=top_partner_name,
    )


@router.get("/export")
async def export_deliveries(
    format: str = Query("csv", description="Format: csv or excel"),
    selected_date: Optional[date] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    status: Optional[str] = Query(None),
    delivery_partner_id: Optional[uuid.UUID] = Query(None),
    search: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    """Export filtered deliveries as Excel or CSV."""
    query = await get_filtered_deliveries_query(
        selected_date=selected_date,
        start_date=start_date,
        end_date=end_date,
        status=status,
        delivery_partner_id=delivery_partner_id,
        search=search,
    )
    result = await db.execute(query)
    rows = result.all()

    headers = [
        "Order ID", "Customer Name", "Phone", "Delivery Partner", "Partner Phone",
        "Address", "Scheduled Date", "Delivery Time", "Amount (₹)", "Payment Status", "Delivery Status"
    ]

    export_rows = []
    for row in rows:
        deliv, sub, cust, c_user, assign, partner, p_user, addr = row

        addr_str = f"{addr.address_line1}"
        if addr.address_line2:
            addr_str += f", {addr.address_line2}"
        addr_str += f", {addr.city} - {addr.pincode}"

        pay_status = "Paid" if sub.status in [SubscriptionStatus.ACTIVE, SubscriptionStatus.COMPLETED] else "Pending"
        partner_name = p_user.full_name if p_user else "Unassigned"
        partner_phone = p_user.phone if p_user else ""

        export_rows.append([
            str(sub.id),
            c_user.full_name,
            c_user.phone,
            partner_name,
            partner_phone,
            addr_str,
            deliv.scheduled_date.isoformat(),
            sub.preferred_delivery_time or "",
            f"{sub.price_per_delivery:.2f}" if sub.price_per_delivery is not None else "0.00",
            pay_status,
            deliv.status.value if hasattr(deliv.status, "value") else str(deliv.status)
        ])

    if format == "excel":
        from openpyxl import Workbook
        wb = Workbook()
        ws = wb.active
        ws.title = "Deliveries"

        ws.append(headers)
        for r in export_rows:
            ws.append(r)

        stream = io.BytesIO()
        wb.save(stream)
        stream.seek(0)
        return StreamingResponse(
            stream,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": "attachment; filename=deliveries.xlsx"}
        )
    else:
        stream = io.StringIO()
        writer = csv.writer(stream)
        writer.writerow(headers)
        writer.writerows(export_rows)

        response = StreamingResponse(
            io.BytesIO(stream.getvalue().encode("utf-8")),
            media_type="text/csv"
        )
        response.headers["Content-Disposition"] = "attachment; filename=deliveries.csv"
        return response


@router.get("/{id}", response_model=AdminDeliveryDetail)
async def get_delivery_details(
    id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    """Retrieve detailed view of a single delivery with timeline and history."""
    stmt = (
        select(
            SubscriptionDelivery,
            Subscription,
            Customer,
            CustomerUser,
            DeliveryAssignment,
            DeliveryPartner,
            PartnerUser,
            Address,
        )
        .join(Subscription, Subscription.id == SubscriptionDelivery.subscription_id)
        .join(Customer, Customer.id == Subscription.customer_id)
        .join(CustomerUser, CustomerUser.id == Customer.user_id)
        .join(Address, Address.id == Subscription.address_id)
        .outerjoin(DeliveryAssignment, DeliveryAssignment.subscription_delivery_id == SubscriptionDelivery.id)
        .outerjoin(DeliveryPartner, DeliveryPartner.id == DeliveryAssignment.delivery_partner_id)
        .outerjoin(PartnerUser, PartnerUser.id == DeliveryPartner.user_id)
        .where(SubscriptionDelivery.id == id)
    )
    result = await db.execute(stmt)
    row = result.first()
    
    if not row:
        # Check if it's a Fruit Order
        from app.models.fruit import FruitOrder, FruitOrderItem, Fruit
        fruit_stmt = (
            select(
                FruitOrder,
                Customer,
                CustomerUser,
                DeliveryAssignment,
                DeliveryPartner,
                PartnerUser,
                Address,
            )
            .join(Customer, Customer.id == FruitOrder.customer_id)
            .join(CustomerUser, CustomerUser.id == Customer.user_id)
            .outerjoin(Address, Address.id == FruitOrder.address_id)
            .outerjoin(DeliveryAssignment, DeliveryAssignment.fruit_order_id == FruitOrder.id)
            .outerjoin(DeliveryPartner, DeliveryPartner.id == DeliveryAssignment.delivery_partner_id)
            .outerjoin(PartnerUser, PartnerUser.id == DeliveryPartner.user_id)
            .where(FruitOrder.id == id)
        )
        fruit_res = await db.execute(fruit_stmt)
        f_row = fruit_res.first()
        if not f_row:
            raise HTTPException(status_code=404, detail="Delivery not found")
        
        f_order, cust, c_user, assign, partner, p_user, addr = f_row

        customer_detail = AdminDeliveryCustomer(
            id=cust.id,
            full_name=c_user.full_name,
            phone=c_user.phone,
            email=c_user.email,
            customer_code=cust.customer_code
        )

        partner_detail = None
        if partner and p_user:
            partner_detail = AdminDeliveryPartner(
                id=partner.id,
                full_name=p_user.full_name,
                phone=p_user.phone,
                employee_code=partner.employee_code,
                vehicle_type=partner.vehicle_type.value if hasattr(partner.vehicle_type, "value") and partner.vehicle_type else str(partner.vehicle_type or ""),
                vehicle_number=partner.vehicle_number
            )

        address_detail = AdminDeliveryAddress(
            id=addr.id if addr else uuid.uuid4(),
            address_line1=addr.address_line1 if addr else "No Address",
            address_line2=addr.address_line2 if addr else None,
            city=addr.city if addr else "",
            state=addr.state if addr else "",
            pincode=addr.pincode if addr else "",
            latitude=float(addr.latitude) if addr and addr.latitude else None,
            longitude=float(addr.longitude) if addr and addr.longitude else None,
        )

        f_items_stmt = select(FruitOrderItem, Fruit).join(Fruit, Fruit.id == FruitOrderItem.fruit_id).where(FruitOrderItem.order_id == f_order.id)
        f_items_res = await db.execute(f_items_stmt)
        products_list = []
        for fi, fr in f_items_res.all():
            products_list.append(AdminDeliveryProduct(
                id=fr.id,
                name=fr.name,
                quantity=fi.quantity,
                unit=fr.unit.value if hasattr(fr.unit, "value") else str(fr.unit)
            ))

        timeline = [AdminDeliveryTimelineEvent(
            status="Order Placed",
            description=f"Fruit order created",
            timestamp=f_order.created_at
        )]
        if assign:
            timeline.append(AdminDeliveryTimelineEvent(
                status="Assigned",
                description=f"Assigned to {p_user.full_name}",
                timestamp=assign.assigned_at
            ))
            if assign.out_at:
                timeline.append(AdminDeliveryTimelineEvent(status="Out for Delivery", description="Driver is on the way", timestamp=assign.out_at))
            if assign.delivered_at:
                timeline.append(AdminDeliveryTimelineEvent(status="Delivered", description="Order completed", timestamp=assign.delivered_at))
            elif assign.failed_at:
                timeline.append(AdminDeliveryTimelineEvent(status="Failed", description=assign.failure_reason or "Delivery failed", timestamp=assign.failed_at))

        assignment_history = []
        
        return AdminDeliveryDetail(
            id=f_order.id,
            subscription_id=None,
            scheduled_date=f_order.delivery_date or f_order.created_at.date(),
            status=f_order.order_status.value if hasattr(f_order.order_status, "value") else str(f_order.order_status),
            delivered_at=assign.delivered_at if assign else None,
            delivery_proof_url=None,
            customer_rating=f_order.rating,
            customer_feedback=f_order.review_text,
            notes=f_order.notes,
            amount=float(f_order.total_amount),
            payment_method=None,
            payment_status="Paid" if f_order.payment_status.value == "paid" else "Pending",
            preferred_delivery_time=f_order.delivery_slot or "Standard",
            customer=customer_detail,
            delivery_partner=partner_detail,
            address=address_detail,
            products=products_list,
            timeline=timeline,
            assignment_history=assignment_history
        )

    deliv, sub, cust, c_user, assign, partner, p_user, addr = row

    # 1. Customer detail
    customer_detail = AdminDeliveryCustomer(
        id=cust.id,
        full_name=c_user.full_name,
        phone=c_user.phone,
        email=c_user.email,
        customer_code=cust.customer_code
    )

    # 2. Partner detail
    partner_detail = None
    if partner and p_user:
        partner_detail = AdminDeliveryPartner(
            id=partner.id,
            full_name=p_user.full_name,
            phone=p_user.phone,
            employee_code=partner.employee_code,
            vehicle_type=partner.vehicle_type.value if hasattr(partner.vehicle_type, "value") and partner.vehicle_type else str(partner.vehicle_type or ""),
            vehicle_number=partner.vehicle_number
        )

    # 3. Address detail
    address_detail = AdminDeliveryAddress(
        id=addr.id,
        address_line1=addr.address_line1,
        address_line2=addr.address_line2,
        city=addr.city,
        state=addr.state,
        pincode=addr.pincode,
        landmark=addr.landmark,
        latitude=float(addr.latitude) if addr.latitude is not None else None,
        longitude=float(addr.longitude) if addr.longitude is not None else None
    )

    # 4. Products detail
    prod_stmt = (
        select(SubscriptionItem, Product)
        .join(Product, Product.id == SubscriptionItem.product_id)
        .where(SubscriptionItem.subscription_id == sub.id)
    )
    prod_res = await db.execute(prod_stmt)
    prod_rows = prod_res.all()
    products_list = [
        AdminDeliveryProduct(
            product_name=p.name,
            quantity=item.quantity,
            price_per_delivery=float(item.price_per_delivery) if item.price_per_delivery is not None else 0.0
        )
        for item, p in prod_rows
    ]

    # 5. Timeline steps
    # Placed -> Assigned -> Picked Up -> Out for Delivery -> Delivered
    # Note: Placed uses deliv.created_at
    timeline = []
    
    # Placed (always completed)
    timeline.append(AdminDeliveryTimelineStep(
        stage="Order Placed",
        completed=True,
        timestamp=deliv.created_at
    ))

    # Assigned
    is_assigned = deliv.status != DeliveryStatus.PENDING and assign is not None
    timeline.append(AdminDeliveryTimelineStep(
        stage="Assigned",
        completed=is_assigned,
        timestamp=assign.assigned_at if is_assigned else None
    ))

    # Picked Up
    is_picked_up = is_assigned and assign.picked_up_at is not None
    timeline.append(AdminDeliveryTimelineStep(
        stage="Picked Up",
        completed=is_picked_up,
        timestamp=assign.picked_up_at if is_picked_up else None
    ))

    # Out for Delivery
    is_out = is_assigned and assign.out_at is not None
    timeline.append(AdminDeliveryTimelineStep(
        stage="Out For Delivery",
        completed=is_out,
        timestamp=assign.out_at if is_out else None
    ))

    # Delivered
    is_delivered = deliv.status == DeliveryStatus.DELIVERED
    timeline.append(AdminDeliveryTimelineStep(
        stage="Delivered",
        completed=is_delivered,
        timestamp=deliv.delivered_at if is_delivered else None
    ))

    # 6. Assignment logs
    PrevPartner = aliased(DeliveryPartner, name="prev_partner")
    PrevPartnerUser = aliased(User, name="prev_partner_user")
    NewPartner = aliased(DeliveryPartner, name="new_partner")
    NewPartnerUser = aliased(User, name="new_partner_user")
    ChangedByUser = aliased(User, name="changed_by_user")

    history_stmt = (
        select(
            DeliveryAssignmentHistory,
            PrevPartnerUser.full_name.label("prev_name"),
            NewPartnerUser.full_name.label("new_name"),
            ChangedByUser.full_name.label("changed_by_name"),
        )
        .where(DeliveryAssignmentHistory.delivery_id == deliv.id)
        .outerjoin(PrevPartner, PrevPartner.id == DeliveryAssignmentHistory.previous_partner_id)
        .outerjoin(PrevPartnerUser, PrevPartnerUser.id == PrevPartner.user_id)
        .outerjoin(NewPartner, NewPartner.id == DeliveryAssignmentHistory.new_partner_id)
        .outerjoin(NewPartnerUser, NewPartnerUser.id == NewPartner.user_id)
        .outerjoin(ChangedByUser, ChangedByUser.id == DeliveryAssignmentHistory.changed_by_id)
        .order_by(DeliveryAssignmentHistory.changed_at.desc())
    )
    hist_res = await db.execute(history_stmt)
    hist_rows = hist_res.all()

    assignment_history = [
        AdminDeliveryAssignmentLog(
            previous_partner_name=h.prev_name,
            new_partner_name=h.new_name,
            changed_by_name=h.changed_by_name,
            changed_at=h[0].changed_at
        )
        for h in hist_rows
    ]

    pay_status = "Paid" if sub.status in [SubscriptionStatus.ACTIVE, SubscriptionStatus.COMPLETED] else "Pending"
    
    # Find payment method of subscription
    from app.models.payment import Payment
    pay_stmt = select(Payment).where(Payment.subscription_id == sub.id).order_by(Payment.created_at.desc())
    pay_res = await db.execute(pay_stmt)
    payments_list = pay_res.scalars().all()
    pay_method = None
    if payments_list:
        last_pay = payments_list[0]
        pay_method = last_pay.payment_method.value if hasattr(last_pay.payment_method, "value") and last_pay.payment_method else str(last_pay.payment_method or "")

    return AdminDeliveryDetail(
        id=deliv.id,
        subscription_id=sub.id,
        scheduled_date=deliv.scheduled_date,
        status=deliv.status.value if hasattr(deliv.status, "value") else str(deliv.status),
        delivered_at=deliv.delivered_at,
        delivery_proof_url=deliv.delivery_proof_url,
        customer_rating=deliv.customer_rating,
        customer_feedback=deliv.customer_feedback,
        notes=deliv.notes,
        amount=float(sub.price_per_delivery) if sub.price_per_delivery is not None else 0.0,
        payment_method=pay_method,
        payment_status=pay_status,
        preferred_delivery_time=sub.preferred_delivery_time,
        customer=customer_detail,
        delivery_partner=partner_detail,
        address=address_detail,
        products=products_list,
        timeline=timeline,
        assignment_history=assignment_history
    )


@router.post("/{id}/assign", response_model=MessageResponse)
async def assign_or_reassign_partner(
    id: uuid.UUID,
    payload: AdminDeliveryAssignRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    """Assign or reassign a delivery partner to a delivery."""
    delivery = await db.get(SubscriptionDelivery, id)
    if not delivery:
        raise HTTPException(status_code=404, detail="Delivery not found")

    partner = await db.get(DeliveryPartner, payload.delivery_partner_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Delivery partner not found")

    partner_user = await db.get(User, partner.user_id)

    assignment_stmt = select(DeliveryAssignment).where(DeliveryAssignment.subscription_delivery_id == delivery.id)
    assignment_result = await db.execute(assignment_stmt)
    assignment = assignment_result.scalar_one_or_none()

    prev_partner_id = None
    if assignment:
        prev_partner_id = assignment.delivery_partner_id
        assignment.delivery_partner_id = partner.id
        assignment.status = AssignmentStatus.PENDING
        assignment.assigned_at = datetime.now(timezone.utc)
        assignment.picked_up_at = None
        assignment.out_at = None
        assignment.delivered_at = None
        assignment.failed_at = None
        assignment.failure_reason = None
    else:
        assignment = DeliveryAssignment(
            subscription_delivery_id=delivery.id,
            delivery_partner_id=partner.id,
            status=AssignmentStatus.PENDING,
            assigned_at=datetime.now(timezone.utc),
        )
        db.add(assignment)

    old_del_status = delivery.status.value if hasattr(delivery.status, "value") else str(delivery.status)
    delivery.status = DeliveryStatus.ASSIGNED

    # Write assignment history log
    history_log = DeliveryAssignmentHistory(
        delivery_id=delivery.id,
        previous_partner_id=prev_partner_id,
        new_partner_id=partner.id,
        changed_by_id=current_user.id,
        changed_at=datetime.now(timezone.utc),
    )
    db.add(history_log)

    # Transition log
    del_history = SubscriptionDeliveryHistory(
        delivery_id=delivery.id,
        old_status=old_del_status,
        new_status=DeliveryStatus.ASSIGNED.value,
        notes=f"Assigned to {partner_user.full_name} by admin",
        changed_by_id=current_user.id,
    )
    db.add(del_history)

    await db.commit()

    # Notification
    if prev_partner_id:
        prev_dp = await db.get(DeliveryPartner, prev_partner_id)
        if prev_dp:
            await NotificationService.send_notification_to_user(
                db=db,
                user_id=prev_dp.user_id,
                title="Delivery Reassigned",
                body="A delivery previously assigned to you has been reassigned to another partner.",
                notification_type="delivery",
                reference_id=str(delivery.id)
            )

    await NotificationService.send_notification_to_user(
        db=db,
        user_id=partner.user_id,
        title="New Delivery Assigned",
        body="You have been assigned a new delivery for today.",
        notification_type="delivery",
        reference_id=str(delivery.id)
    )

    return MessageResponse(message=f"Delivery assigned to {partner_user.full_name}")


@router.post("/subscription/{subscription_id}/assign", response_model=MessageResponse)
async def assign_subscription_partner(
    subscription_id: uuid.UUID,
    payload: AdminDeliveryAssignRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    """Assign a delivery partner to an entire subscription and all its future scheduled deliveries."""
    subscription = await db.get(Subscription, subscription_id)
    if not subscription:
        raise HTTPException(status_code=404, detail="Subscription not found")

    partner = await db.get(DeliveryPartner, payload.delivery_partner_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Delivery partner not found")

    partner_user = await db.get(User, partner.user_id)

    # Update subscription
    subscription.delivery_partner_id = partner.id

    # Find all future or pending deliveries for this subscription
    deliveries_stmt = select(SubscriptionDelivery).where(
        SubscriptionDelivery.subscription_id == subscription.id,
        SubscriptionDelivery.status.in_([DeliveryStatus.SCHEDULED, DeliveryStatus.ASSIGNED, DeliveryStatus.PENDING])
    )
    deliveries_result = await db.execute(deliveries_stmt)
    future_deliveries = deliveries_result.scalars().all()

    for delivery in future_deliveries:
        assignment_stmt = select(DeliveryAssignment).where(DeliveryAssignment.subscription_delivery_id == delivery.id)
        assignment_result = await db.execute(assignment_stmt)
        assignment = assignment_result.scalar_one_or_none()

        prev_partner_id = None
        if assignment:
            prev_partner_id = assignment.delivery_partner_id
            assignment.delivery_partner_id = partner.id
            assignment.status = AssignmentStatus.PENDING
            assignment.assigned_at = datetime.now(timezone.utc)
            assignment.picked_up_at = None
            assignment.out_at = None
            assignment.delivered_at = None
            assignment.failed_at = None
            assignment.failure_reason = None
        else:
            assignment = DeliveryAssignment(
                subscription_delivery_id=delivery.id,
                delivery_partner_id=partner.id,
                status=AssignmentStatus.PENDING,
                assigned_at=datetime.now(timezone.utc),
            )
            db.add(assignment)

        old_del_status = delivery.status.value if hasattr(delivery.status, "value") else str(delivery.status)
        delivery.status = DeliveryStatus.ASSIGNED

        history_log = DeliveryAssignmentHistory(
            delivery_id=delivery.id,
            previous_partner_id=prev_partner_id,
            new_partner_id=partner.id,
            changed_by_id=current_user.id,
            changed_at=datetime.now(timezone.utc),
        )
        db.add(history_log)

        del_history = SubscriptionDeliveryHistory(
            delivery_id=delivery.id,
            old_status=old_del_status,
            new_status=DeliveryStatus.ASSIGNED.value,
            notes=f"Assigned to {partner_user.full_name} via Subscription Bulk Assign",
            changed_by_id=current_user.id,
        )
        db.add(del_history)

    await db.commit()
    return MessageResponse(message=f"Subscription assigned to {partner_user.full_name}")


@router.post("/fruit/{fruit_order_id}/assign", response_model=MessageResponse)
async def assign_fruit_order_partner(
    fruit_order_id: uuid.UUID,
    payload: AdminDeliveryAssignRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    """Assign a delivery partner to a specific fruit order."""
    from app.models.fruit import FruitOrder, FruitOrderStatus
    f_order = await db.get(FruitOrder, fruit_order_id)
    if not f_order:
        raise HTTPException(status_code=404, detail="Fruit Order not found")

    partner = await db.get(DeliveryPartner, payload.delivery_partner_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Delivery partner not found")

    partner_user = await db.get(User, partner.user_id)

    assignment_stmt = select(DeliveryAssignment).where(DeliveryAssignment.fruit_order_id == f_order.id)
    assignment_result = await db.execute(assignment_stmt)
    assignment = assignment_result.scalar_one_or_none()

    if assignment:
        assignment.delivery_partner_id = partner.id
        assignment.status = AssignmentStatus.PENDING
        assignment.assigned_at = datetime.now(timezone.utc)
        assignment.picked_up_at = None
        assignment.out_at = None
        assignment.delivered_at = None
        assignment.failed_at = None
        assignment.failure_reason = None
    else:
        assignment = DeliveryAssignment(
            fruit_order_id=f_order.id,
            delivery_partner_id=partner.id,
            status=AssignmentStatus.PENDING,
            assigned_at=datetime.now(timezone.utc),
        )
        db.add(assignment)

    f_order.order_status = FruitOrderStatus.ASSIGNED
    await db.commit()

    await NotificationService.send_notification_to_user(
        db=db,
        user_id=partner.user_id,
        title="New Fruit Order Assigned",
        body="You have been assigned a new fruit order delivery.",
        notification_type="delivery",
        reference_id=str(f_order.id)
    )

    return MessageResponse(message=f"Fruit Order assigned to {partner_user.full_name}")


@router.put("/{id}/status", response_model=MessageResponse)
async def update_status(
    id: uuid.UUID,
    payload: AdminDeliveryStatusUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    """Admin updates delivery status manually, executing business engine hooks."""
    delivery = await db.get(SubscriptionDelivery, id)
    if not delivery:
        raise HTTPException(status_code=404, detail="Delivery not found")

    old_status_val = delivery.status.value if hasattr(delivery.status, "value") else str(delivery.status)
    new_status_val = payload.status

    assignment_stmt = select(DeliveryAssignment).where(DeliveryAssignment.subscription_delivery_id == delivery.id)
    assignment_result = await db.execute(assignment_stmt)
    assignment = assignment_result.scalar_one_or_none()

    now = datetime.now(timezone.utc)

    if new_status_val == "pending":
        delivery.status = DeliveryStatus.PENDING
        if assignment:
            await db.delete(assignment)

    elif new_status_val == "assigned":
        if not assignment:
            raise HTTPException(status_code=400, detail="Cannot assign status without delivery assignment")
        delivery.status = DeliveryStatus.ASSIGNED
        assignment.status = AssignmentStatus.PENDING

    elif new_status_val == "picked_up":
        if not assignment:
            raise HTTPException(status_code=400, detail="Cannot set picked_up without assignment")
        delivery.status = DeliveryStatus.ASSIGNED
        assignment.status = AssignmentStatus.ACCEPTED
        assignment.picked_up_at = now

    elif new_status_val == "out_for_delivery":
        if not assignment:
            raise HTTPException(status_code=400, detail="Cannot set out_for_delivery without assignment")
        delivery.status = DeliveryStatus.OUT_FOR_DELIVERY
        assignment.status = AssignmentStatus.OUT_FOR_DELIVERY
        assignment.out_at = now

    elif new_status_val == "delivered":
        if not assignment:
            raise HTTPException(status_code=400, detail="Cannot mark delivered without assignment")
        assignment.status = AssignmentStatus.DELIVERED
        assignment.delivered_at = now
        await subscription_engine.mark_delivered(db, delivery)

    elif new_status_val == "failed":
        if not assignment:
            raise HTTPException(status_code=400, detail="Cannot mark failed without assignment")
        assignment.status = AssignmentStatus.FAILED
        assignment.failed_at = now
        assignment.failure_reason = payload.failure_reason or "Marked failed by admin"
        await subscription_engine.handle_missed_delivery(db, delivery)

    elif new_status_val == "cancelled":
        await subscription_engine.skip_delivery(db, delivery)

    else:
        raise HTTPException(status_code=400, detail=f"Invalid status: {new_status_val}")

    del_history = SubscriptionDeliveryHistory(
        delivery_id=delivery.id,
        old_status=old_status_val,
        new_status=delivery.status.value if hasattr(delivery.status, "value") else str(delivery.status),
        notes=f"Status updated by admin to {new_status_val}",
        changed_by_id=current_user.id,
    )
    db.add(del_history)
    await db.commit()

    return MessageResponse(message=f"Status updated successfully to {new_status_val}")
