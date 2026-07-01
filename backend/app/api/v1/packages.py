import hmac, hashlib
from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from sqlalchemy.orm import selectinload
import razorpay

from app.db.session import get_db
from app.core.dependencies import get_current_user, require_customer
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
from app.core.config import settings

router = APIRouter(prefix="/packages", tags=["Package Cart & Orders"])


def _razorpay_client():
    return razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))


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
        
    # 1. Determine highest days and pricing
    highest_days = 6 # default fallback
    selected_price = 0.0
    first_plan_type = None
    items_data = []
    
    for item in cart_items:
        qty = item.quantity
        product = item.product
        item_price = float(product.discount_price if product.discount_price else product.package_price)
        selected_price += item_price * qty
        
        if product.package_days > highest_days:
            highest_days = product.package_days
            
        if first_plan_type is None:
            first_plan_type = product.plan_type
            
        items_data.append({
            "product": product,
            "quantity": qty,
            "package_price": item_price
        })
        
    # 2. Get delivery distance & calculate delivery charge
    settings_result = await db.execute(select(AdminSettings).where(AdminSettings.id == 1))
    settings_obj = settings_result.scalar_one_or_none()
    
    distance = 0.0
    delivery_charge = 0.0
    tax_amount = 0.0
    
    if settings_obj:
        if settings_obj.business_lat and settings_obj.business_lng and address.latitude and address.longitude:
            distance = haversine(
                float(settings_obj.business_lat), float(settings_obj.business_lng),
                float(address.latitude), float(address.longitude)
            )
        if distance > 15.0:
            raise HTTPException(
                status_code=400,
                detail="There is no service beyond 15km. Please select an address within the range."
            )
        # Calculate daily charge
        charge_per_delivery = max(0.0, distance - float(settings_obj.free_delivery_radius_km)) * float(settings_obj.delivery_charge_per_km)
        # Apply for highest days
        delivery_charge = highest_days * charge_per_delivery
        
        tax_rate = float(settings_obj.tax_percentage) / 100
        tax_amount = round(selected_price * tax_rate, 2)
        
    # 3. Retrieve SubscriptionPlan matching the highest_days/plan_type
    plan_result = await db.execute(
        select(SubscriptionPlan)
        .where(and_(SubscriptionPlan.plan_type == first_plan_type, SubscriptionPlan.is_active == True))
        .limit(1)
    )
    sub_plan = plan_result.scalar_one_or_none()
    plan_id = sub_plan.id if sub_plan else None
    
    # 4. Create the Subscription (pending_payment)
    sub = await subscription_engine.create_subscription(
        db=db,
        customer=customer,
        items_data=items_data,
        plan_type=first_plan_type or "weekly",
        total_deliveries=highest_days,
        plan_id=plan_id,
        address_id=address.id,
        delivery_charge=delivery_charge,
        tax_amount=tax_amount
    )
    
    # 5. Create Razorpay order
    client = _razorpay_client()
    amount_paise = int(float(sub.total_amount) * 100) # Razorpay uses paise
    order = client.order.create({
        "amount": amount_paise,
        "currency": "INR",
        "receipt": str(sub.id)[:30],
        "notes": {"subscription_id": str(sub.id)},
    })
    
    # 6. Save Payment record
    payment = Payment(
        subscription_id=sub.id,
        customer_id=customer.id,
        gateway_order_id=order["id"],
        amount=float(sub.total_amount),
        status=PaymentStatus.INITIATED,
    )
    db.add(payment)
    await db.commit()
    
    return {
        "gateway_order_id": order["id"],
        "razorpay_key_id": settings.RAZORPAY_KEY_ID,
        "total_amount": float(sub.total_amount),
        "order_number": str(sub.id)[:8].upper()
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
    razorpay_signature = payload.get("razorpay_signature")
    
    if not all([razorpay_order_id, razorpay_payment_id, razorpay_signature]):
        raise HTTPException(status_code=400, detail="Missing payment verification fields")
        
    # Verify signature
    expected_signature = hmac.new(
        settings.RAZORPAY_KEY_SECRET.encode(),
        f"{razorpay_order_id}|{razorpay_payment_id}".encode(),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected_signature, razorpay_signature):
        raise HTTPException(status_code=400, detail="Invalid payment signature")
        
    # Find Payment
    pay_result = await db.execute(
        select(Payment).where(Payment.gateway_order_id == razorpay_order_id)
    )
    payment = pay_result.scalar_one_or_none()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment record not found")
        
    # Update Payment
    payment.gateway_payment_id = razorpay_payment_id
    payment.gateway_signature = razorpay_signature
    payment.status = PaymentStatus.SUCCESS
    payment.payment_method = PaymentMethod.RAZORPAY
    payment.paid_at = datetime.now(timezone.utc)
    
    # Load subscription and activate
    sub = await db.get(Subscription, payment.subscription_id)
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
        
    await subscription_engine.activate_subscription(db, sub)
    
    # Generate invoice
    invoice_number = f"INV-{datetime.now().strftime('%Y%m')}-{str(payment.id)[:8].upper()}"
    invoice = Invoice(
        payment_id=payment.id,
        invoice_number=invoice_number,
        customer_name=current_user.full_name or "Customer",
        customer_phone=current_user.phone,
        customer_email=current_user.email,
        billing_address="",
        product_name="Multi-package subscription",
        plan_name=f"{sub.plan_type.upper()} Plan",
        total_deliveries=sub.total_deliveries,
        price_per_delivery=0.0, # not applicable for combined checkout
        subtotal=float(sub.package_price),
        delivery_charge=float(sub.delivery_charge),
        tax_percentage=0.0,
        tax_amount=float(sub.tax_amount),
        total_amount=float(sub.total_amount)
    )
    db.add(invoice)
    
    # Clear cart
    customer = await _get_customer(db, current_user.id)
    cart_result = await db.execute(select(PackageCart).where(PackageCart.customer_id == customer.id))
    for item in cart_result.scalars().all():
        await db.delete(item)
        
    # Send Notifications
    await NotificationService.create_in_app_notification(
        db=db,
        user_id=current_user.id,
        title="Payment Successful",
        body=f"Your payment of ₹{payment.amount} was successful.",
        category="payment",
        action_type="payment",
        reference_id=str(payment.id)
    )
    
    await NotificationService.create_in_app_notification(
        db=db,
        user_id=current_user.id,
        title="Subscription Activated",
        body="Your package subscription has been activated! Deliveries will begin as scheduled.",
        category="subscription",
        action_type="subscription",
        reference_id=str(sub.id)
    )
    
    await db.commit()
    return MessageResponse(message="Payment verified and subscription activated")
