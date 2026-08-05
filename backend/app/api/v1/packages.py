import hmac, hashlib
from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from sqlalchemy.orm import selectinload
import razorpay

from app.db.session import get_db
from app.core.dependencies import get_current_user, require_customer, require_super_admin
from app.models.user import User
from app.models.customer import Customer
from app.models.product import Product
from app.models.package_cart import PackageCart
from app.models.subscription import Subscription, SubscriptionStatus, SubscriptionPlan, SubscriptionItem
from app.models.payment import Payment, PaymentStatus, PaymentMethod
from app.models.invoice import Invoice
from app.models.address import Address
from app.models.admin_settings import AdminSettings
from app.schemas.package import (
    PackageCartAddRequest, PackageCartUpdateRequest, PackageCartResponse, PackageCartItemResponse
)
from app.schemas.common import MessageResponse
from app.services import subscription_engine
from app.services.notification_service import NotificationService
from app.services.delivery_engine import haversine
from app.services.payment_service import PaymentService
from app.core.config import settings

router = APIRouter(prefix="/packages", tags=["Package Cart & Orders"])


def _razorpay_client():
    return razorpay.Client(auth=(settings.RAZORPAY_KEY_ID or "mock", settings.RAZORPAY_KEY_SECRET or "mock"))


async def _get_customer(db: AsyncSession, user_id: UUID) -> Customer:
    result = await db.execute(select(Customer).where(Customer.user_id == user_id))
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer profile not found")
    return customer


# ── Cart Endpoints ───────────────────────────────────────────────────────────

@router.get("/cart", response_model=PackageCartResponse)
async def get_cart(
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db)
):
    """Get the current customer's package cart."""
    customer = await _get_customer(db, current_user.id)
    
    result = await db.execute(
        select(PackageCart)
        .where(PackageCart.customer_id == customer.id)
        .options(selectinload(PackageCart.product))
        .order_by(PackageCart.created_at)
    )
    cart_items = result.scalars().all()
    
    items_out = []
    total = 0.0
    for item in cart_items:
        subtotal = float(item.subtotal)
        total += subtotal
        
        # Calculate full image path
        img_url = item.product.image_url
        
        items_out.append(
            PackageCartItemResponse(
                id=item.id,
                product_id=item.product_id,
                product_name=item.product.name,
                product_image_url=img_url,
                quantity=item.quantity,
                unit_price=float(item.unit_price),
                subtotal=subtotal
            )
        )
        
    return PackageCartResponse(
        items=items_out,
        total_amount=round(total, 2),
        item_count=len(items_out)
    )


@router.post("/cart/add", response_model=PackageCartItemResponse)
async def add_to_cart(
    payload: PackageCartAddRequest,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db)
):
    """Add or update a product in the package cart (upsert)."""
    customer = await _get_customer(db, current_user.id)
    
    prod_result = await db.execute(select(Product).where(Product.id == payload.product_id))
    product = prod_result.scalar_one_or_none()
    if not product or not product.is_active:
        raise HTTPException(status_code=404, detail="Product not found or inactive")
        
    price = float(product.discount_price if product.discount_price else product.package_price)
    
    # Check if item exists
    existing_result = await db.execute(
        select(PackageCart).where(
            and_(
                PackageCart.customer_id == customer.id,
                PackageCart.product_id == payload.product_id
            )
        )
    )
    cart_item = existing_result.scalar_one_or_none()
    
    if cart_item:
        cart_item.quantity = payload.quantity
        cart_item.unit_price = price
        cart_item.subtotal = round(payload.quantity * price, 2)
    else:
        cart_item = PackageCart(
            customer_id=customer.id,
            product_id=payload.product_id,
            quantity=payload.quantity,
            unit_price=price,
            subtotal=round(payload.quantity * price, 2)
        )
        db.add(cart_item)
        
    await db.commit()
    await db.refresh(cart_item)
    
    return PackageCartItemResponse(
        id=cart_item.id,
        product_id=cart_item.product_id,
        product_name=product.name,
        product_image_url=product.image_url,
        quantity=cart_item.quantity,
        unit_price=float(cart_item.unit_price),
        subtotal=float(cart_item.subtotal)
    )


@router.put("/cart/{cart_item_id}", response_model=PackageCartItemResponse)
async def update_cart_item(
    cart_item_id: UUID,
    payload: PackageCartUpdateRequest,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db)
):
    """Update the quantity of a package cart item."""
    customer = await _get_customer(db, current_user.id)
    
    result = await db.execute(
        select(PackageCart)
        .where(and_(PackageCart.id == cart_item_id, PackageCart.customer_id == customer.id))
        .options(selectinload(PackageCart.product))
    )
    cart_item = result.scalar_one_or_none()
    if not cart_item:
        raise HTTPException(status_code=404, detail="Cart item not found")
        
    price = float(cart_item.product.discount_price if cart_item.product.discount_price else cart_item.product.package_price)
    cart_item.quantity = payload.quantity
    cart_item.unit_price = price
    cart_item.subtotal = round(payload.quantity * price, 2)
    
    await db.commit()
    await db.refresh(cart_item)
    
    return PackageCartItemResponse(
        id=cart_item.id,
        product_id=cart_item.product_id,
        product_name=cart_item.product.name,
        product_image_url=cart_item.product.image_url,
        quantity=cart_item.quantity,
        unit_price=float(cart_item.unit_price),
        subtotal=float(cart_item.subtotal)
    )


@router.delete("/cart/clear", response_model=MessageResponse)
async def clear_cart_endpoint(
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db)
):
    """Clear the entire package cart for the current customer."""
    customer = await _get_customer(db, current_user.id)
    
    result = await db.execute(select(PackageCart).where(PackageCart.customer_id == customer.id))
    items = result.scalars().all()
    for item in items:
        await db.delete(item)
        
    await db.commit()
    return MessageResponse(message="Cart cleared successfully")


@router.delete("/cart/{cart_item_id}", response_model=MessageResponse)
async def remove_from_cart(
    cart_item_id: UUID,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db)
):
    """Remove a single item from the package cart."""
    customer = await _get_customer(db, current_user.id)
    
    result = await db.execute(
        select(PackageCart).where(and_(PackageCart.id == cart_item_id, PackageCart.customer_id == customer.id))
    )
    cart_item = result.scalar_one_or_none()
    if not cart_item:
        raise HTTPException(status_code=404, detail="Cart item not found")
        
    await db.delete(cart_item)
    await db.commit()
    return MessageResponse(message="Item removed from cart")


# ── Checkout Endpoints ───────────────────────────────────────────────────────

@router.post("/orders/checkout", response_model=dict)
async def checkout(
    payload: dict, # expecting {"address_id": "..."}
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db)
):
    """Create a subscription from the package cart and return Razorpay details."""
    customer = await _get_customer(db, current_user.id)
    
    address_id_str = payload.get("address_id")
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
        
    # Get cart items
    cart_result = await db.execute(
        select(PackageCart)
        .where(PackageCart.customer_id == customer.id)
        .options(selectinload(PackageCart.product))
    )
    cart_items = cart_result.scalars().all()
    if not cart_items:
        raise HTTPException(status_code=400, detail="Cart is empty")
        
    # 1. Get delivery distance & calculate delivery charge per delivery day
    settings_result = await db.execute(select(AdminSettings).where(AdminSettings.id == 1))
    settings_obj = settings_result.scalar_one_or_none()
    
    distance = 0.0
    charge_per_delivery = 0.0
    tax_rate = 0.0
    
    if settings_obj:
        if address.latitude and address.longitude:
            shop_lat = float(settings_obj.business_lat) if settings_obj.business_lat is not None else 9.919630
            shop_lng = float(settings_obj.business_lng) if settings_obj.business_lng is not None else 78.094379
            distance = haversine(
                shop_lat, shop_lng,
                float(address.latitude), float(address.longitude)
            )
        max_dist = float(getattr(settings_obj, "max_delivery_distance_km", 15.0))
        if distance > max_dist:
            raise HTTPException(
                status_code=400,
                detail=f"There is no service beyond {max_dist}km. Please select an address within the range."
            )
        from app.services.delivery_engine import calculate_charge_for_distance
        charge_per_delivery = calculate_charge_for_distance(distance, settings_obj)
        tax_rate = float(settings_obj.tax_percentage) / 100

    # 2. Create an individual Subscription per product item in cart
    subs_created = []
    total_checkout_amount = 0.0

    for item in cart_items:
        qty = item.quantity
        product = item.product
        unit_price = float(product.discount_price if product.discount_price else product.package_price)
        item_total_price = unit_price * qty
        package_days = product.package_days if (product.package_days and product.package_days > 0) else 6

        item_del_charge = package_days * charge_per_delivery
        item_tax_amt = round(item_total_price * tax_rate, 2)

        # Retrieve SubscriptionPlan matching plan_type
        plan_result = await db.execute(
            select(SubscriptionPlan)
            .where(and_(SubscriptionPlan.plan_type == product.plan_type, SubscriptionPlan.is_active == True))
            .limit(1)
        )
        sub_plan = plan_result.scalar_one_or_none()
        plan_id = sub_plan.id if sub_plan else None

        item_data = [{
            "product": product,
            "quantity": qty,
            "package_price": unit_price
        }]

        sub = await subscription_engine.create_subscription(
            db=db,
            customer=customer,
            items_data=item_data,
            plan_type=product.plan_type or "weekly",
            total_deliveries=package_days,
            plan_id=plan_id,
            address_id=address.id,
            delivery_charge=item_del_charge,
            tax_amount=item_tax_amt
        )
        subs_created.append(sub)
        total_checkout_amount += float(sub.total_amount)

    first_sub = subs_created[0]

    # 3. Save Payment record using PaymentService with combined total amount
    payment = await PaymentService.initiate_mock_payment(
        db=db,
        customer_id=customer.id,
        subscription_id=first_sub.id,
        amount=round(total_checkout_amount, 2)
    )
    
    return {
        "gateway_order_id": payment.gateway_order_id,
        "razorpay_key_id": settings.RAZORPAY_KEY_ID or "mock_key",
        "total_amount": round(total_checkout_amount, 2),
        "order_number": str(first_sub.id)[:8].upper()
    }


@router.post("/orders/verify-payment", response_model=MessageResponse)
async def verify_payment(
    payload: dict, # expecting {"razorpay_order_id": "...", "razorpay_payment_id": "...", "razorpay_signature": "..."}
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db)
):
    """Verify payment signature, activate subscription and clear package cart."""
    razorpay_order_id = payload.get("razorpay_order_id")
    razorpay_payment_id = payload.get("razorpay_payment_id")
    razorpay_signature = payload.get("razorpay_signature", "")

    if not all([razorpay_order_id, razorpay_payment_id]):
        raise HTTPException(status_code=400, detail="Missing payment verification fields")

    # Verify and activate subscription via PaymentService
    await PaymentService.verify_payment(
        db=db,
        gateway_order_id=razorpay_order_id,
        gateway_payment_id=razorpay_payment_id,
        gateway_signature=razorpay_signature,
        user=current_user
    )
    
    # Clear cart
    customer = await _get_customer(db, current_user.id)
    cart_result = await db.execute(select(PackageCart).where(PackageCart.customer_id == customer.id))
    for item in cart_result.scalars().all():
        await db.delete(item)
        
    await db.commit()
    return MessageResponse(message="Payment verified and subscription activated")


@router.get("/orders/admin/package-orders", response_model=list)
async def list_admin_package_orders(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_super_admin),
):
    """Retrieve all package orders (subscriptions) for admin view."""
    stmt = (
        select(Subscription)
        .options(
            selectinload(Subscription.customer).selectinload(Customer.user),
            selectinload(Subscription.items).selectinload(SubscriptionItem.product),
            selectinload(Subscription.payments),
        )
        .order_by(Subscription.created_at.desc())
    )
    result = await db.execute(stmt)
    subscriptions = result.scalars().all()

    orders_list = []
    for sub in subscriptions:
        latest_payment = None
        if sub.payments:
            sorted_payments = sorted(sub.payments, key=lambda p: p.created_at or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
            latest_payment = sorted_payments[0]
            
        c_user = sub.customer.user if sub.customer else None
        
        items_list = []
        for item in sub.items:
            items_list.append({
                "product_name": item.product.name if item.product else "Unknown Product",
                "quantity": item.quantity,
                "package_price": float(item.package_price) if item.package_price else 0.0,
                "subtotal": float(item.package_price or 0.0) * item.quantity,
            })
            
        if not items_list and sub.product_id:
            from app.models.product import Product
            prod = await db.get(Product, sub.product_id)
            items_list.append({
                "product_name": prod.name if prod else "Meal Plan",
                "quantity": 1,
                "package_price": float(sub.package_price) if sub.package_price else float(sub.total_amount),
                "subtotal": float(sub.total_amount),
            })

        orders_list.append({
            "id": str(sub.id),
            "order_number": f"PKG-{str(sub.id)[:8].upper()}",
            "customer_name": c_user.full_name if c_user else "Unknown Customer",
            "customer_phone": c_user.phone if c_user else "N/A",
            "payment_status": "success" if sub.status != SubscriptionStatus.PENDING_PAYMENT else "pending",
            "gateway_order_id": latest_payment.gateway_order_id if latest_payment else "N/A",
            "gateway_payment_id": latest_payment.gateway_payment_id if latest_payment else "N/A",
            "total_amount": float(sub.total_amount),
            "created_at": sub.created_at.isoformat() if sub.created_at else datetime.now().isoformat(),
            "items": items_list,
            "delivery_partner_id": str(sub.delivery_partner_id) if sub.delivery_partner_id else None,
        })
        
    return orders_list

from pydantic import BaseModel
class AdminPackageAssignRequest(BaseModel):
    delivery_partner_id: UUID | None = None

@router.post("/orders/admin/package-orders/{sub_id}/assign", response_model=MessageResponse)
async def assign_package_delivery_partner(
    sub_id: UUID,
    payload: AdminPackageAssignRequest,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Assign a delivery partner to an entire subscription package."""
    sub_result = await db.execute(select(Subscription).where(Subscription.id == sub_id))
    subscription = sub_result.scalar_one_or_none()
    if not subscription:
        raise HTTPException(status_code=404, detail="Subscription not found")

    subscription.delivery_partner_id = payload.delivery_partner_id
    await db.commit()

    if payload.delivery_partner_id:
        # Also assign any current PENDING deliveries
        from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
        from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
        
        pending_deliveries_result = await db.execute(
            select(SubscriptionDelivery).where(
                SubscriptionDelivery.subscription_id == subscription.id,
                SubscriptionDelivery.status == DeliveryStatus.PENDING
            )
        )
        for delivery in pending_deliveries_result.scalars().all():
            # Update or create assignment
            assignment_result = await db.execute(
                select(DeliveryAssignment).where(DeliveryAssignment.subscription_delivery_id == delivery.id)
            )
            assignment = assignment_result.scalar_one_or_none()
            if assignment:
                assignment.delivery_partner_id = payload.delivery_partner_id
                assignment.status = AssignmentStatus.PENDING
                assignment.assigned_at = datetime.now(timezone.utc)
            else:
                new_assignment = DeliveryAssignment(
                    subscription_delivery_id=delivery.id,
                    delivery_partner_id=payload.delivery_partner_id,
                    status=AssignmentStatus.PENDING,
                    assigned_at=datetime.now(timezone.utc)
                )
                db.add(new_assignment)
        await db.commit()

    return MessageResponse(message="Delivery partner assigned to package successfully")


