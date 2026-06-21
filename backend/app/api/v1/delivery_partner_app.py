from datetime import date, datetime, timezone, timedelta
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
    
    # Base query for today's assignments
    query = select(DeliveryAssignment).where(
        DeliveryAssignment.delivery_partner_id == partner.id,
        func.date(DeliveryAssignment.assigned_at) == today
    )
    result = await db.execute(query)
    assignments = result.scalars().all()
    
    assigned_today = len(assignments)
    completed_today = sum(1 for a in assignments if a.status == AssignmentStatus.DELIVERED)
    pending_deliveries = sum(1 for a in assignments if a.status in [AssignmentStatus.PENDING, AssignmentStatus.PICKED_UP, AssignmentStatus.OUT_FOR_DELIVERY])
    failed_deliveries = sum(1 for a in assignments if a.status == AssignmentStatus.FAILED)
    
    success_rate = 0.0
    if assigned_today > 0:
        success_rate = (completed_today / assigned_today) * 100.0
        
    # Active deliveries: pending/picked_up/out across any date (if not finished)
    active_query = select(func.count(DeliveryAssignment.id)).where(
        DeliveryAssignment.delivery_partner_id == partner.id,
        DeliveryAssignment.status.in_([AssignmentStatus.PENDING, AssignmentStatus.PICKED_UP, AssignmentStatus.OUT_FOR_DELIVERY])
    )
    active_count = await db.scalar(active_query)

    return PartnerDashboardStats(
        assigned_today=assigned_today,
        completed_today=completed_today,
        pending_deliveries=pending_deliveries,
        failed_deliveries=failed_deliveries,
        success_rate=success_rate,
        active_deliveries=active_count or 0
    )


@router.get("/active", response_model=List[ActiveDeliveryResponse])
async def get_active_deliveries(
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    partner = await get_my_partner_profile(db, current_user.id)
    
    # Get active assignments
    query = select(DeliveryAssignment).where(
        DeliveryAssignment.delivery_partner_id == partner.id,
        DeliveryAssignment.status.in_([AssignmentStatus.PENDING, AssignmentStatus.PICKED_UP, AssignmentStatus.OUT_FOR_DELIVERY])
    ).order_by(DeliveryAssignment.assigned_at.asc())
    
    result = await db.execute(query)
    assignments = result.scalars().all()
    
    response_list = []
    for a in assignments:
        if a.subscription_delivery_id:
            # Subscription Delivery
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
            
            response_list.append(ActiveDeliveryResponse(
                id=a.id,
                order_id=str(sd.id)[-8:].upper(),
                order_type="subscription",
                customer_name=u.full_name,
                customer_phone=u.mobile_number,
                delivery_address=f"{addr.address_line1}, {addr.city}, {addr.pincode}",
                latitude=float(addr.latitude) if addr.latitude else None,
                longitude=float(addr.longitude) if addr.longitude else None,
                status=a.status.value,
                assigned_at=a.assigned_at,
                items_summary="Subscription Meal",
                total_amount=0.0, # Prepaid usually
                delivery_instructions=sub.notes
            ))
        elif a.fruit_order_id:
            # Fruit Order
            fo_res = await db.execute(select(FruitOrder).where(FruitOrder.id == a.fruit_order_id))
            fo = fo_res.scalar_one()
            cust_res = await db.execute(select(Customer).where(Customer.id == fo.customer_id))
            cust = cust_res.scalar_one()
            addr_res = await db.execute(select(Address).where(Address.id == fo.address_id))
            addr = addr_res.scalar_one()
            user_res = await db.execute(select(User).where(User.id == cust.user_id))
            u = user_res.scalar_one()
            
            response_list.append(ActiveDeliveryResponse(
                id=a.id,
                order_id=fo.order_number,
                order_type="fruit",
                customer_name=u.full_name,
                customer_phone=u.mobile_number,
                delivery_address=f"{addr.address_line1}, {addr.city}, {addr.pincode}",
                latitude=float(addr.latitude) if addr.latitude else None,
                longitude=float(addr.longitude) if addr.longitude else None,
                status=a.status.value,
                assigned_at=a.assigned_at,
                items_summary="Fresh Fruits Order",
                total_amount=float(fo.total_amount),
                delivery_instructions=fo.notes
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
        DeliveryAssignment.assigned_at >= start_date,
        DeliveryAssignment.status.in_([AssignmentStatus.DELIVERED, AssignmentStatus.FAILED])
    ).order_by(DeliveryAssignment.assigned_at.desc())
    
    result = await db.execute(query)
    assignments = result.scalars().all()
    
    histories = []
    for a in assignments:
        customer_name = ""
        product_name = ""
        dt = a.delivered_at or a.failed_at or a.assigned_at
        
        if a.subscription_delivery_id:
            sd_res = await db.execute(select(SubscriptionDelivery).where(SubscriptionDelivery.id == a.subscription_delivery_id))
            sd = sd_res.scalar_one_or_none()
            if sd:
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
            delivery_time=dt
        ))
        
    return histories

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
    if payload.service_zone is not None:
        partner.service_zone = payload.service_zone
        
    await db.commit()
    return MessageResponse(message="Profile updated successfully")


@router.put("/change-password", response_model=MessageResponse)
async def change_password(
    payload: PartnerPasswordChange,
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    if not verify_password(payload.old_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Incorrect old password")
        
    current_user.hashed_password = hash_password(payload.new_password)
    await db.commit()
    return MessageResponse(message="Password changed successfully")

from app.schemas.common import UpdateDeliveryStatusRequest

@router.put("/assignments/{assignment_id}/status", response_model=MessageResponse)
async def update_delivery_status(
    assignment_id: str,
    payload: UpdateDeliveryStatusRequest,
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(DeliveryAssignment).where(DeliveryAssignment.id == assignment_id))
    assignment = result.scalar_one_or_none()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
        
    now = datetime.now(timezone.utc)
    
    # Identify the parent order
    user_id = None
    if assignment.subscription_delivery_id:
        sd_res = await db.execute(select(SubscriptionDelivery).where(SubscriptionDelivery.id == assignment.subscription_delivery_id))
        delivery = sd_res.scalar_one()
        sub_res = await db.execute(select(Subscription).where(Subscription.id == delivery.subscription_id))
        sub = sub_res.scalar_one()
        cust_res = await db.execute(select(Customer).where(Customer.id == sub.customer_id))
        cust = cust_res.scalar_one()
        user_id = cust.user_id
    elif assignment.fruit_order_id:
        fo_res = await db.execute(select(FruitOrder).where(FruitOrder.id == assignment.fruit_order_id))
        fruit_order = fo_res.scalar_one()
        cust_res = await db.execute(select(Customer).where(Customer.id == fruit_order.customer_id))
        cust = cust_res.scalar_one()
        user_id = cust.user_id

    if payload.status == "picked_up":
        assignment.status = AssignmentStatus.PICKED_UP
        assignment.picked_up_at = now
    elif payload.status == "out_for_delivery":
        assignment.status = AssignmentStatus.OUT_FOR_DELIVERY
        assignment.out_at = now
        if assignment.subscription_delivery_id:
            delivery.status = DeliveryStatus.OUT_FOR_DELIVERY
        elif assignment.fruit_order_id:
            fruit_order.order_status = FruitOrderStatus.OUT_FOR_DELIVERY
            
        if user_id:
            await NotificationService.create_in_app_notification(
                db=db, user_id=user_id, title="Out for Delivery",
                body="Your order is out for delivery! You can track it live.",
                category="delivery", action_type="delivery", reference_id=str(assignment.id)
            )
    elif payload.status == "delivered":
        assignment.status = AssignmentStatus.DELIVERED
        assignment.delivered_at = now
        if assignment.subscription_delivery_id:
            await subscription_engine.mark_delivered(db, delivery)
        elif assignment.fruit_order_id:
            fruit_order.order_status = FruitOrderStatus.DELIVERED
            
        if user_id:
            await NotificationService.create_in_app_notification(
                db=db, user_id=user_id, title="Delivery Completed",
                body="Your order has been delivered. Enjoy!",
                category="delivery", action_type="delivery", reference_id=str(assignment.id)
            )
    elif payload.status == "failed":
        assignment.status = AssignmentStatus.FAILED
        assignment.failed_at = now
        assignment.failure_reason = payload.failure_reason
        if assignment.subscription_delivery_id:
            await subscription_engine.handle_missed_delivery(db, delivery)
        elif assignment.fruit_order_id:
            # Maybe a new status for failed fruit delivery, but keeping it simple
            pass
            
        if user_id:
            await NotificationService.create_in_app_notification(
                db=db, user_id=user_id, title="Delivery Failed",
                body=f"We couldn't deliver your order today. Reason: {payload.failure_reason}",
                category="delivery", action_type="delivery", reference_id=str(assignment.id)
            )
    else:
        raise HTTPException(status_code=400, detail=f"Invalid status: {payload.status}")

    await db.commit()
    return MessageResponse(message=f"Status updated to {payload.status}")
