import math
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from datetime import datetime, timezone
import uuid

from app.models.delivery_partner import DeliveryPartner
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
from app.models.address import Address
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


def calculate_charge_for_distance(distance: float, settings_obj) -> float:
    """Calculate delivery charge based on configured settings and distance tiers."""
    charge_0_to_5 = float(getattr(settings_obj, "delivery_charge_0_to_5_km", 0.0))
    charge_5_to_10 = float(getattr(settings_obj, "delivery_charge_5_to_10_km", 15.0))
    charge_10_to_15 = float(getattr(settings_obj, "delivery_charge_10_to_15_km", 25.0))
    
    if distance <= 5.0:
        return charge_0_to_5
    elif distance <= 10.0:
        return charge_5_to_10
    else:
        return charge_10_to_15


async def auto_assign_delivery(
    db: AsyncSession,
    delivery: SubscriptionDelivery
) -> Optional[DeliveryAssignment]:
    """
    Business Rules for Assignment:
    1. Within 3km radius (Distance Matrix / Mock Haversine).
    2. Max workload: 30 active deliveries per boy.
    3. Round-robin assignment if multiple match (based on fewest current deliveries).
    4. If no delivery partner available -> mark "Unassigned" and alert Admin.
    5. Delivery Partner gets push notification to accept/reject.
    """
    
    # 1. Get destination coordinates from subscription -> address
    stmt = (
        select(Address.latitude, Address.longitude)
        .join(Subscription, Subscription.address_id == Address.id)
        .where(Subscription.id == delivery.subscription_id)
    )
    result = await db.execute(stmt)
    row = result.first()
    
    if not row or not row.latitude or not row.longitude:
        # Address doesn't have coordinates, fallback or fail
        return None
        
    dest_lat, dest_lng = float(row.latitude), float(row.longitude)
    
    # 2. Get all available delivery partners
    partners_stmt = select(DeliveryPartner).where(DeliveryPartner.is_available == True)
    partners_result = await db.execute(partners_stmt)
    available_partners = partners_result.scalars().all()
    
    if not available_partners:
        return None
        
    # 3. Filter by capacity (< 30 active deliveries)
    eligible_partners = []
    
    for partner in available_partners:
        # Check active assignments (PENDING, ACCEPTED, OUT_FOR_DELIVERY)
        active_count_stmt = select(func.count()).select_from(DeliveryAssignment).where(
            and_(
                DeliveryAssignment.delivery_partner_id == partner.id,
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
        # Here we assume hub is at dest_lat, dest_lng for testing if partner has no current_lat
        partner_lat = float(partner.current_lat) if partner.current_lat else None
        partner_lng = float(partner.current_lng) if partner.current_lng else None
        
        if partner_lat and partner_lng:
            dist = haversine(dest_lat, dest_lng, partner_lat, partner_lng)
            if dist > MAX_RADIUS_KM:
                continue
        else:
            # If we don't know where the partner is, give them a penalty distance or skip
            dist = 0.0 # Mock dist for partners without GPS
            
        eligible_partners.append({
            'partner': partner,
            'active_count': active_count,
            'distance': dist
        })
        
    if not eligible_partners:
        return None
        
    # 5. Round Robin / Load Balancing: Sort by fewest active assignments, then distance
    eligible_partners.sort(key=lambda x: (x['active_count'], x['distance']))
    
    best_match = eligible_partners[0]['partner']
    dist = eligible_partners[0]['distance']
    
    # 6. Create Assignment
    assignment = DeliveryAssignment(
        subscription_delivery_id=delivery.id,
        delivery_partner_id=best_match.id,
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
        data={"assignment_id": str(assignment.id), "type": "new_assignment"},
        db=db,
    )
    
    return assignment


async def process_unassigned_deliveries(db: AsyncSession):
    """Cron job or background task to find partners for pending deliveries."""
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
