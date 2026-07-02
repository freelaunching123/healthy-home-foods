import json
from uuid import UUID
from datetime import datetime, timezone, date
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Query, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
import redis.asyncio as aioredis
import os, shutil, uuid as uuid_lib

from app.db.session import get_db
from app.core.dependencies import get_current_user, require_super_admin, require_delivery_partner, require_customer
from app.models.user import User
from app.models.delivery_partner import DeliveryPartner
from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.gps_tracking import GpsTrackingLog
from app.models.subscription import Subscription
from app.models.customer import Customer
from app.schemas.common import (
    AssignDeliveryRequest, UpdateDeliveryStatusRequest, AssignmentResponse,
    GpsUpdateRequest, GpsLocationResponse, MessageResponse, DeliveryHistoryResponse,
)
from app.services import subscription_engine
from app.services.notification_service import NotificationService
from app.core.config import settings

router = APIRouter(prefix="/deliveries", tags=["Deliveries & GPS"])


async def get_redis():
    return await aioredis.from_url(settings.REDIS_URL, decode_responses=True)


@router.get("/history", response_model=list[DeliveryHistoryResponse])
async def get_customer_delivery_history(
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Get delivery history for the authenticated customer."""
    # Get customer
    from app.models.customer import Customer
    customer_result = await db.execute(select(Customer).where(Customer.user_id == current_user.id))
    customer = customer_result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer profile not found")

    from app.models.subscription import Subscription, SubscriptionItem
    from app.models.product import Product
    
    query = (
        select(
            SubscriptionDelivery.id,
            SubscriptionDelivery.scheduled_date,
            SubscriptionDelivery.status,
            func.string_agg(Product.name, ", ").label("product_name")
        )
        .join(Subscription, Subscription.id == SubscriptionDelivery.subscription_id)
        .outerjoin(SubscriptionItem, SubscriptionItem.subscription_id == Subscription.id)
        .outerjoin(Product, Product.id == SubscriptionItem.product_id)
        .where(Subscription.customer_id == customer.id)
        .group_by(SubscriptionDelivery.id, SubscriptionDelivery.scheduled_date, SubscriptionDelivery.status)
        .order_by(SubscriptionDelivery.scheduled_date.desc())
    )
    result = await db.execute(query)
    rows = result.fetchall()
    
    return [
        DeliveryHistoryResponse(
            id=row.id,
            delivery_date=row.scheduled_date,
            product_name=row.product_name,
            status=row.status.value if hasattr(row.status, "value") else row.status
        )
        for row in rows
    ]


# ── Admin: View & assign deliveries ───────────────────────────────────────────

@router.get("/pending")
async def get_pending_deliveries(
    delivery_date: date = Query(default=date.today()),
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SubscriptionDelivery).where(
            and_(
                SubscriptionDelivery.scheduled_date == delivery_date,
                SubscriptionDelivery.status == DeliveryStatus.PENDING,
            )
        )
    )
    return result.scalars().all()


@router.post("/assign", response_model=AssignmentResponse)
async def assign_delivery(
    payload: AssignDeliveryRequest,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Manually assign a delivery to a specific delivery boy. Overwrites existing assignments if they exist."""
    delivery_result = await db.execute(
        select(SubscriptionDelivery).where(SubscriptionDelivery.id == payload.delivery_id)
    )
    delivery = delivery_result.scalar_one_or_none()
    if not delivery:
        raise HTTPException(status_code=404, detail="Delivery not found")

    partner_result = await db.execute(
        select(DeliveryPartner).where(DeliveryPartner.id == payload.delivery_partner_id)
    )
    partner = partner_result.scalar_one_or_none()
    if not partner:
        raise HTTPException(status_code=404, detail="Delivery partner not found")

    # Check if a delivery assignment already exists for this delivery (to overwrite)
    assignment_result = await db.execute(
        select(DeliveryAssignment).where(DeliveryAssignment.delivery_id == delivery.id)
    )
    assignment = assignment_result.scalar_one_or_none()

    if assignment:
        # Overwrite/reset the existing assignment details
        assignment.delivery_partner_id = partner.id
        assignment.status = AssignmentStatus.PENDING
        assignment.assigned_at = datetime.now(timezone.utc)
        assignment.picked_up_at = None
        assignment.out_at = None
        assignment.delivered_at = None
        assignment.failed_at = None
        assignment.failure_reason = None
    else:
        # Create a new assignment
        assignment = DeliveryAssignment(
            delivery_id=delivery.id,
            delivery_partner_id=partner.id,
            status=AssignmentStatus.PENDING,
            assigned_at=datetime.now(timezone.utc),
        )
        db.add(assignment)

    delivery.status = DeliveryStatus.ASSIGNED
    await db.commit()
    await db.refresh(assignment)
    return assignment


# ── Delivery partner: View assigned deliveries ─────────────────────────────────────

@router.get("/assigned", response_model=list[AssignmentResponse])
async def get_my_assignments(
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
    delivery_date: date = Query(default=date.today()),
):
    partner_result = await db.execute(
        select(DeliveryPartner).where(DeliveryPartner.user_id == current_user.id)
    )
    partner = partner_result.scalar_one_or_none()
    if not partner:
        raise HTTPException(status_code=404, detail="Delivery partner profile not found")

    result = await db.execute(
        select(DeliveryAssignment)
        .join(SubscriptionDelivery, DeliveryAssignment.delivery_id == SubscriptionDelivery.id)
        .where(
            and_(
                DeliveryAssignment.delivery_partner_id == partner.id,
                SubscriptionDelivery.scheduled_date == delivery_date,
            )
        )
    )
    return result.scalars().all()


@router.put("/{assignment_id}/status", response_model=MessageResponse)
async def update_delivery_status(
    assignment_id: UUID,
    payload: UpdateDeliveryStatusRequest,
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    """Delivery partner updates assignment status (accepted/out_for_delivery/delivered/failed)."""
    result = await db.execute(
        select(DeliveryAssignment).where(DeliveryAssignment.id == assignment_id)
    )
    assignment = result.scalar_one_or_none()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    now = datetime.now(timezone.utc)
    
    # Pre-fetch user_id for notifications
    delivery_result = await db.execute(
        select(SubscriptionDelivery).where(SubscriptionDelivery.id == assignment.delivery_id)
    )
    delivery = delivery_result.scalar_one()
    sub_result = await db.execute(
        select(Subscription).where(Subscription.id == delivery.subscription_id)
    )
    sub = sub_result.scalar_one()
    customer_result = await db.execute(
        select(Customer).where(Customer.id == sub.customer_id)
    )
    customer = customer_result.scalar_one()
    user_id = customer.user_id

    if payload.status == "accepted":
        assignment.status = AssignmentStatus.ACCEPTED
        assignment.picked_up_at = now
    elif payload.status == "out_for_delivery":
        assignment.status = AssignmentStatus.OUT_FOR_DELIVERY
        assignment.out_at = now
        delivery.status = DeliveryStatus.OUT_FOR_DELIVERY
        await NotificationService.create_in_app_notification(
            db=db,
            user_id=user_id,
            title="Out for Delivery",
            body="Your meal is out for delivery! You can track it live.",
            category="delivery",
            action_type="delivery",
            reference_id=str(delivery.id)
        )
    elif payload.status == "delivered":
        assignment.status = AssignmentStatus.DELIVERED
        await subscription_engine.mark_delivered(db, delivery)
        assignment.delivered_at = now
        await NotificationService.create_in_app_notification(
            db=db,
            user_id=user_id,
            title="Delivery Completed",
            body="Your meal has been delivered. Enjoy your food!",
            category="delivery",
            action_type="delivery",
            reference_id=str(delivery.id)
        )
    elif payload.status == "failed":
        assignment.status = AssignmentStatus.FAILED
        assignment.failed_at = now
        assignment.failure_reason = payload.failure_reason
        await subscription_engine.handle_missed_delivery(db, delivery)
        await NotificationService.create_in_app_notification(
            db=db,
            user_id=user_id,
            title="Delivery Failed",
            body=f"We couldn't deliver your meal today. Reason: {payload.failure_reason}",
            category="delivery",
            action_type="delivery",
            reference_id=str(delivery.id)
        )
    else:
        raise HTTPException(status_code=400, detail=f"Invalid status: {payload.status}")

    await db.commit()
    return MessageResponse(message=f"Status updated to {payload.status}")


@router.post("/{assignment_id}/proof", response_model=MessageResponse)
async def upload_delivery_proof(
    assignment_id: UUID,
    file: UploadFile = File(...),
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    """Upload delivery proof photo."""
    result = await db.execute(
        select(DeliveryAssignment).where(DeliveryAssignment.id == assignment_id)
    )
    assignment = result.scalar_one_or_none()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in [".jpg", ".jpeg", ".png"]:
        raise HTTPException(status_code=400, detail="Invalid image format")

    upload_dir = os.path.join(settings.UPLOAD_DIR, "proofs")
    os.makedirs(upload_dir, exist_ok=True)
    filename = f"{uuid_lib.uuid4()}{ext}"
    filepath = os.path.join(upload_dir, filename)
    with open(filepath, "wb") as f:
        shutil.copyfileobj(file.file, f)

    delivery_result = await db.execute(
        select(SubscriptionDelivery).where(SubscriptionDelivery.id == assignment.delivery_id)
    )
    delivery = delivery_result.scalar_one()
    delivery.delivery_proof_url = f"/uploads/proofs/{filename}"
    await db.commit()
    return MessageResponse(message="Proof uploaded successfully")


# ── GPS Tracking ──────────────────────────────────────────────────────────────

@router.post("/gps/update", response_model=MessageResponse)
async def update_gps_location(
    payload: GpsUpdateRequest,
    current_user: User = Depends(require_delivery_partner),
    db: AsyncSession = Depends(get_db),
):
    """Delivery partner sends live location. Stored in DB + broadcasted via Redis."""
    partner_result = await db.execute(
        select(DeliveryPartner).where(DeliveryPartner.user_id == current_user.id)
    )
    partner = partner_result.scalar_one_or_none()
    if not partner:
        raise HTTPException(status_code=404, detail="Delivery partner profile not found")

    # Update current location on delivery partner
    partner.current_lat = payload.latitude
    partner.current_lng = payload.longitude

    # Store GPS log
    gps_log = GpsTrackingLog(
        assignment_id=payload.assignment_id,
        delivery_partner_id=partner.id,
        latitude=payload.latitude,
        longitude=payload.longitude,
        accuracy_meters=payload.accuracy_meters,
        speed_kmph=payload.speed_kmph,
        heading=payload.heading,
        recorded_at=datetime.now(timezone.utc),
    )
    db.add(gps_log)
    await db.commit()

    # Publish to Redis for WebSocket broadcast
    redis = await get_redis()
    location_data = json.dumps({
        "lat": payload.latitude,
        "lng": payload.longitude,
        "accuracy": payload.accuracy_meters,
        "speed": payload.speed_kmph,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "delivery_partner_name": current_user.full_name,
    })
    await redis.publish(f"gps:{payload.assignment_id}", location_data)
    await redis.close()

    return MessageResponse(message="Location updated")


@router.get("/gps/track/{assignment_id}", response_model=GpsLocationResponse)
async def get_current_location(
    assignment_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Poll latest GPS location for a delivery assignment."""
    result = await db.execute(
        select(GpsTrackingLog)
        .where(GpsTrackingLog.assignment_id == assignment_id)
        .order_by(GpsTrackingLog.recorded_at.desc())
        .limit(1)
    )
    log = result.scalar_one_or_none()
    if not log:
        raise HTTPException(status_code=404, detail="No GPS data available yet")

    return GpsLocationResponse(
        latitude=float(log.latitude),
        longitude=float(log.longitude),
        accuracy_meters=float(log.accuracy_meters) if log.accuracy_meters else None,
        speed_kmph=float(log.speed_kmph) if log.speed_kmph else None,
        recorded_at=log.recorded_at,
    )


@router.websocket("/ws/track/{assignment_id}")
async def websocket_track(
    websocket: WebSocket,
    assignment_id: str,
):
    """WebSocket endpoint — streams real-time GPS to customer."""
    await websocket.accept()
    redis = await get_redis()
    pubsub = redis.pubsub()
    await pubsub.subscribe(f"gps:{assignment_id}")
    try:
        async for message in pubsub.listen():
            if message["type"] == "message":
                await websocket.send_text(message["data"])
    except WebSocketDisconnect:
        pass
    finally:
        await pubsub.unsubscribe(f"gps:{assignment_id}")
        await redis.close()


# ── Delivery Charge Router ───────────────────────────────────────────────────
delivery_router = APIRouter(prefix="/delivery", tags=["Delivery Charge"])

from app.services.delivery_engine import haversine
from app.models.admin_settings import AdminSettings
from app.models.address import Address
from app.models.package_cart import PackageCart
from app.models.product import Product

@delivery_router.post("/calculate-charge")
async def calculate_delivery_charge(
    payload: dict,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    address_id_str = payload.get("address_id")
    order_type = payload.get("order_type", "package")
    
    if not address_id_str:
        raise HTTPException(status_code=400, detail="address_id is required")
        
    try:
        address_id = UUID(address_id_str)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid address_id format")
        
    # Get address
    addr_result = await db.execute(
        select(Address).where(and_(Address.id == address_id, Address.user_id == current_user.id))
    )
    address = addr_result.scalar_one_or_none()
    if not address:
        raise HTTPException(status_code=404, detail="Address not found")
        
    # Get admin settings
    settings_result = await db.execute(select(AdminSettings).where(AdminSettings.id == 1))
    settings_obj = settings_result.scalar_one_or_none()
    
    distance = 0.0
    delivery_charge = 0.0
    
    if settings_obj:
        if address.latitude and address.longitude:
            distance = haversine(
                9.919630, 78.094379,
                float(address.latitude), float(address.longitude)
            )
            
        charge_per_delivery = max(0.0, distance - float(settings_obj.free_delivery_radius_km)) * float(settings_obj.delivery_charge_per_km)
        
        if order_type == "package":
            customer_result = await db.execute(select(Customer).where(Customer.user_id == current_user.id))
            customer = customer_result.scalar_one_or_none()
            highest_days = 6
            if customer:
                cart_result = await db.execute(
                    select(PackageCart)
                    .where(PackageCart.customer_id == customer.id)
                    .options(selectinload(PackageCart.product))
                )
                cart_items = cart_result.scalars().all()
                for item in cart_items:
                    if item.product.package_days > highest_days:
                        highest_days = item.product.package_days
            delivery_charge = highest_days * charge_per_delivery
        else:
            delivery_charge = 1 * charge_per_delivery
            
    return {
        "delivery_charge": round(delivery_charge, 2),
        "distance_km": round(distance, 2)
    }

