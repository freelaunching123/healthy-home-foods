import logging
from uuid import UUID
from datetime import datetime, date
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_
from sqlalchemy.orm import selectinload, aliased

from app.db.session import get_db
from app.core.dependencies import require_super_admin
from app.models.user import User
from app.models.customer import Customer
from app.models.delivery_partner import DeliveryPartner
from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.subscription import Subscription, SubscriptionItem
from app.models.product import Product
from app.models.fruit import FruitOrder, FruitOrderStatus, FruitOrderItem, Fruit
from app.models.address import Address
from app.schemas.common import MessageResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin/orders", tags=["Admin Unified Orders"])

class UnifiedOrderResponse(BaseModel):
    id: str  # subscription_delivery_id or fruit_order_id
    order_id: str  # order number or formatted subscription delivery id
    order_type: str  # "subscription" or "fruit"
    customer_name: str
    customer_phone: str
    delivery_address: str
    ordered_items: str
    total_amount: float
    payment_status: str
    order_date_time: str
    status: str  # pending_assignment, assigned, out_for_delivery, delivered, failed
    delivery_partner_id: Optional[str] = None
    delivery_partner_name: Optional[str] = None
    delivery_partner_phone: Optional[str] = None

# Aliases to avoid joins collision
CustomerUser = aliased(User, name="cust_user")
PartnerUser = aliased(User, name="part_user")

@router.get("/all", response_model=List[UnifiedOrderResponse])
async def list_all_orders(
    status: Optional[str] = Query(None, description="pending_assignment, assigned, out_for_delivery, delivered, failed"),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    """Get all paid subscription deliveries and fruit orders unified for Admin management."""
    unified_orders = []

    # ── 1. Fetch Subscription Deliveries ──────────────────────────────────────
    sub_stmt = (
        select(
            SubscriptionDelivery,
            Subscription,
            Customer,
            CustomerUser,
            Address,
            DeliveryAssignment,
            DeliveryPartner,
            PartnerUser
        )
        .join(Subscription, Subscription.id == SubscriptionDelivery.subscription_id)
        .join(Customer, Customer.id == Subscription.customer_id)
        .join(CustomerUser, CustomerUser.id == Customer.user_id)
        .join(Address, Address.id == Subscription.address_id)
        .outerjoin(DeliveryAssignment, DeliveryAssignment.subscription_delivery_id == SubscriptionDelivery.id)
        .outerjoin(DeliveryPartner, DeliveryPartner.id == DeliveryAssignment.delivery_partner_id)
        .outerjoin(PartnerUser, PartnerUser.id == DeliveryPartner.user_id)
        .options(
            selectinload(SubscriptionDelivery.subscription).selectinload(Subscription.items).selectinload(SubscriptionItem.product)
        )
    )
    
    sub_result = await db.execute(sub_stmt)
    sub_rows = sub_result.all()

    for row in sub_rows:
        deliv, sub, cust, c_user, addr, assign, partner, p_user = row
        
        # Build items summary
        items = ", ".join([f"{item.product.name} ({item.quantity})" for item in sub.items if item.product])
        if not items:
            items = "Subscription Meal Plan"
            
        addr_str = f"{addr.address_line1}, {addr.city}, {addr.pincode}"
        if addr.landmark:
            addr_str += f" (Landmark: {addr.landmark})"
            
        # Determine status
        unified_status = "pending_assignment"
        if assign:
            if assign.status == AssignmentStatus.DELIVERED:
                unified_status = "delivered"
            elif assign.status == AssignmentStatus.FAILED:
                unified_status = "failed"
            elif assign.status == AssignmentStatus.OUT_FOR_DELIVERY:
                unified_status = "out_for_delivery"
            else:
                unified_status = "assigned"
                
        # Filter status if requested
        if status and unified_status != status:
            continue
            
        unified_orders.append(UnifiedOrderResponse(
            id=str(deliv.id),
            order_id=f"SUB-{str(deliv.id)[:8].upper()}",
            order_type="subscription",
            customer_name=c_user.full_name,
            customer_phone=c_user.phone,
            delivery_address=addr_str,
            ordered_items=items,
            total_amount=float(sub.price_per_delivery) if sub.price_per_delivery else float(sub.total_amount) / sub.total_deliveries,
            payment_status="Paid",  # active subscription is paid
            order_date_time=deliv.created_at.isoformat() if deliv.created_at else datetime.now().isoformat(),
            status=unified_status,
            delivery_partner_id=str(partner.id) if partner else None,
            delivery_partner_name=p_user.full_name if p_user else None,
            delivery_partner_phone=p_user.phone if p_user else None,
        ))

    # ── 2. Fetch Fruit Orders ─────────────────────────────────────────────────
    fruit_stmt = (
        select(
            FruitOrder,
            Customer,
            CustomerUser,
            Address,
            DeliveryAssignment,
            DeliveryPartner,
            PartnerUser
        )
        .join(Customer, Customer.id == FruitOrder.customer_id)
        .join(CustomerUser, CustomerUser.id == Customer.user_id)
        .join(Address, Address.id == FruitOrder.address_id)
        .outerjoin(DeliveryAssignment, DeliveryAssignment.fruit_order_id == FruitOrder.id)
        .outerjoin(DeliveryPartner, DeliveryPartner.id == DeliveryAssignment.delivery_partner_id)
        .outerjoin(PartnerUser, PartnerUser.id == DeliveryPartner.user_id)
        .options(
            selectinload(FruitOrder.items).selectinload(FruitOrderItem.fruit)
        )
        .where(FruitOrder.payment_status == "success")  # Only show paid fruit orders
    )
    
    fruit_result = await db.execute(fruit_stmt)
    fruit_rows = fruit_result.all()

    for row in fruit_rows:
        order, cust, c_user, addr, assign, partner, p_user = row
        
        # Build items summary
        items = ", ".join([f"{item.fruit.name} ({item.quantity_kg} kg)" for item in order.items if item.fruit])
        if not items:
            items = "Fresh Fruits"
            
        addr_str = f"{addr.address_line1}, {addr.city}, {addr.pincode}"
        if addr.landmark:
            addr_str += f" (Landmark: {addr.landmark})"
            
        # Determine status
        unified_status = "pending_assignment"
        if assign:
            if assign.status == AssignmentStatus.DELIVERED:
                unified_status = "delivered"
            elif assign.status == AssignmentStatus.FAILED:
                unified_status = "failed"
            elif assign.status == AssignmentStatus.OUT_FOR_DELIVERY:
                unified_status = "out_for_delivery"
            else:
                unified_status = "assigned"
                
        # Filter status if requested
        if status and unified_status != status:
            continue
            
        unified_orders.append(UnifiedOrderResponse(
            id=str(order.id),
            order_id=order.order_number,
            order_type="fruit",
            customer_name=c_user.full_name,
            customer_phone=c_user.phone,
            delivery_address=addr_str,
            ordered_items=items,
            total_amount=float(order.total_amount),
            payment_status="Paid",
            order_date_time=order.created_at.isoformat() if order.created_at else datetime.now().isoformat(),
            status=unified_status,
            delivery_partner_id=str(partner.id) if partner else None,
            delivery_partner_name=p_user.full_name if p_user else None,
            delivery_partner_phone=p_user.phone if p_user else None,
        ))

    # Sort unified orders by date desc
    unified_orders.sort(key=lambda o: o.order_date_time, reverse=True)
    return unified_orders
