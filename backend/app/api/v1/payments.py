import hmac, hashlib
from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import razorpay

from app.db.session import get_db
from app.core.dependencies import get_current_user, require_customer
from app.models.user import User
from app.models.customer import Customer
from app.models.subscription import Subscription, SubscriptionStatus
from app.models.payment import Payment, PaymentStatus, PaymentMethod
from app.models.invoice import Invoice
from app.schemas.common import PaymentInitiateRequest, PaymentVerifyRequest, PaymentResponse, MessageResponse
from app.services import subscription_engine
from app.core.config import settings

router = APIRouter(prefix="/payments", tags=["Payments"])


def _razorpay_client():
    return razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))


async def _get_customer(db: AsyncSession, user_id: UUID) -> Customer:
    result = await db.execute(select(Customer).where(Customer.user_id == user_id))
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer profile not found")
    return customer


@router.post("/initiate", response_model=dict)
async def initiate_payment(
    payload: PaymentInitiateRequest,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Create a Razorpay order for the given subscription."""
    customer = await _get_customer(db, current_user.id)

    sub_result = await db.execute(
        select(Subscription).where(
            Subscription.id == payload.subscription_id,
            Subscription.customer_id == customer.id,
        )
    )
    sub = sub_result.scalar_one_or_none()
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    if sub.status != SubscriptionStatus.PENDING_PAYMENT:
        raise HTTPException(status_code=400, detail="Subscription is not awaiting payment")

    client = _razorpay_client()
    amount_paise = int(float(sub.total_amount) * 100)  # Razorpay uses paise
    order = client.order.create({
        "amount": amount_paise,
        "currency": "INR",
        "receipt": str(sub.id)[:30],
        "notes": {"subscription_id": str(sub.id)},
    })

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
        "order_id": order["id"],
        "amount": amount_paise,
        "currency": "INR",
        "key_id": settings.RAZORPAY_KEY_ID,
        "subscription_id": str(sub.id),
        "payment_id": str(payment.id),
    }


@router.post("/verify", response_model=MessageResponse)
async def verify_payment(
    payload: PaymentVerifyRequest,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Verify Razorpay payment signature and activate subscription."""
    # Verify signature
    expected_signature = hmac.new(
        settings.RAZORPAY_KEY_SECRET.encode(),
        f"{payload.razorpay_order_id}|{payload.razorpay_payment_id}".encode(),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected_signature, payload.razorpay_signature):
        raise HTTPException(status_code=400, detail="Invalid payment signature")

    # Find payment
    result = await db.execute(
        select(Payment).where(Payment.gateway_order_id == payload.razorpay_order_id)
    )
    payment = result.scalar_one_or_none()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment record not found")

    payment.gateway_payment_id = payload.razorpay_payment_id
    payment.gateway_signature = payload.razorpay_signature
    payment.status = PaymentStatus.SUCCESS
    payment.payment_method = PaymentMethod.RAZORPAY
    payment.paid_at = datetime.now(timezone.utc)

    # Activate subscription
    sub = await db.get(Subscription, payment.subscription_id)
    await subscription_engine.activate_subscription(db, sub)

    # Generate invoice number
    invoice_number = f"INV-{datetime.now().strftime('%Y%m')}-{str(payment.id)[:8].upper()}"
    customer_result = await db.execute(select(Customer).where(Customer.id == payment.customer_id))
    customer = customer_result.scalar_one()
    user_result = await db.execute(select(User).where(User.id == customer.user_id))  # noqa
    # Note: In production, fetch full user/address for invoice
    invoice = Invoice(
        payment_id=payment.id,
        invoice_number=invoice_number,
        customer_name="Customer",  # TODO: fetch from user
        customer_phone=current_user.phone,
        customer_email=current_user.email,
        billing_address="",
        product_name="",
        plan_name="",
        total_deliveries=sub.total_deliveries,
        price_per_delivery=float(sub.price_per_delivery),
        subtotal=float(sub.price_per_delivery) * sub.total_deliveries,
        delivery_charge=float(sub.delivery_charge),
        tax_percentage=0.0,
        tax_amount=float(sub.tax_amount),
        total_amount=float(sub.total_amount),
    )
    db.add(invoice)
    await db.commit()

    return MessageResponse(message="Payment verified and subscription activated")


@router.post("/webhook", include_in_schema=False)
async def razorpay_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    """Razorpay server-side webhook — fallback payment confirmation."""
    body = await request.body()
    signature = request.headers.get("X-Razorpay-Signature", "")
    expected = hmac.new(
        settings.RAZORPAY_WEBHOOK_SECRET.encode(), body, hashlib.sha256
    ).hexdigest()
    if not hmac.compare_digest(expected, signature):
        raise HTTPException(status_code=400, detail="Invalid webhook signature")

    import json
    event = json.loads(body)
    if event.get("event") == "payment.captured":
        payment_entity = event["payload"]["payment"]["entity"]
        order_id = payment_entity.get("order_id")
        result = await db.execute(
            select(Payment).where(Payment.gateway_order_id == order_id)
        )
        payment = result.scalar_one_or_none()
        if payment and payment.status == PaymentStatus.INITIATED:
            payment.status = PaymentStatus.SUCCESS
            payment.gateway_payment_id = payment_entity["id"]
            payment.paid_at = datetime.now(timezone.utc)
            sub = await db.get(Subscription, payment.subscription_id)
            if sub and sub.status == SubscriptionStatus.PENDING_PAYMENT:
                await subscription_engine.activate_subscription(db, sub)
            await db.commit()

    return {"status": "ok"}


@router.get("/history", response_model=list[PaymentResponse])
async def payment_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    customer = await _get_customer(db, current_user.id)
    result = await db.execute(
        select(Payment).where(Payment.customer_id == customer.id)
        .order_by(Payment.created_at.desc())
    )
    return result.scalars().all()
