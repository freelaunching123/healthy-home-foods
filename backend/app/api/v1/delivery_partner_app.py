from datetime import date, datetime, timezone, timedelta
import uuid as uuid_lib
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func, or_

from app.db.session import get_db
from app.core.dependencies import require_delivery_partner, get_current_user
from app.models.user import User
from app.models.delivery_partner import DeliveryPartner
from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.subscription import Subscription
from app.models.fruit import FruitOrder, FruitOrderStatus
from app.models.customer import Customer
from app.models.address import Address
from app.schemas.common import (
    ActiveDeliveryResponse, PartnerDashboardStats, DeliveryRouteResponse,
    MessageResponse, DeliveryHistoryResponse, PartnerProfileUpdate, PartnerPasswordChange
)
from app.services.notification_service import NotificationService
from app.services import subscription_engine
from app.core.security import hash_password, verify_password

router = APIRouter(prefix="/delivery-partner", tags=["Delivery Partner App"])


async def get_my_partner_profile(db: AsyncSession, user_id):
    result = await db.execute(select(DeliveryPartner).where(DeliveryPartner.user_id == user_id))
    partner = result.scalar_one_or_none()
    if not partner:
        raise HTTPException(status_code=404, detail="Delivery partner profile not found")
    return partner


@router.get("/dashboard", response_model=PartnerDashboardStats)
async def get_dashboard_stats(
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    partner = await get_my_partner_profile(db, current_user.id)
    today = date.today()
    
    # Base query for today's assignments based on scheduled/delivery date
    query = (
        select(DeliveryAssignment)
        .outerjoin(SubscriptionDelivery, DeliveryAssignment.subscription_delivery_id == SubscriptionDelivery.id)
        .outerjoin(FruitOrder, DeliveryAssignment.fruit_order_id == FruitOrder.id)
        .where(
            DeliveryAssignment.delivery_partner_id == partner.id,
            or_(
                SubscriptionDelivery.scheduled_date == today,
                FruitOrder.delivery_date == today,
                and_(
                    DeliveryAssignment.subscription_delivery_id.is_(None),
                    DeliveryAssignment.fruit_order_id.is_(None),
                    func.date(DeliveryAssignment.assigned_at) == today
                )
            )
        )
    )
    result = await db.execute(query)
    assignments = result.scalars().all()
    
    assigned_today = len(assignments)
    completed_today = sum(1 for a in assignments if a.status == AssignmentStatus.DELIVERED)
    failed_deliveries = sum(1 for a in assignments if a.status == AssignmentStatus.FAILED)
    
    active_list = await get_active_deliveries(current_user, db)
    active_count = len(active_list)
    pending_deliveries = active_count

    success_rate = 0.0
    if assigned_today > 0:
        success_rate = (completed_today / assigned_today) * 100.0

    return PartnerDashboardStats(
        assigned_today=assigned_today,
        completed_today=completed_today,
        pending_deliveries=pending_deliveries,
        failed_deliveries=failed_deliveries,
        success_rate=round(success_rate, 1),
        active_deliveries=active_count
    )


@router.get("/active", response_model=List[ActiveDeliveryResponse])
async def get_active_deliveries(
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    partner = await get_my_partner_profile(db, current_user.id)
    today = date.today()
    
    # Get active assignments
    query = select(DeliveryAssignment).where(
        DeliveryAssignment.delivery_partner_id == partner.id,
        DeliveryAssignment.status.in_([AssignmentStatus.PENDING, AssignmentStatus.ACCEPTED, AssignmentStatus.OUT_FOR_DELIVERY])
    ).order_by(DeliveryAssignment.assigned_at.asc())
    
    result = await db.execute(query)
    assignments = result.scalars().all()
    
    response_list = []
    for a in assignments:
        if a.subscription_delivery_id:
            # Subscription Delivery
            sd_res = await db.execute(select(SubscriptionDelivery).where(SubscriptionDelivery.id == a.subscription_delivery_id))
            sd = sd_res.scalar_one_or_none()
            if not sd:
                continue
            # CRITICAL RULE: A subscription delivery scheduled for a future calendar date
            # MUST NOT be shown as an active delivery on today's list. Only one delivery per calendar day.
            if sd.scheduled_date > today:
                continue
            if sd.status in [DeliveryStatus.DELIVERED, DeliveryStatus.SKIPPED]:
                continue

            sub_res = await db.execute(select(Subscription).where(Subscription.id == sd.subscription_id))
            sub = sub_res.scalar_one_or_none()
            if not sub:
                continue
            cust_res = await db.execute(select(Customer).where(Customer.id == sub.customer_id))
            cust = cust_res.scalar_one_or_none()
            if not cust:
                continue
            addr_res = await db.execute(select(Address).where(Address.id == sub.address_id))
            addr = addr_res.scalar_one_or_none()
            if not addr:
                continue
            user_res = await db.execute(select(User).where(User.id == cust.user_id))
            u = user_res.scalar_one_or_none()
            if not u:
                continue
            
            response_list.append(ActiveDeliveryResponse(
                id=a.id,
                order_id=str(sd.id)[-8:].upper(),
                order_type="subscription",
                customer_name=u.full_name,
                customer_phone=u.phone,
                delivery_address=f"{addr.address_line1}, {addr.city}, {addr.pincode}",
                latitude=float(addr.latitude) if addr.latitude else None,
                longitude=float(addr.longitude) if addr.longitude else None,
                status=a.status.value if hasattr(a.status, "value") else str(a.status),
                assigned_at=a.assigned_at,
                items_summary="Subscription Meal",
                total_amount=0.0, # Prepaid usually
                delivery_instructions=sub.notes,
                scheduled_time=sub.preferred_delivery_time or "Morning (7-9 AM)"
            ))
        elif a.fruit_order_id:
            # Fruit Order
            fo_res = await db.execute(select(FruitOrder).where(FruitOrder.id == a.fruit_order_id))
            fo = fo_res.scalar_one_or_none()
            if not fo:
                continue
            if fo.order_status in [FruitOrderStatus.DELIVERED, FruitOrderStatus.CANCELLED]:
                continue
            cust_res = await db.execute(select(Customer).where(Customer.id == fo.customer_id))
            cust = cust_res.scalar_one_or_none()
            if not cust:
                continue
            addr_res = await db.execute(select(Address).where(Address.id == fo.address_id))
            addr = addr_res.scalar_one_or_none()
            if not addr:
                continue
            user_res = await db.execute(select(User).where(User.id == cust.user_id))
            u = user_res.scalar_one_or_none()
            if not u:
                continue
            
            response_list.append(ActiveDeliveryResponse(
                id=a.id,
                order_id=fo.order_number,
                order_type="fruit",
                customer_name=u.full_name,
                customer_phone=u.phone,
                delivery_address=f"{addr.address_line1}, {addr.city}, {addr.pincode}",
                latitude=float(addr.latitude) if addr.latitude else None,
                longitude=float(addr.longitude) if addr.longitude else None,
                status=a.status.value if hasattr(a.status, "value") else str(a.status),
                assigned_at=a.assigned_at,
                items_summary="Fresh Fruits Order",
                total_amount=float(fo.total_amount),
                delivery_instructions=fo.notes,
                scheduled_time="9 AM - 6 PM"
            ))
            
    return response_list


@router.get("/route", response_model=DeliveryRouteResponse)
async def get_route(
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    # Fetch active deliveries
    active_deliveries = await get_active_deliveries(current_user, db)
    
    # A simple greedy sort could be implemented here if the partner's lat/long is known.
    # For now, we will return them sorted by assignment time (as they come from get_active_deliveries)
    # or implement a simple straight-line distance sort if all have lat/long.
    
    total_distance = len(active_deliveries) * 2.5 # Fake estimate for UI
    total_time = len(active_deliveries) * 15 # Fake estimate for UI
    
    return DeliveryRouteResponse(
        stops=active_deliveries,
        total_distance_km=total_distance,
        total_estimated_minutes=total_time
    )


@router.get("/history", response_model=List[DeliveryHistoryResponse])
async def get_history(
    filter_period: str = "today", # today, week, month
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    partner = await get_my_partner_profile(db, current_user.id)
    
    now = datetime.now(timezone.utc)
    if filter_period == "week":
        start_date = now - timedelta(days=7)
    elif filter_period == "month":
        start_date = now - timedelta(days=30)
    else:
        start_date = now.replace(hour=0, minute=0, second=0, microsecond=0)
        
    query = select(DeliveryAssignment).where(
        DeliveryAssignment.delivery_partner_id == partner.id,
        or_(
            DeliveryAssignment.delivered_at >= start_date,
            DeliveryAssignment.failed_at >= start_date
        ),
        DeliveryAssignment.status.in_([AssignmentStatus.DELIVERED, AssignmentStatus.FAILED])
    ).order_by(DeliveryAssignment.assigned_at.desc())
    
    result = await db.execute(query)
    assignments = result.scalars().all()
    
    histories = []
    for a in assignments:
      customer_name = ""
      product_name = ""
      order_id = ""
      dt = a.delivered_at or a.failed_at or a.assigned_at
      
      if a.subscription_delivery_id:
          sd_res = await db.execute(select(SubscriptionDelivery).where(SubscriptionDelivery.id == a.subscription_delivery_id))
          sd = sd_res.scalar_one_or_none()
          if sd:
              order_id = str(sd.id)[-8:].upper()
              sub_res = await db.execute(select(Subscription).where(Subscription.id == sd.subscription_id))
              sub = sub_res.scalar_one()
              cust_res = await db.execute(select(Customer).where(Customer.id == sub.customer_id))
              cust = cust_res.scalar_one()
              user_res = await db.execute(select(User).where(User.id == cust.user_id))
              u = user_res.scalar_one()
              customer_name = u.full_name
              product_name = "Subscription Meal"
      elif a.fruit_order_id:
          fo_res = await db.execute(select(FruitOrder).where(FruitOrder.id == a.fruit_order_id))
          fo = fo_res.scalar_one_or_none()
          if fo:
              order_id = fo.order_number
              cust_res = await db.execute(select(Customer).where(Customer.id == fo.customer_id))
              cust = cust_res.scalar_one()
              user_res = await db.execute(select(User).where(User.id == cust.user_id))
              u = user_res.scalar_one()
              customer_name = u.full_name
              product_name = f"Fruit Order {fo.order_number}"
              
      histories.append(DeliveryHistoryResponse(
          id=a.id,
          delivery_date=dt.date() if dt else date.today(),
          product_name=product_name,
          status=a.status.value,
          order_type="subscription" if a.subscription_delivery_id else "fruit",
          customer_name=customer_name,
          delivery_time=dt,
          order_id=order_id
      ))
        
    return histories

@router.get("/profile")
async def get_profile(
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    partner = await get_my_partner_profile(db, current_user.id)
    return {
        "full_name": current_user.full_name,
        "mobile_number": current_user.phone,
        "photo_url": partner.photo_url,
        "delivery_partner": {
            "employee_code": partner.employee_code,
            "vehicle_type": partner.vehicle_type.value if partner.vehicle_type else None,
            "vehicle_number": partner.vehicle_number,
            "age": partner.age,
            "gender": partner.gender,
        }
    }

@router.put("/profile", response_model=MessageResponse)
async def update_profile(
    payload: PartnerProfileUpdate,
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    partner = await get_my_partner_profile(db, current_user.id)
    if payload.vehicle_type is not None:
        partner.vehicle_type = payload.vehicle_type
    if payload.vehicle_number is not None:
        partner.vehicle_number = payload.vehicle_number
        
    await db.commit()
    return MessageResponse(message="Profile updated successfully")


@router.put("/change-password", response_model=MessageResponse)
async def change_password(
    payload: PartnerPasswordChange,
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Password management must be available only to the Admin through the Admin Panel."
    )

@router.get("/assignments/{assignment_id}", response_model=ActiveDeliveryResponse)
async def get_assignment_details(
    assignment_id: uuid_lib.UUID,
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    partner = await get_my_partner_profile(db, current_user.id)
    query = select(DeliveryAssignment).where(
        DeliveryAssignment.id == assignment_id,
        DeliveryAssignment.delivery_partner_id == partner.id
    )
    result = await db.execute(query)
    a = result.scalar_one_or_none()
    if not a:
        raise HTTPException(status_code=404, detail="Assignment not found")
        
    if a.subscription_delivery_id:
        sd_res = await db.execute(select(SubscriptionDelivery).where(SubscriptionDelivery.id == a.subscription_delivery_id))
        sd = sd_res.scalar_one()
        sub_res = await db.execute(select(Subscription).where(Subscription.id == sd.subscription_id))
        sub = sub_res.scalar_one()
        cust_res = await db.execute(select(Customer).where(Customer.id == sub.customer_id))
        cust = cust_res.scalar_one()
        addr_res = await db.execute(select(Address).where(Address.id == sub.address_id))
        addr = addr_res.scalar_one()
        user_res = await db.execute(select(User).where(User.id == cust.user_id))
        u = user_res.scalar_one()
        
        return ActiveDeliveryResponse(
            id=a.id,
            order_id=str(sd.id)[-8:].upper(),
            order_type="subscription",
            customer_name=u.full_name,
            customer_phone=u.phone,
            delivery_address=f"{addr.address_line1}, {addr.city}, {addr.pincode}",
            latitude=float(addr.latitude) if addr.latitude else None,
            longitude=float(addr.longitude) if addr.longitude else None,
            status=a.status.value,
            assigned_at=a.assigned_at,
            items_summary="Subscription Meal",
            total_amount=0.0,
            delivery_instructions=sub.notes,
            scheduled_time=sub.preferred_delivery_time or "Morning (7-9 AM)"
        )
    elif a.fruit_order_id:
        fo_res = await db.execute(select(FruitOrder).where(FruitOrder.id == a.fruit_order_id))
        fo = fo_res.scalar_one()
        cust_res = await db.execute(select(Customer).where(Customer.id == fo.customer_id))
        cust = cust_res.scalar_one()
        addr_res = await db.execute(select(Address).where(Address.id == fo.address_id))
        addr = addr_res.scalar_one()
        user_res = await db.execute(select(User).where(User.id == cust.user_id))
        u = user_res.scalar_one()
        
        # Get items for fruit order
        from app.models.fruit import FruitOrderItem, Fruit
        items_result = await db.execute(
            select(FruitOrderItem, Fruit)
            .outerjoin(Fruit, Fruit.id == FruitOrderItem.fruit_id)
            .where(FruitOrderItem.order_id == fo.id)
        )
        items_rows = items_result.all()
        items_summary = ", ".join([f"{f.name if f else 'Fresh Fruit'} ({item.quantity_kg} kg)" for item, f in items_rows])
        
        return ActiveDeliveryResponse(
            id=a.id,
            order_id=fo.order_number,
            order_type="fruit",
            customer_name=u.full_name,
            customer_phone=u.phone,
            delivery_address=f"{addr.address_line1}, {addr.city}, {addr.pincode}",
            latitude=float(addr.latitude) if addr.latitude else None,
            longitude=float(addr.longitude) if addr.longitude else None,
            status=a.status.value,
            assigned_at=a.assigned_at,
            items_summary=items_summary or "Fresh Fruits Order",
            total_amount=float(fo.total_amount),
            delivery_instructions=fo.notes,
            scheduled_time="9 AM - 6 PM"
        )

from app.schemas.common import UpdateDeliveryStatusRequest

@router.put("/assignments/{assignment_id}/status", response_model=MessageResponse)
async def update_delivery_status(
    assignment_id: str,
    payload: UpdateDeliveryStatusRequest,
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    try:
        assign_uuid = uuid_lib.UUID(assignment_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid assignment ID format")

    result = await db.execute(
        select(DeliveryAssignment).where(
            or_(
                DeliveryAssignment.id == assign_uuid,
                DeliveryAssignment.subscription_delivery_id == assign_uuid,
                DeliveryAssignment.fruit_order_id == assign_uuid,
            )
        )
    )
    assignment = result.scalars().first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
        
    now = datetime.now(timezone.utc)
    
    # Identify the parent order
    user_id = None
    delivery = None
    fruit_order = None
    if assignment.subscription_delivery_id:
        sd_res = await db.execute(select(SubscriptionDelivery).where(SubscriptionDelivery.id == assignment.subscription_delivery_id))
        delivery = sd_res.scalar_one_or_none()
        if delivery:
            sub_res = await db.execute(select(Subscription).where(Subscription.id == delivery.subscription_id))
            sub = sub_res.scalar_one_or_none()
            if sub:
                cust_res = await db.execute(select(Customer).where(Customer.id == sub.customer_id))
                cust = cust_res.scalar_one_or_none()
                if cust:
                    user_id = cust.user_id
    elif assignment.fruit_order_id:
        fo_res = await db.execute(select(FruitOrder).where(FruitOrder.id == assignment.fruit_order_id))
        fruit_order = fo_res.scalar_one_or_none()
        if fruit_order:
            cust_res = await db.execute(select(Customer).where(Customer.id == fruit_order.customer_id))
            cust = cust_res.scalar_one_or_none()
            if cust:
                user_id = cust.user_id

    if payload.status == "accepted":
        assignment.status = AssignmentStatus.ACCEPTED
        assignment.picked_up_at = now
    elif payload.status == "out_for_delivery":
        assignment.status = AssignmentStatus.OUT_FOR_DELIVERY
        assignment.out_at = now
        if assignment.subscription_delivery_id and delivery:
            delivery.status = DeliveryStatus.OUT_FOR_DELIVERY
        elif assignment.fruit_order_id and fruit_order:
            fruit_order.order_status = FruitOrderStatus.OUT_FOR_DELIVERY
            
        if user_id:
            try:
                await NotificationService.send_notification_to_user(
                    db=db, user_id=user_id, title="Out for Delivery",
                    body="Your order is out for delivery!",
                    notification_type="delivery", reference_id=str(assignment.id)
                )
            except Exception:
                pass
    elif payload.status == "delivered":
        assignment.status = AssignmentStatus.DELIVERED
        assignment.delivered_at = now
        if assignment.subscription_delivery_id and delivery:
            await subscription_engine.mark_delivered(db, delivery)
        elif assignment.fruit_order_id and fruit_order:
            fruit_order.order_status = FruitOrderStatus.DELIVERED
            
        if user_id:
            try:
                await NotificationService.send_notification_to_user(
                    db=db, user_id=user_id, title="Delivery Completed",
                    body="Your order has been delivered. Enjoy!",
                    notification_type="delivery", reference_id=str(assignment.id)
                )
            except Exception:
                pass
    elif payload.status == "failed":
        assignment.status = AssignmentStatus.FAILED
        assignment.failed_at = now
        assignment.failure_reason = payload.failure_reason
        if assignment.subscription_delivery_id and delivery:
            await subscription_engine.handle_missed_delivery(db, delivery)
        elif assignment.fruit_order_id and fruit_order:
            fruit_order.order_status = FruitOrderStatus.CANCELLED
            
        if user_id:
            try:
                await NotificationService.send_notification_to_user(
                    db=db, user_id=user_id, title="Delivery Failed",
                    body=f"We couldn't deliver your order today. Reason: {payload.failure_reason}",
                    notification_type="delivery", reference_id=str(assignment.id)
                )
            except Exception:
                pass
    else:
        raise HTTPException(status_code=400, detail=f"Invalid status: {payload.status}")

    await db.commit()
    return MessageResponse(message=f"Status updated to {payload.status}")
