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
from app.schemas.common import PaymentInitiateRequest, PaymentVerifyRequest, PaymentResponse, PaymentSummaryResponse, MessageResponse
from app.services import subscription_engine
from app.services.notification_service import NotificationService
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
        body="Your meal plan subscription has been activated! Your deliveries will begin as scheduled.",
        category="subscription",
        action_type="subscription",
        reference_id=str(sub.id)
    )
    
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
    status: str = None,
):
    """Return enriched payment history for the current customer."""
    from sqlalchemy.orm import selectinload
    from app.models.product import Product
    from app.models.subscription import SubscriptionPlan
    customer = await _get_customer(db, current_user.id)
    
    query = (
        select(Payment)
        .where(Payment.customer_id == customer.id)
        .options(
            selectinload(Payment.subscription).selectinload(Subscription.product),
            selectinload(Payment.subscription).selectinload(Subscription.plan),
        )
        .order_by(Payment.created_at.desc())
    )
    if status:
        query = query.where(Payment.status == status)
    
    result = await db.execute(query)
    payments = result.scalars().all()
    
    enriched = []
    for pmt in payments:
        sub = pmt.subscription
        product_name = sub.product.name if sub and sub.product else None
        plan_name = sub.plan.name if sub and sub.plan else None
        subscription_name = None
        if product_name and plan_name:
            subscription_name = f"{product_name} ({plan_name})"
        elif product_name:
            subscription_name = product_name

        gst_amount = float(sub.tax_amount) if sub and sub.tax_amount is not None else 0.0
        delivery_charge = float(sub.delivery_charge) if sub and sub.delivery_charge is not None else 0.0
        total_amount = float(pmt.amount)

        enriched.append(PaymentResponse(
            id=pmt.id,
            subscription_id=pmt.subscription_id,
            gateway_order_id=pmt.gateway_order_id,
            gateway_payment_id=pmt.gateway_payment_id,
            amount=float(pmt.amount),
            currency=pmt.currency,
            status=pmt.status.value if hasattr(pmt.status, "value") else str(pmt.status),
            payment_method=pmt.payment_method.value if pmt.payment_method and hasattr(pmt.payment_method, "value") else pmt.payment_method,
            paid_at=pmt.paid_at,
            created_at=pmt.created_at,
            subscription_name=subscription_name,
            gst_amount=gst_amount,
            delivery_charge=delivery_charge,
            total_amount=total_amount,
        ))
    return enriched


@router.get("/summary", response_model=PaymentSummaryResponse)
async def payment_summary(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return payment summary stats for the current customer."""
    from sqlalchemy import func as sqlfunc
    customer = await _get_customer(db, current_user.id)

    total_result = await db.execute(
        select(
            sqlfunc.count(Payment.id).label("total"),
            sqlfunc.coalesce(sqlfunc.sum(Payment.amount), 0).label("total_amount"),
            sqlfunc.max(Payment.paid_at).label("last_paid"),
        ).where(
            Payment.customer_id == customer.id,
            Payment.status == PaymentStatus.SUCCESS,
        )
    )
    row = total_result.one()

    # Active subscription cost
    active_sub_result = await db.execute(
        select(Subscription.total_amount)
        .where(
            Subscription.customer_id == customer.id,
            Subscription.status == SubscriptionStatus.ACTIVE,
        )
        .order_by(Subscription.created_at.desc())
        .limit(1)
    )
    active_cost = active_sub_result.scalar_one_or_none()

    return PaymentSummaryResponse(
        total_transactions=row.total or 0,
        total_amount_spent=float(row.total_amount or 0),
        last_payment_date=row.last_paid,
        active_subscription_cost=float(active_cost) if active_cost else None,
    )


@router.get("/{payment_id}/invoice")
async def download_invoice(
    payment_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generate and return the invoice PDF for a payment transaction."""
    # Retrieve customer profile
    customer = await _get_customer(db, current_user.id)

    # Fetch payment with relationships
    from sqlalchemy.orm import selectinload
    result = await db.execute(
        select(Payment)
        .where(Payment.id == payment_id, Payment.customer_id == customer.id)
        .options(
            selectinload(Payment.invoice),
            selectinload(Payment.subscription).selectinload(Subscription.product),
            selectinload(Payment.subscription).selectinload(Subscription.plan)
        )
    )
    payment = result.scalar_one_or_none()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment transaction not found")

    # Fallback to subscription details if invoice record does not exist
    invoice = payment.invoice
    sub = payment.subscription
    
    invoice_no = invoice.invoice_number if invoice else f"INV-{payment.created_at.strftime('%Y%m')}-{str(payment.id)[:8].upper()}"
    cust_name = invoice.customer_name if (invoice and invoice.customer_name != "Customer") else current_user.full_name
    cust_phone = invoice.customer_phone if invoice else current_user.phone
    cust_email = invoice.customer_email if invoice else current_user.email
    billing_addr = invoice.billing_address if (invoice and invoice.billing_address) else "Registered Address"
    prod_name = invoice.product_name if (invoice and invoice.product_name) else (sub.product.name if sub and sub.product else "Healthy Meal Plan")
    plan_name = invoice.plan_name if (invoice and invoice.plan_name) else (sub.plan.name if sub and sub.plan else "Subscription Plan")
    total_del = invoice.total_deliveries if invoice else (sub.total_deliveries if sub else 0)
    price_per = float(invoice.price_per_delivery) if invoice else (float(sub.price_per_delivery) if sub else 0.0)
    subtotal = float(invoice.subtotal) if invoice else (price_per * total_del)
    del_charge = float(invoice.delivery_charge) if invoice else (float(sub.delivery_charge) if sub else 0.0)
    tax_amt = float(invoice.tax_amount) if invoice else (float(sub.tax_amount) if sub else 0.0)
    total_amt = float(invoice.total_amount) if invoice else float(payment.amount)
    paid_date = payment.paid_at.strftime('%B %d, %Y') if payment.paid_at else payment.created_at.strftime('%B %d, %Y')
    pmt_method = payment.payment_method.value if payment.payment_method and hasattr(payment.payment_method, "value") else (payment.payment_method or "Razorpay")

    # Generate PDF using WeasyPrint
    import weasyprint
    import io
    from fastapi.responses import StreamingResponse

    html_content = f"""
    <html>
    <head>
      <style>
        body {{ font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; margin: 40px; color: #333; }}
        .header {{ border-bottom: 2px solid #2E7D32; padding-bottom: 20px; margin-bottom: 30px; }}
        .header h1 {{ color: #2E7D32; margin: 0; font-size: 28px; }}
        .header p {{ margin: 5px 0 0 0; color: #666; font-size: 14px; }}
        .invoice-details {{ width: 100%; margin-bottom: 30px; }}
        .invoice-details td {{ vertical-align: top; font-size: 14px; }}
        .details-title {{ font-weight: bold; color: #2E7D32; margin-bottom: 5px; text-transform: uppercase; font-size: 12px; }}
        .table {{ width: 100%; border-collapse: collapse; margin-bottom: 30px; }}
        .table th {{ background: #2E7D32; color: white; padding: 10px; font-size: 14px; text-align: left; }}
        .table td {{ padding: 12px 10px; border-bottom: 1px solid #eee; font-size: 14px; }}
        .summary {{ float: right; width: 300px; margin-top: 10px; }}
        .summary table {{ width: 100%; border-collapse: collapse; }}
        .summary td {{ padding: 6px 0; font-size: 14px; }}
        .summary .total {{ font-weight: bold; font-size: 16px; border-top: 2px solid #2E7D32; color: #2E7D32; padding-top: 10px; }}
        .footer {{ position: fixed; bottom: 0; left: 0; right: 0; border-top: 1px solid #ddd; padding-top: 10px; text-align: center; color: #999; font-size: 11px; }}
      </style>
    </head>
    <body>
      <div class="header">
        <h1>HEALTHY HOME FOODS</h1>
        <p>Your Daily Dose of Healthy & Fresh Home-Cooked Meals</p>
      </div>
      
      <table class="invoice-details">
        <tr>
          <td style="width: 50%;">
            <div class="details-title">Billed To</div>
            <strong>{cust_name}</strong><br/>
            Phone: {cust_phone}<br/>
            {f"Email: {cust_email}<br/>" if cust_email else ""}
            Address: {billing_addr}
          </td>
          <td style="width: 50%; text-align: right;">
            <div class="details-title">Invoice Information</div>
            <strong>Invoice No:</strong> {invoice_no}<br/>
            <strong>Date:</strong> {paid_date}<br/>
            <strong>Payment Method:</strong> {pmt_method.upper()}<br/>
            <strong>Status:</strong> {payment.status.upper()}
          </td>
        </tr>
      </table>
      
      <table class="table">
        <thead>
          <tr>
            <th>Item Description</th>
            <th style="text-align: right; width: 150px;">Price per Delivery</th>
            <th style="text-align: right; width: 100px;">Deliveries</th>
            <th style="text-align: right; width: 150px;">Total</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>
              <strong>{prod_name}</strong><br/>
              <span style="font-size: 12px; color: #666;">Plan: {plan_name.title()}</span>
            </td>
            <td style="text-align: right;">₹{price_per:.2f}</td>
            <td style="text-align: right;">{total_del}</td>
            <td style="text-align: right;">₹{subtotal:.2f}</td>
          </tr>
        </tbody>
      </table>
      
      <div class="summary">
        <table>
          <tr>
            <td>Subtotal</td>
            <td style="text-align: right;">₹{subtotal:.2f}</td>
          </tr>
          <tr>
            <td>Delivery Charge</td>
            <td style="text-align: right;">₹{del_charge:.2f}</td>
          </tr>
          <tr>
            <td>Tax Amount</td>
            <td style="text-align: right;">₹{tax_amt:.2f}</td>
          </tr>
          <tr class="total">
            <td>Total Paid</td>
            <td style="text-align: right;">₹{total_amt:.2f}</td>
          </tr>
        </table>
      </div>
      
      <div class="footer">
        Thank you for subscribing to Healthy Home Foods! For support, contact support@healthyhomefoods.com
      </div>
    </body>
    </html>
    """
    
    pdf_bytes = weasyprint.HTML(string=html_content).write_pdf()
    
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename={invoice_no}.pdf"},
    )
