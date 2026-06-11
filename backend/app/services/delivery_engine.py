import math
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from datetime import datetime, timezone
import uuid

from app.models.delivery_boy import DeliveryBoy
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
from app.models.user_address import UserAddress
from app.models.subscription import Subscription
from app.services.notification_service import NotificationService

# Constants
MAX_WORKLOAD = 30
MAX_RADIUS_KM = 3.0


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance in km between two points using Haversine formula."""
    R = 6371.0  # Earth radius in km
    
    # Convert latitude and longitude to radians
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    
    a = math.sin(dphi / 2)**2 + \
        math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2)**2
    
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    distance = R * c
    return distance


async def auto_assign_delivery(
    db: AsyncSession,
    delivery: SubscriptionDelivery
) -> Optional[DeliveryAssignment]:
    """
    Business Rules for Assignment:
    1. Within 3km radius (Distance Matrix / Mock Haversine).
    2. Max workload: 30 active deliveries per boy.
    3. Round-robin assignment if multiple match (based on fewest current deliveries).
    4. If no delivery boy available -> mark "Unassigned" and alert Admin.
    5. Delivery Boy gets push notification to accept/reject.
    """
    
    # 1. Get destination coordinates from subscription -> address
    stmt = (
        select(UserAddress.latitude, UserAddress.longitude)
        .join(Subscription, Subscription.address_id == UserAddress.id)
        .where(Subscription.id == delivery.subscription_id)
    )
    result = await db.execute(stmt)
    row = result.first()
    
    if not row or not row.latitude or not row.longitude:
        # Address doesn't have coordinates, fallback or fail
        return None
        
    dest_lat, dest_lng = float(row.latitude), float(row.longitude)
    
    # 2. Get all available delivery boys
    boys_stmt = select(DeliveryBoy).where(DeliveryBoy.is_available == True)
    boys_result = await db.execute(boys_stmt)
    available_boys = boys_result.scalars().all()
    
    if not available_boys:
        return None
        
    # 3. Filter by capacity (< 30 active deliveries)
    eligible_boys = []
    
    for boy in available_boys:
        # Check active assignments (PENDING, ACCEPTED, OUT_FOR_DELIVERY)
        active_count_stmt = select(func.count()).select_from(DeliveryAssignment).where(
            and_(
                DeliveryAssignment.delivery_boy_id == boy.id,
                DeliveryAssignment.status.in_([
                    AssignmentStatus.PENDING,
                    AssignmentStatus.ACCEPTED,
                    AssignmentStatus.OUT_FOR_DELIVERY
                ])
            )
        )
        active_count_result = await db.execute(active_count_stmt)
        active_count = active_count_result.scalar_one_or_none() or 0
        
        if active_count >= MAX_WORKLOAD:
            continue
            
        # 4. Filter by radius (<= 3km)
        # Using current_lat/lng if available, otherwise assume they start from hub
        # Here we assume hub is at dest_lat, dest_lng for testing if boy has no current_lat
        boy_lat = float(boy.current_lat) if boy.current_lat else None
        boy_lng = float(boy.current_lng) if boy.current_lng else None
        
        if boy_lat and boy_lng:
            dist = haversine(dest_lat, dest_lng, boy_lat, boy_lng)
            if dist > MAX_RADIUS_KM:
                continue
        else:
            # If we don't know where the boy is, give them a penalty distance or skip
            dist = 0.0 # Mock dist for boys without GPS
            
        eligible_boys.append({
            'boy': boy,
            'active_count': active_count,
            'distance': dist
        })
        
    if not eligible_boys:
        return None
        
    # 5. Round Robin / Load Balancing: Sort by fewest active assignments, then distance
    eligible_boys.sort(key=lambda x: (x['active_count'], x['distance']))
    
    best_match = eligible_boys[0]['boy']
    dist = eligible_boys[0]['distance']
    
    # 6. Create Assignment
    assignment = DeliveryAssignment(
        delivery_id=delivery.id,
        delivery_boy_id=best_match.id,
        status=AssignmentStatus.PENDING,
        assigned_at=datetime.now(timezone.utc),
        distance_km=dist,
        estimated_minutes=int(dist * 3) + 5 # Rough estimate: 3 mins per km + 5 mins buffer
    )
    db.add(assignment)
    
    # Update Delivery status
    delivery.status = DeliveryStatus.ASSIGNED
    
    # In a real app, send FCM push notification here
    await NotificationService.send_push_notification(
        user_id=str(best_match.user_id),
        title="New Delivery Assigned!",
        body=f"You have a new delivery assigned. Distance: {dist:.2f}km.",
        data={"assignment_id": str(assignment.id), "type": "new_assignment"}
    )
    
    return assignment


async def process_unassigned_deliveries(db: AsyncSession):
    """Cron job or background task to find boys for pending deliveries."""
    stmt = select(SubscriptionDelivery).where(SubscriptionDelivery.status == DeliveryStatus.PENDING)
    result = await db.execute(stmt)
    pending_deliveries = result.scalars().all()
    
    assigned_count = 0
    for delivery in pending_deliveries:
        assignment = await auto_assign_delivery(db, delivery)
        if assignment:
            assigned_count += 1
            
    if assigned_count > 0:
        await db.commit()
        
    return assigned_count
