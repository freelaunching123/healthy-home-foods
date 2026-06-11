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
from app.core.dependencies import get_current_user, require_super_admin, require_delivery_boy
from app.models.user import User
from app.models.delivery_boy import DeliveryBoy
from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.gps_tracking import GpsTrackingLog
from app.schemas.common import (
    AssignDeliveryRequest, UpdateDeliveryStatusRequest, AssignmentResponse,
    GpsUpdateRequest, GpsLocationResponse, MessageResponse,
)
from app.services import subscription_engine
from app.core.config import settings

router = APIRouter(prefix="/deliveries", tags=["Deliveries & GPS"])


async def get_redis():
    return await aioredis.from_url(settings.REDIS_URL, decode_responses=True)


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
    """Manually assign a delivery to a specific delivery boy."""
    delivery_result = await db.execute(
        select(SubscriptionDelivery).where(SubscriptionDelivery.id == payload.delivery_id)
    )
    delivery = delivery_result.scalar_one_or_none()
    if not delivery:
        raise HTTPException(status_code=404, detail="Delivery not found")

    boy_result = await db.execute(
        select(DeliveryBoy).where(DeliveryBoy.id == payload.delivery_boy_id)
    )
    boy = boy_result.scalar_one_or_none()
    if not boy:
        raise HTTPException(status_code=404, detail="Delivery boy not found")

    assignment = DeliveryAssignment(
        delivery_id=delivery.id,
        delivery_boy_id=boy.id,
        status=AssignmentStatus.PENDING,
        assigned_at=datetime.now(timezone.utc),
    )
    db.add(assignment)
    delivery.status = DeliveryStatus.ASSIGNED
    await db.commit()
    await db.refresh(assignment)
    return assignment


# ── Delivery boy: View assigned deliveries ─────────────────────────────────────

@router.get("/assigned", response_model=list[AssignmentResponse])
async def get_my_assignments(
    current_user: User = Depends(require_delivery_boy),
    db: AsyncSession = Depends(get_db),
    delivery_date: date = Query(default=date.today()),
):
    boy_result = await db.execute(
        select(DeliveryBoy).where(DeliveryBoy.user_id == current_user.id)
    )
    boy = boy_result.scalar_one_or_none()
    if not boy:
        raise HTTPException(status_code=404, detail="Delivery boy profile not found")

    result = await db.execute(
        select(DeliveryAssignment)
        .join(SubscriptionDelivery, DeliveryAssignment.delivery_id == SubscriptionDelivery.id)
        .where(
            and_(
                DeliveryAssignment.delivery_boy_id == boy.id,
                SubscriptionDelivery.scheduled_date == delivery_date,
            )
        )
    )
    return result.scalars().all()


@router.put("/{assignment_id}/status", response_model=MessageResponse)
async def update_delivery_status(
    assignment_id: UUID,
    payload: UpdateDeliveryStatusRequest,
    current_user: User = Depends(require_delivery_boy),
    db: AsyncSession = Depends(get_db),
):
    """Delivery boy updates assignment status (accepted/out_for_delivery/delivered/failed)."""
    result = await db.execute(
        select(DeliveryAssignment).where(DeliveryAssignment.id == assignment_id)
    )
    assignment = result.scalar_one_or_none()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    now = datetime.now(timezone.utc)
    if payload.status == "accepted":
        assignment.status = AssignmentStatus.ACCEPTED
        assignment.accepted_at = now
    elif payload.status == "out_for_delivery":
        assignment.status = AssignmentStatus.OUT_FOR_DELIVERY
        assignment.out_at = now
        delivery_result = await db.execute(
            select(SubscriptionDelivery).where(SubscriptionDelivery.id == assignment.delivery_id)
        )
        delivery = delivery_result.scalar_one()
        delivery.status = DeliveryStatus.OUT_FOR_DELIVERY
    elif payload.status == "delivered":
        assignment.status = AssignmentStatus.DELIVERED
        delivery_result = await db.execute(
            select(SubscriptionDelivery).where(SubscriptionDelivery.id == assignment.delivery_id)
        )
        delivery = delivery_result.scalar_one()
        await subscription_engine.mark_delivered(db, delivery)
        assignment.delivered_at = now
    elif payload.status == "failed":
        assignment.status = AssignmentStatus.FAILED
        assignment.failed_at = now
        assignment.failure_reason = payload.failure_reason
        delivery_result = await db.execute(
            select(SubscriptionDelivery).where(SubscriptionDelivery.id == assignment.delivery_id)
        )
        delivery = delivery_result.scalar_one()
        await subscription_engine.handle_missed_delivery(db, delivery)
    else:
        raise HTTPException(status_code=400, detail=f"Invalid status: {payload.status}")

    await db.commit()
    return MessageResponse(message=f"Status updated to {payload.status}")


@router.post("/{assignment_id}/proof", response_model=MessageResponse)
async def upload_delivery_proof(
    assignment_id: UUID,
    file: UploadFile = File(...),
    current_user: User = Depends(require_delivery_boy),
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
    current_user: User = Depends(require_delivery_boy),
    db: AsyncSession = Depends(get_db),
):
    """Delivery boy sends live location. Stored in DB + broadcasted via Redis."""
    boy_result = await db.execute(
        select(DeliveryBoy).where(DeliveryBoy.user_id == current_user.id)
    )
    boy = boy_result.scalar_one_or_none()
    if not boy:
        raise HTTPException(status_code=404, detail="Delivery boy profile not found")

    # Update current location on delivery boy
    boy.current_lat = payload.latitude
    boy.current_lng = payload.longitude

    # Store GPS log
    gps_log = GpsTrackingLog(
        assignment_id=payload.assignment_id,
        delivery_boy_id=boy.id,
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
        "delivery_boy_name": current_user.full_name,
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
