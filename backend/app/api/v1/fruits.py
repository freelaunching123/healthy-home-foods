"""
Fruits API — Customer ordering + Admin management.
Completely independent from subscription plans.
"""
import hmac
import hashlib
import os
import shutil
import uuid as uuid_lib
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

import razorpay
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, status
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.core.dependencies import get_current_user, require_customer, require_super_admin
from app.db.session import get_db
from app.models.address import Address
from app.models.customer import Customer
from app.models.fruit import (
    Fruit, FruitCart, FruitOrder, FruitOrderItem,
    FruitAvailability, FruitOrderStatus, FruitPaymentStatus,
)
from app.models.user import User
from app.schemas.common import MessageResponse
from app.services.payment_service import PaymentService
from app.models.admin_settings import AdminSettings
from app.services.delivery_engine import haversine
from app.schemas.fruit import (
    FruitCreate, FruitUpdate, FruitResponse,
    FruitAvailabilityUpdate,
    FruitCartAddRequest, FruitCartUpdateRequest, FruitCartItemResponse, FruitCartResponse,
    FruitCheckoutRequest,
    FruitOrderItemResponse, FruitOrderResponse,
    FruitOrderStatusUpdate, AdminFruitOrderAssignRequest,
    FruitPaymentVerifyRequest, FruitOrderRateRequest,
)

router = APIRouter(prefix="/fruits", tags=["Fruits"])


# ── Helpers ───────────────────────────────────────────────────────────────────

def _razorpay_client():
    return razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))


async def _get_customer(db: AsyncSession, user_id: UUID) -> Customer:
    result = await db.execute(select(Customer).where(Customer.user_id == user_id))
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer profile not found")
    return customer


def _generate_order_number() -> str:
    now = datetime.now(timezone.utc)
    suffix = str(uuid_lib.uuid4()).replace("-", "")[:6].upper()
    return f"FRT-{now.strftime('%Y%m%d')}-{suffix}"


def _build_order_response(order: FruitOrder, customer: Optional[Customer] = None) -> FruitOrderResponse:
    items_out = []
    for item in order.items:
        fruit = item.fruit
        items_out.append(FruitOrderItemResponse(
            id=item.id,
            fruit_id=item.fruit_id,
            fruit_name=fruit.name if fruit else "Unknown",
            fruit_image_url=fruit.image_url if fruit else None,
            quantity_kg=float(item.quantity_kg),
            price_per_kg=float(item.price_per_kg),
            subtotal=float(item.subtotal),
        ))

    address = order.address
    if not customer and hasattr(order, "customer") and order.customer:
        customer = order.customer

    customer_name = None
    customer_phone = None
    if customer and customer.user:
        customer_name = customer.user.full_name
        customer_phone = customer.user.phone

    assigned_partner_id = None
    assigned_partner_name = None
    if hasattr(order, "assignment") and order.assignment:
        assigned_partner_id = order.assignment.delivery_partner_id
        if order.assignment.delivery_partner and order.assignment.delivery_partner.user:
            assigned_partner_name = order.assignment.delivery_partner.user.full_name

    return FruitOrderResponse(
        id=order.id,
        order_number=order.order_number,
        total_amount=float(order.total_amount),
        payment_status=order.payment_status.value if hasattr(order.payment_status, "value") else str(order.payment_status),
        order_status=order.order_status.value if hasattr(order.order_status, "value") else str(order.order_status),
        gateway_order_id=order.gateway_order_id,
        gateway_payment_id=order.gateway_payment_id,
        paid_at=order.paid_at,
        notes=order.notes,
        created_at=order.created_at,
        updated_at=order.updated_at,
        items=items_out,
        address_line1=address.address_line1 if address else None,
        address_city=address.city if address else None,
        address_line2=address.address_line2 if address else None,
        address_state=address.state if address else None,
        address_pincode=address.pincode if address else None,
        recipient_name=address.recipient_name if address else None,
        recipient_phone=address.recipient_phone if address else None,
        latitude=float(address.latitude) if address and address.latitude is not None else None,
        longitude=float(address.longitude) if address and address.longitude is not None else None,
        customer_name=customer_name,
        customer_phone=customer_phone,
        assigned_partner_id=assigned_partner_id,
        assigned_partner_name=assigned_partner_name,
        delivery_date=order.delivery_date,
        delivery_slot=order.delivery_slot,
        rating=order.rating,
        review_text=order.review_text,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# CUSTOMER ROUTES
# ═══════════════════════════════════════════════════════════════════════════════

# ── Fruit Listing ──────────────────────────────────────────────────────────────

@router.get("/", response_model=list[FruitResponse])
async def list_fruits(
    search: Optional[str] = Query(None),
    availability: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    """List all active fruits visible to customers."""
    query = select(Fruit).where(Fruit.is_active == True)

    if availability:
        try:
            avail_enum = FruitAvailability(availability)
            query = query.where(Fruit.availability_status == avail_enum)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid availability value: {availability}")

    if search:
        query = query.where(
            or_(Fruit.name.ilike(f"%{search}%"), Fruit.description.ilike(f"%{search}%"))
        )

    result = await db.execute(query.order_by(Fruit.name))
    return result.scalars().all()


@router.get("/detail/{fruit_id}", response_model=FruitResponse)
async def get_fruit(fruit_id: UUID, db: AsyncSession = Depends(get_db)):
    """Get a single fruit's details."""
    result = await db.execute(select(Fruit).where(Fruit.id == fruit_id, Fruit.is_active == True))
    fruit = result.scalar_one_or_none()
    if not fruit:
        raise HTTPException(status_code=404, detail="Fruit not found")
    return fruit


# ── Cart ───────────────────────────────────────────────────────────────────────

@router.get("/cart", response_model=FruitCartResponse)
async def get_cart(
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Get the current customer's cart."""
    customer = await _get_customer(db, current_user.id)

    result = await db.execute(
        select(FruitCart)
        .where(FruitCart.customer_id == customer.id)
        .options(selectinload(FruitCart.fruit))
        .order_by(FruitCart.created_at)
    )
    cart_items = result.scalars().all()

    items_out = []
    total = 0.0
    for item in cart_items:
        fruit = item.fruit
        subtotal = float(item.subtotal)
        total += subtotal
        items_out.append(FruitCartItemResponse(
            id=item.id,
            fruit_id=item.fruit_id,
            fruit_name=fruit.name if fruit else "Unknown",
            fruit_image_url=fruit.image_url if fruit else None,
            fruit_availability_status=(
                fruit.availability_status.value if fruit and hasattr(fruit.availability_status, "value")
                else (str(fruit.availability_status) if fruit else "unknown")
            ),
            quantity_kg=float(item.quantity_kg),
            unit_price=float(item.unit_price),
            subtotal=subtotal,
        ))

    return FruitCartResponse(items=items_out, total_amount=round(total, 2), item_count=len(items_out))


@router.post("/cart/add", response_model=FruitCartItemResponse, status_code=status.HTTP_200_OK)
async def add_to_cart(
    payload: FruitCartAddRequest,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Add or update a fruit in the cart (upsert by customer+fruit)."""
    customer = await _get_customer(db, current_user.id)

    # Validate fruit
    fruit_result = await db.execute(
        select(Fruit).where(Fruit.id == payload.fruit_id, Fruit.is_active == True)
    )
    fruit = fruit_result.scalar_one_or_none()
    if not fruit:
        raise HTTPException(status_code=404, detail="Fruit not found or unavailable")
    if fruit.availability_status != FruitAvailability.IN_STOCK:
        raise HTTPException(status_code=400, detail="Fruit is not available for ordering")

    subtotal = round(payload.quantity_kg * float(fruit.price_per_kg), 2)

    # Upsert cart item
    existing_result = await db.execute(
        select(FruitCart).where(
            FruitCart.customer_id == customer.id,
            FruitCart.fruit_id == payload.fruit_id,
        )
    )
    cart_item = existing_result.scalar_one_or_none()

    if cart_item:
        cart_item.quantity_kg = payload.quantity_kg
        cart_item.unit_price = float(fruit.price_per_kg)
        cart_item.subtotal = subtotal
    else:
        cart_item = FruitCart(
            customer_id=customer.id,
            fruit_id=payload.fruit_id,
            quantity_kg=payload.quantity_kg,
            unit_price=float(fruit.price_per_kg),
            subtotal=subtotal,
        )
        db.add(cart_item)

    await db.commit()
    await db.refresh(cart_item)

    return FruitCartItemResponse(
        id=cart_item.id,
        fruit_id=cart_item.fruit_id,
        fruit_name=fruit.name,
        fruit_image_url=fruit.image_url,
        fruit_availability_status=fruit.availability_status.value if hasattr(fruit.availability_status, "value") else str(fruit.availability_status),
        quantity_kg=float(cart_item.quantity_kg),
        unit_price=float(cart_item.unit_price),
        subtotal=float(cart_item.subtotal),
    )


@router.put("/cart/{cart_item_id}", response_model=FruitCartItemResponse)
async def update_cart_item(
    cart_item_id: UUID,
    payload: FruitCartUpdateRequest,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Update the quantity of a cart item."""
    customer = await _get_customer(db, current_user.id)

    result = await db.execute(
        select(FruitCart)
        .where(FruitCart.id == cart_item_id, FruitCart.customer_id == customer.id)
        .options(selectinload(FruitCart.fruit))
    )
    cart_item = result.scalar_one_or_none()
    if not cart_item:
        raise HTTPException(status_code=404, detail="Cart item not found")

    fruit = cart_item.fruit
    cart_item.quantity_kg = payload.quantity_kg
    cart_item.unit_price = float(fruit.price_per_kg)
    cart_item.subtotal = round(payload.quantity_kg * float(fruit.price_per_kg), 2)

    await db.commit()
    await db.refresh(cart_item)

    return FruitCartItemResponse(
        id=cart_item.id,
        fruit_id=cart_item.fruit_id,
        fruit_name=fruit.name,
        fruit_image_url=fruit.image_url,
        fruit_availability_status=fruit.availability_status.value if hasattr(fruit.availability_status, "value") else str(fruit.availability_status),
        quantity_kg=float(cart_item.quantity_kg),
        unit_price=float(cart_item.unit_price),
        subtotal=float(cart_item.subtotal),
    )


@router.delete("/cart/{cart_item_id}", response_model=MessageResponse)
async def remove_from_cart(
    cart_item_id: UUID,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Remove a single item from the cart."""
    customer = await _get_customer(db, current_user.id)
    result = await db.execute(
        select(FruitCart).where(FruitCart.id == cart_item_id, FruitCart.customer_id == customer.id)
    )
    cart_item = result.scalar_one_or_none()
    if not cart_item:
        raise HTTPException(status_code=404, detail="Cart item not found")
    await db.delete(cart_item)
    await db.commit()
    return MessageResponse(message="Item removed from cart")


@router.delete("/cart", response_model=MessageResponse)
async def clear_cart(
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Clear the entire cart for the current customer."""
    customer = await _get_customer(db, current_user.id)
    result = await db.execute(select(FruitCart).where(FruitCart.customer_id == customer.id))
    items = result.scalars().all()
    for item in items:
        await db.delete(item)
    await db.commit()
    return MessageResponse(message="Cart cleared successfully")


# ── Orders ─────────────────────────────────────────────────────────────────────

@router.post("/orders/checkout", response_model=FruitOrderResponse, status_code=status.HTTP_201_CREATED)
async def checkout(
    payload: FruitCheckoutRequest,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Convert cart to a pending fruit order."""
    customer = await _get_customer(db, current_user.id)

    # Validate address
    addr_result = await db.execute(
        select(Address).where(Address.id == payload.address_id, Address.user_id == current_user.id)
    )
    address = addr_result.scalar_one_or_none()
    if not address:
        raise HTTPException(status_code=404, detail="Address not found")

    # Validate distance (service range 15km)
    settings_result = await db.execute(select(AdminSettings).where(AdminSettings.id == 1))
    settings_obj = settings_result.scalar_one_or_none()
    distance = 0.0
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

    # Load cart
    cart_result = await db.execute(
        select(FruitCart)
        .where(FruitCart.customer_id == customer.id)
        .options(selectinload(FruitCart.fruit))
    )
    cart_items = cart_result.scalars().all()
    if not cart_items:
        raise HTTPException(status_code=400, detail="Cart is empty")

    # Re-validate each fruit and build order items
    total = 0.0
    order_items_data = []
    for item in cart_items:
        fruit = item.fruit
        if not fruit or not fruit.is_active:
            raise HTTPException(status_code=400, detail=f"Fruit '{fruit.name if fruit else item.fruit_id}' is no longer available")
        if fruit.availability_status != FruitAvailability.IN_STOCK:
            raise HTTPException(status_code=400, detail=f"'{fruit.name}' is not in stock")
        subtotal = round(float(item.quantity_kg) * float(fruit.price_per_kg), 2)
        total += subtotal
        order_items_data.append({
            "fruit_id": fruit.id,
            "fruit": fruit,
            "quantity_kg": float(item.quantity_kg),
            "price_per_kg": float(fruit.price_per_kg),
            "subtotal": subtotal,
        })

    # Create order
    order = FruitOrder(
        customer_id=customer.id,
        address_id=address.id,
        order_number=_generate_order_number(),
        total_amount=round(total, 2),
        payment_status=FruitPaymentStatus.PENDING,
        order_status=FruitOrderStatus.PENDING,
        notes=payload.notes,
        delivery_date=payload.delivery_date,
        delivery_slot=payload.delivery_slot,
    )
    db.add(order)
    await db.flush()  # Get order.id

    for data in order_items_data:
        order_item = FruitOrderItem(
            order_id=order.id,
            fruit_id=data["fruit_id"],
            quantity_kg=data["quantity_kg"],
            price_per_kg=data["price_per_kg"],
            subtotal=data["subtotal"],
        )
        db.add(order_item)

    await db.commit()

    # Reload with relationships
    reload_result = await db.execute(
        select(FruitOrder)
        .where(FruitOrder.id == order.id)
        .options(
            selectinload(FruitOrder.items).selectinload(FruitOrderItem.fruit),
            selectinload(FruitOrder.address),
            selectinload(FruitOrder.assignment)
                .selectinload(__import__('app.models.delivery_assignment', fromlist=['DeliveryAssignment']).DeliveryAssignment.delivery_partner)
                .selectinload(__import__('app.models.delivery_partner', fromlist=['DeliveryPartner']).DeliveryPartner.user),
        )
    )
    order = reload_result.scalar_one()
    return _build_order_response(order)


@router.post("/orders/{order_id}/payment/initiate", response_model=dict)
async def initiate_fruit_payment(
    order_id: UUID,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Create a mock order for a pending fruit order."""
    customer = await _get_customer(db, current_user.id)

    order_result = await db.execute(
        select(FruitOrder).where(FruitOrder.id == order_id, FruitOrder.customer_id == customer.id)
    )
    order = order_result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Fruit order not found")
    if order.payment_status not in (FruitPaymentStatus.PENDING, FruitPaymentStatus.INITIATED):
        raise HTTPException(status_code=400, detail="Order payment is not in a payable state")

    order.gateway_order_id = f"mock_order_fruit_{order.id}"
    order.payment_status = FruitPaymentStatus.INITIATED
    await db.commit()

    return {
        "order_id": order.gateway_order_id,
        "amount": int(float(order.total_amount) * 100),
        "currency": "INR",
        "key_id": "mock_key",
        "fruit_order_id": str(order.id),
        "order_number": order.order_number,
    }


@router.post("/orders/{order_id}/payment/verify", response_model=MessageResponse)
async def verify_fruit_payment(
    order_id: UUID,
    payload: FruitPaymentVerifyRequest,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Verify mock payment, mark order paid, and clear the cart."""
    await PaymentService.verify_mock_fruit_payment(db, order_id, current_user)
    return MessageResponse(message="Payment verified. Your fruit order has been placed successfully!")


@router.get("/orders/history", response_model=list[FruitOrderResponse])
async def fruit_order_history(
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Get the current customer's fruit order history."""
    customer = await _get_customer(db, current_user.id)

    result = await db.execute(
        select(FruitOrder)
        .where(FruitOrder.customer_id == customer.id)
        .options(
            selectinload(FruitOrder.items).selectinload(FruitOrderItem.fruit),
            selectinload(FruitOrder.address),
            selectinload(FruitOrder.assignment)
                .selectinload(__import__('app.models.delivery_assignment', fromlist=['DeliveryAssignment']).DeliveryAssignment.delivery_partner)
                .selectinload(__import__('app.models.delivery_partner', fromlist=['DeliveryPartner']).DeliveryPartner.user),
        )
        .order_by(FruitOrder.created_at.desc())
    )
    orders = result.scalars().all()
    return [_build_order_response(o) for o in orders]


@router.get("/orders/{order_id}", response_model=FruitOrderResponse)
async def get_fruit_order(
    order_id: UUID,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Get detail of a single fruit order."""
    customer = await _get_customer(db, current_user.id)

    result = await db.execute(
        select(FruitOrder)
        .where(FruitOrder.id == order_id, FruitOrder.customer_id == customer.id)
        .options(
            selectinload(FruitOrder.items).selectinload(FruitOrderItem.fruit),
            selectinload(FruitOrder.address),
            selectinload(FruitOrder.assignment)
                .selectinload(__import__('app.models.delivery_assignment', fromlist=['DeliveryAssignment']).DeliveryAssignment.delivery_partner)
                .selectinload(__import__('app.models.delivery_partner', fromlist=['DeliveryPartner']).DeliveryPartner.user),
        )
    )
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Fruit order not found")
    return _build_order_response(order)


# ═══════════════════════════════════════════════════════════════════════════════
# ADMIN ROUTES
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/admin/fruits", response_model=list[FruitResponse])
async def admin_list_fruits(
    search: Optional[str] = Query(None),
    availability: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin: list all fruits (including inactive)."""
    query = select(Fruit)
    if is_active is not None:
        query = query.where(Fruit.is_active == is_active)
    if availability:
        try:
            avail_enum = FruitAvailability(availability)
            query = query.where(Fruit.availability_status == avail_enum)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid availability value: {availability}")
    if search:
        query = query.where(
            or_(Fruit.name.ilike(f"%{search}%"), Fruit.description.ilike(f"%{search}%"))
        )
    result = await db.execute(query.order_by(Fruit.name))
    return result.scalars().all()


@router.post("/admin/fruits", response_model=FruitResponse, status_code=status.HTTP_201_CREATED)
async def admin_create_fruit(
    payload: FruitCreate,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin: add a new fruit to the catalogue."""
    try:
        avail = FruitAvailability(payload.availability_status)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid availability_status: {payload.availability_status}")

    fruit = Fruit(
        name=payload.name.strip(),
        description=payload.description,
        price_per_kg=payload.price_per_kg,
        availability_status=avail,
        is_active=payload.is_active,
    )
    db.add(fruit)
    await db.commit()
    await db.refresh(fruit)
    return fruit


@router.put("/admin/fruits/{fruit_id}", response_model=FruitResponse)
async def admin_update_fruit(
    fruit_id: UUID,
    payload: FruitUpdate,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin: update fruit details."""
    result = await db.execute(select(Fruit).where(Fruit.id == fruit_id))
    fruit = result.scalar_one_or_none()
    if not fruit:
        raise HTTPException(status_code=404, detail="Fruit not found")

    data = payload.model_dump(exclude_none=True)
    if "availability_status" in data:
        try:
            data["availability_status"] = FruitAvailability(data["availability_status"])
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid availability_status: {data['availability_status']}")
    if "name" in data:
        data["name"] = data["name"].strip()

    for k, v in data.items():
        setattr(fruit, k, v)

    await db.commit()
    await db.refresh(fruit)
    return fruit


@router.post("/admin/fruits/{fruit_id}/image", response_model=FruitResponse)
async def admin_upload_fruit_image(
    fruit_id: UUID,
    file: UploadFile = File(...),
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin: upload or replace fruit image."""
    result = await db.execute(select(Fruit).where(Fruit.id == fruit_id))
    fruit = result.scalar_one_or_none()
    if not fruit:
        raise HTTPException(status_code=404, detail="Fruit not found")

    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in [".jpg", ".jpeg", ".png", ".webp"]:
        raise HTTPException(status_code=400, detail="Invalid image format. Use JPG, PNG, or WebP.")

    upload_dir = os.path.join(settings.UPLOAD_DIR, "fruits")
    os.makedirs(upload_dir, exist_ok=True)

    # Delete old image file if it exists
    if fruit.image_url:
        old_path = os.path.join(settings.UPLOAD_DIR, fruit.image_url.lstrip("/uploads/"))
        if os.path.exists(old_path):
            os.remove(old_path)

    filename = f"{uuid_lib.uuid4()}{ext}"
    filepath = os.path.join(upload_dir, filename)
    with open(filepath, "wb") as f:
        shutil.copyfileobj(file.file, f)

    fruit.image_url = f"/uploads/fruits/{filename}"
    await db.commit()
    await db.refresh(fruit)
    return fruit


@router.delete("/admin/fruits/{fruit_id}/image", response_model=MessageResponse)
async def admin_delete_fruit_image(
    fruit_id: UUID,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin: remove the image from a fruit."""
    result = await db.execute(select(Fruit).where(Fruit.id == fruit_id))
    fruit = result.scalar_one_or_none()
    if not fruit:
        raise HTTPException(status_code=404, detail="Fruit not found")
    if fruit.image_url:
        old_path = os.path.join(settings.UPLOAD_DIR, fruit.image_url.lstrip("/uploads/"))
        if os.path.exists(old_path):
            os.remove(old_path)
        fruit.image_url = None
        await db.commit()
    return MessageResponse(message="Image deleted successfully")


@router.patch("/admin/fruits/{fruit_id}/availability", response_model=FruitResponse)
async def admin_update_availability(
    fruit_id: UUID,
    payload: FruitAvailabilityUpdate,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin: change the stock/availability status of a fruit."""
    result = await db.execute(select(Fruit).where(Fruit.id == fruit_id))
    fruit = result.scalar_one_or_none()
    if not fruit:
        raise HTTPException(status_code=404, detail="Fruit not found")
    try:
        fruit.availability_status = FruitAvailability(payload.availability_status)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid availability status: {payload.availability_status}")
    await db.commit()
    await db.refresh(fruit)
    return fruit


@router.patch("/admin/fruits/{fruit_id}/toggle-active", response_model=FruitResponse)
async def admin_toggle_active(
    fruit_id: UUID,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin: toggle the is_active flag (activate/deactivate)."""
    result = await db.execute(select(Fruit).where(Fruit.id == fruit_id))
    fruit = result.scalar_one_or_none()
    if not fruit:
        raise HTTPException(status_code=404, detail="Fruit not found")
    fruit.is_active = not fruit.is_active
    await db.commit()
    await db.refresh(fruit)
    return fruit


@router.delete("/admin/fruits/{fruit_id}", response_model=MessageResponse)
async def admin_soft_delete_fruit(
    fruit_id: UUID,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin: soft-delete a fruit (sets is_active=False, hides from customers)."""
    result = await db.execute(select(Fruit).where(Fruit.id == fruit_id))
    fruit = result.scalar_one_or_none()
    if not fruit:
        raise HTTPException(status_code=404, detail="Fruit not found")
    fruit.is_active = False
    await db.commit()
    return MessageResponse(message="Fruit deleted (deactivated) successfully")


# ── Admin: Fruit Orders ────────────────────────────────────────────────────────

@router.get("/admin/orders", response_model=list[FruitOrderResponse])
async def admin_list_fruit_orders(
    order_status: Optional[str] = Query(None),
    payment_status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),  # search by order_number or customer name
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin: list all fruit orders with optional filters."""
    query = (
        select(FruitOrder)
        .options(
            selectinload(FruitOrder.items).selectinload(FruitOrderItem.fruit),
            selectinload(FruitOrder.address),
            selectinload(FruitOrder.customer).selectinload(Customer.user),
            selectinload(FruitOrder.assignment)
                .selectinload(__import__('app.models.delivery_assignment', fromlist=['DeliveryAssignment']).DeliveryAssignment.delivery_partner)
                .selectinload(__import__('app.models.delivery_partner', fromlist=['DeliveryPartner']).DeliveryPartner.user),
        )
        .order_by(FruitOrder.created_at.desc())
    )

    if order_status:
        try:
            query = query.where(FruitOrder.order_status == FruitOrderStatus(order_status))
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid order_status: {order_status}")

    if payment_status:
        try:
            query = query.where(FruitOrder.payment_status == FruitPaymentStatus(payment_status))
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid payment_status: {payment_status}")

    if search:
        query = query.where(FruitOrder.order_number.ilike(f"%{search}%"))

    result = await db.execute(query)
    orders = result.scalars().all()
    return [_build_order_response(o, o.customer) for o in orders]


@router.patch("/admin/orders/{order_id}/status", response_model=FruitOrderResponse)
async def admin_update_order_status(
    order_id: UUID,
    payload: FruitOrderStatusUpdate,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin: update the delivery status of a fruit order."""
    result = await db.execute(
        select(FruitOrder)
        .where(FruitOrder.id == order_id)
        .options(
            selectinload(FruitOrder.items).selectinload(FruitOrderItem.fruit),
            selectinload(FruitOrder.address),
            selectinload(FruitOrder.customer).selectinload(Customer.user),
            selectinload(FruitOrder.assignment)
                .selectinload(__import__('app.models.delivery_assignment', fromlist=['DeliveryAssignment']).DeliveryAssignment.delivery_partner)
                .selectinload(__import__('app.models.delivery_partner', fromlist=['DeliveryPartner']).DeliveryPartner.user),
        )
    )
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Fruit order not found")
    try:
        order.order_status = FruitOrderStatus(payload.order_status)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid order_status: {payload.order_status}")
    await db.commit()
    await db.refresh(order)
    return _build_order_response(order, order.customer)


@router.post("/admin/orders/{order_id}/assign", response_model=MessageResponse)
async def admin_assign_fruit_order(
    order_id: UUID,
    payload: AdminFruitOrderAssignRequest,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin: assign or unassign a delivery partner to a fruit order."""
    from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus
    from app.models.delivery_partner import DeliveryPartner

    # Get the order
    order_result = await db.execute(select(FruitOrder).where(FruitOrder.id == order_id))
    order = order_result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Fruit order not found")

    # Get existing assignment
    assignment_result = await db.execute(select(DeliveryAssignment).where(DeliveryAssignment.fruit_order_id == order_id))
    assignment = assignment_result.scalar_one_or_none()

    if payload.delivery_partner_id is None:
        # Unassign
        if assignment:
            await db.delete(assignment)
            order.order_status = FruitOrderStatus.READY
            await db.commit()
        return MessageResponse(message="Delivery partner unassigned successfully")

    # Assign
    partner_result = await db.execute(select(DeliveryPartner).where(DeliveryPartner.id == payload.delivery_partner_id))
    partner = partner_result.scalar_one_or_none()
    if not partner:
        raise HTTPException(status_code=404, detail="Delivery partner not found")

    if assignment:
        assignment.delivery_partner_id = partner.id
        assignment.status = AssignmentStatus.PENDING
        assignment.assigned_at = datetime.now(timezone.utc)
    else:
        assignment = DeliveryAssignment(
            fruit_order_id=order.id,
            delivery_partner_id=partner.id,
            status=AssignmentStatus.PENDING,
            assigned_at=datetime.now(timezone.utc),
        )
        db.add(assignment)

    order.order_status = FruitOrderStatus.OUT_FOR_DELIVERY

    await db.commit()
    return MessageResponse(message="Delivery partner assigned successfully")


@router.get("/{fruit_id}/reviews", response_model=__import__('app.schemas.review', fromlist=['ReviewListResponse']).ReviewListResponse)
async def list_fruit_reviews(
    fruit_id: UUID,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    from app.models.review import Review, ReviewItemType
    from app.schemas.review import ReviewListResponse, ReviewResponse
    from sqlalchemy import func
    
    query = select(Review).options(selectinload(Review.customer).selectinload(Customer.user)).where(
        Review.item_id == fruit_id,
        Review.item_type == ReviewItemType.FRUIT,
        Review.is_visible == True
    )
    
    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()
    
    avg_result = await db.execute(select(func.avg(Review.rating)).where(
        Review.item_id == fruit_id,
        Review.item_type == ReviewItemType.FRUIT,
        Review.is_visible == True
    ))
    avg = avg_result.scalar() or 0.0
    
    result = await db.execute(query.order_by(Review.created_at.desc()).offset((page - 1) * page_size).limit(page_size))
    items = result.scalars().all()
    
    formatted_items = []
    for item in items:
        formatted_items.append(ReviewResponse(
            id=item.id,
            customer_id=item.customer_id,
            customer_name=item.customer.user.full_name if item.customer and item.customer.user else "Anonymous",
            item_type=item.item_type,
            item_id=item.item_id,
            rating=item.rating,
            review_text=item.review_text,
            created_at=item.created_at
        ))
        
    return ReviewListResponse(total=total, page=page, page_size=page_size, items=formatted_items, average_rating=float(avg))


@router.post("/{fruit_id}/reviews", response_model=MessageResponse)
async def create_fruit_review(
    fruit_id: UUID,
    payload: __import__('app.schemas.review', fromlist=['ReviewCreate']).ReviewCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.models.review import Review, ReviewItemType
    
    # Get customer
    result = await db.execute(select(Customer).where(Customer.user_id == current_user.id))
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=403, detail="Only customers can leave reviews")

    # Verify they have completed an order for this fruit
    order_query = select(FruitOrderItem).join(FruitOrder, FruitOrder.id == FruitOrderItem.order_id).where(
        FruitOrder.customer_id == customer.id,
        FruitOrderItem.fruit_id == fruit_id,
        FruitOrder.order_status == FruitOrderStatus.DELIVERED
    ).limit(1)
    
    order_res = await db.execute(order_query)
    if not order_res.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="You can only review fruits that have been delivered to you")

    # Check for existing review
    existing_res = await db.execute(select(Review).where(
        Review.customer_id == customer.id,
        Review.item_id == fruit_id,
        Review.item_type == ReviewItemType.FRUIT
    ))
    if existing_res.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="You have already reviewed this fruit")

    # Create review
    review = Review(
        customer_id=customer.id,
        item_type=ReviewItemType.FRUIT,
        item_id=fruit_id,
        rating=payload.rating,
        review_text=payload.review_text
    )
    db.add(review)
    await db.commit()
    return MessageResponse(message="Review submitted successfully")


@router.get("/delivery-slots", response_model=list[dict])
async def get_available_slots(db: AsyncSession = Depends(get_db)):
    """Fetch available delivery dates and time slots."""
    import datetime
    from app.models.delivery_slot import DeliverySlot
    from sqlalchemy import select

    now = datetime.datetime.now(datetime.timezone.utc).date()
    result = await db.execute(select(DeliverySlot).where(DeliverySlot.slot_date >= now))
    slots = result.scalars().all()
    
    if not slots:
        # Dynamically seed slots for the next 7 days starting tomorrow
        default_slots = [
            "6:00 AM – 7:00 AM",
            "7:00 AM – 8:00 AM",
            "8:00 AM – 9:00 AM",
            "3:00 PM – 4:00 PM",
            "4:00 PM – 5:00 PM",
            "5:00 PM – 6:00 PM"
        ]
        for i in range(1, 8):
            day = now + datetime.timedelta(days=i)
            for time_slot in default_slots:
                slot = DeliverySlot(slot_date=day, time_slot=time_slot, is_available=True)
                db.add(slot)
        await db.commit()
        
        result = await db.execute(select(DeliverySlot).where(DeliverySlot.slot_date >= now))
        slots = result.scalars().all()
        
    return [{"id": str(s.id), "date": s.slot_date.isoformat(), "time_slot": s.time_slot, "is_available": s.is_available} for s in slots]


@router.post("/orders/{order_id}/rate", response_model=MessageResponse)
async def rate_fruit_order(
    order_id: UUID,
    payload: FruitOrderRateRequest,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Submit a star rating and review comment for a delivered fruit order."""
    customer = await _get_customer(db, current_user.id)
    result = await db.execute(
        select(FruitOrder).where(FruitOrder.id == order_id, FruitOrder.customer_id == customer.id)
    )
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Fruit order not found")
        
    if order.order_status != FruitOrderStatus.DELIVERED:
        raise HTTPException(status_code=400, detail="You can only rate orders that have been successfully delivered")
        
    if payload.rating < 1 or payload.rating > 5:
        raise HTTPException(status_code=400, detail="Rating must be between 1 and 5 stars")
        
    order.rating = payload.rating
    order.review_text = payload.review_text
    
    await db.commit()
    return MessageResponse(message="Rating submitted successfully")
