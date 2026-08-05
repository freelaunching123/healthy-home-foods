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
from app.models.subscription import Subscription, SubscriptionStatus, SubscriptionItem
from app.models.payment import Payment, PaymentStatus, PaymentMethod
from app.models.invoice import Invoice
from app.schemas.common import PaymentInitiateRequest, PaymentVerifyRequest, PaymentResponse, PaymentSummaryResponse, MessageResponse
from app.services import subscription_engine
from app.services.notification_service import NotificationService
from app.core.config import settings

from app.services.payment_service import PaymentService

router = APIRouter(prefix="/payments", tags=["Payments"])


def _razorpay_client():
    return razorpay.Client(auth=(settings.RAZORPAY_KEY_ID or "mock", settings.RAZORPAY_KEY_SECRET or "mock"))


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
    """Create a mock order for the given subscription."""
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

    payment = await PaymentService.initiate_mock_payment(
        db=db,
        customer_id=customer.id,
        subscription_id=sub.id,
        amount=float(sub.total_amount)
    )

    return {
        "order_id": payment.gateway_order_id,
        "amount": int(float(sub.total_amount) * 100),
        "currency": "INR",
        "key_id": settings.RAZORPAY_KEY_ID or "mock_key",
        "subscription_id": str(sub.id),
        "payment_id": str(payment.id),
    }


@router.post("/verify", response_model=MessageResponse)
async def verify_payment(
    payload: PaymentVerifyRequest,
    current_user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Verify mock payment and activate subscription."""
    await PaymentService.verify_payment(
        db=db,
        gateway_order_id=payload.razorpay_order_id,
        gateway_payment_id=payload.razorpay_payment_id,
        gateway_signature=payload.razorpay_signature,
        user=current_user
    )
    return MessageResponse(message="Payment verified and subscription activated")



@router.get("/history", response_model=list[PaymentResponse])
async def payment_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    status: str = None,
):
    """Return enriched payment history for the current customer (both Packages and Fruit Orders)."""
    from sqlalchemy.orm import selectinload
    from app.models.fruit import FruitOrder, FruitPaymentStatus
    customer = await _get_customer(db, current_user.id)
    
    query = (
        select(Payment)
        .where(Payment.customer_id == customer.id)
        .options(
            selectinload(Payment.subscription).selectinload(Subscription.product),
            selectinload(Payment.subscription).selectinload(Subscription.plan),
            selectinload(Payment.subscription).selectinload(Subscription.items).selectinload(SubscriptionItem.product),
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
        product_name = None
        plan_name = sub.plan.name if sub and sub.plan else None
        if sub:
            if sub.product and sub.product.name:
                product_name = sub.product.name
            elif sub.items:
                p_names = [it.product.name for it in sub.items if it.product]
                if len(p_names) == 1:
                    product_name = p_names[0]
                elif len(p_names) > 1:
                    product_name = f"{p_names[0]} + {len(p_names)-1} other(s)"

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

    # Also include Fruit Orders in Payment History if status is ALL or SUCCESS
    if not status or status.lower() == "success":
        fruit_res = await db.execute(
            select(FruitOrder)
            .where(FruitOrder.customer_id == customer.id, FruitOrder.payment_status == FruitPaymentStatus.SUCCESS)
            .order_by(FruitOrder.created_at.desc())
        )
        fruit_orders = fruit_res.scalars().all()
        for fo in fruit_orders:
            enriched.append(PaymentResponse(
                id=fo.id,
                subscription_id=None,
                gateway_order_id=fo.gateway_order_id,
                gateway_payment_id=fo.gateway_payment_id,
                amount=float(fo.total_amount),
                currency="INR",
                status="success",
                payment_method="online",
                paid_at=fo.paid_at,
                created_at=fo.created_at,
                subscription_name=f"Fresh Fruit Order #{fo.order_number}",
                gst_amount=0.0,
                delivery_charge=0.0,
                total_amount=float(fo.total_amount),
            ))

    # Sort combined history by created_at desc
    enriched.sort(key=lambda x: x.created_at if x.created_at else datetime.min.replace(tzinfo=timezone.utc), reverse=True)
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
    try:
        # Retrieve customer profile
        customer = await _get_customer(db, current_user.id)

        # Fetch payment with relationships
        from sqlalchemy.orm import selectinload
        from app.models.fruit import FruitOrder, FruitOrderItem
        result = await db.execute(
            select(Payment)
            .where(Payment.id == payment_id, Payment.customer_id == customer.id)
            .options(
                selectinload(Payment.invoice),
                selectinload(Payment.subscription).selectinload(Subscription.product),
                selectinload(Payment.subscription).selectinload(Subscription.plan),
                selectinload(Payment.subscription).selectinload(Subscription.items).selectinload(SubscriptionItem.product),
            )
        )
        payment = result.scalar_one_or_none()
        fruit_order = None

        if not payment:
            f_res = await db.execute(
                select(FruitOrder)
                .where(FruitOrder.id == payment_id, FruitOrder.customer_id == customer.id)
                .options(selectinload(FruitOrder.items).selectinload(FruitOrderItem.fruit))
            )
            fruit_order = f_res.scalar_one_or_none()
            if not fruit_order:
                raise HTTPException(status_code=404, detail="Payment transaction not found")

        from datetime import datetime
        import io
        from fastapi.responses import StreamingResponse
        from reportlab.lib.pagesizes import letter
        from reportlab.lib import colors
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle

        styles = getSampleStyleSheet()

        title_style = ParagraphStyle(
            'DocTitle',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=20,
            leading=24,
            textColor=colors.HexColor('#2E7D32')
        )
        subtitle_style = ParagraphStyle(
            'DocSubtitle',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=10,
            leading=13,
            textColor=colors.HexColor('#666666')
        )
        h2_style = ParagraphStyle(
            'H2Style',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=11,
            leading=14,
            textColor=colors.HexColor('#2E7D32')
        )
        normal_style = ParagraphStyle(
            'NormalText',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=10,
            leading=14,
            textColor=colors.HexColor('#333333')
        )
        right_normal = ParagraphStyle(
            'RightNormal',
            parent=normal_style,
            alignment=2
        )
        right_bold = ParagraphStyle(
            'RightBold',
            parent=normal_style,
            fontName='Helvetica-Bold',
            alignment=2
        )

        if fruit_order:
            invoice_no = f"INV-FRUIT-{fruit_order.order_number}"
            cust_name = (current_user.full_name if (current_user and current_user.full_name) else "Customer") or "Customer"
            cust_phone = (current_user.phone if (current_user and current_user.phone) else "N/A") or "N/A"
            cust_email = current_user.email if current_user else None
            billing_addr = "Registered Address"
            paid_date = (
                fruit_order.paid_at.strftime('%B %d, %Y')
                if fruit_order.paid_at
                else (fruit_order.created_at.strftime('%B %d, %Y') if fruit_order.created_at else datetime.now().strftime('%B %d, %Y'))
            )
            pmt_method = "ONLINE"
            status_str = "SUCCESS"
            del_charge = float(getattr(fruit_order, 'delivery_charge', 0.0) or 0.0)
            tax_amt = 0.0
            total_amt = float(fruit_order.total_amount or 0.0)
            subtotal = total_amt - del_charge

            item_rows = []
            if fruit_order.items:
                for it in fruit_order.items:
                    fname = it.fruit.name if (it.fruit and it.fruit.name) else "Fresh Fruit"
                    u_price = float(it.unit_price_per_kg or 0.0)
                    qty_kg = float(it.quantity_kg or 0.0)
                    sub_tot = float(it.subtotal or (u_price * qty_kg))
                    item_rows.append([
                        Paragraph(f"<b>{fname}</b>", normal_style),
                        Paragraph(f"INR {u_price:.2f}/kg", right_normal),
                        Paragraph(f"{qty_kg} kg", right_normal),
                        Paragraph(f"INR {sub_tot:.2f}", right_bold),
                    ])
            else:
                item_rows.append([
                    Paragraph("<b>Fresh Fruits Order</b>", normal_style),
                    Paragraph("—", right_normal),
                    Paragraph("1", right_normal),
                    Paragraph(f"INR {subtotal:.2f}", right_bold),
                ])
        else:
            invoice = payment.invoice
            sub = payment.subscription

            now_str = datetime.now().strftime('%Y%m')
            created_str = payment.created_at.strftime('%Y%m') if (payment and payment.created_at is not None) else now_str

            invoice_no = (
                invoice.invoice_number
                if (invoice and invoice.invoice_number)
                else f"INV-{created_str}-{str(payment.id)[:8].upper()}"
            )
            cust_name = (
                invoice.customer_name
                if (invoice and invoice.customer_name and invoice.customer_name != "Customer")
                else (current_user.full_name if (current_user and current_user.full_name) else "Customer")
            ) or "Customer"

            cust_phone = (
                invoice.customer_phone
                if (invoice and invoice.customer_phone)
                else (current_user.phone if (current_user and current_user.phone) else "N/A")
            ) or "N/A"

            cust_email = (
                invoice.customer_email
                if invoice
                else (current_user.email if current_user else None)
            )

            billing_addr = (
                invoice.billing_address
                if (invoice and invoice.billing_address)
                else "Registered Address"
            ) or "Registered Address"

            prod_name = (
                invoice.product_name
                if (invoice and invoice.product_name)
                else (
                    sub.product.name
                    if (sub and sub.product and sub.product.name)
                    else ("Multi-package subscription" if (sub and not getattr(sub, "product_id", None)) else "Healthy Meal Plan")
                )
            ) or "Healthy Meal Plan"

            plan_name = (
                invoice.plan_name
                if (invoice and invoice.plan_name)
                else (
                    sub.plan.name
                    if (sub and sub.plan and sub.plan.name)
                    else (f"{str(sub.plan_type).upper()} Plan" if (sub and getattr(sub, "plan_type", None)) else "Subscription Plan")
                )
            ) or "Subscription Plan"

            total_del = (
                invoice.total_deliveries
                if (invoice and invoice.total_deliveries is not None)
                else (sub.total_deliveries if (sub and sub.total_deliveries is not None) else 0)
            ) or 0

            price_per = (
                float(invoice.price_per_delivery)
                if (invoice and invoice.price_per_delivery is not None)
                else (float(getattr(sub, 'price_per_delivery', 0.0) or 0.0) if sub else 0.0)
            )

            subtotal = (
                float(invoice.subtotal)
                if (invoice and invoice.subtotal is not None)
                else (price_per * total_del)
            )

            del_charge = (
                float(invoice.delivery_charge)
                if (invoice and invoice.delivery_charge is not None)
                else (float(sub.delivery_charge) if (sub and sub.delivery_charge is not None) else 0.0)
            )

            tax_amt = (
                float(invoice.tax_amount)
                if (invoice and invoice.tax_amount is not None)
                else (float(sub.tax_amount) if (sub and sub.tax_amount is not None) else 0.0)
            )

            total_amt = (
                float(invoice.total_amount)
                if (invoice and invoice.total_amount is not None)
                else (float(payment.amount) if (payment and payment.amount is not None) else 0.0)
            )

            paid_date = (
                payment.paid_at.strftime('%B %d, %Y')
                if (payment and payment.paid_at)
                else (payment.created_at.strftime('%B %d, %Y') if (payment and payment.created_at) else datetime.now().strftime('%B %d, %Y'))
            )

            pmt_method = (
                payment.payment_method.value
                if (payment and payment.payment_method and hasattr(payment.payment_method, "value"))
                else (str(payment.payment_method) if (payment and payment.payment_method) else "Razorpay")
            ) or "Razorpay"

            status_str = (
                payment.status.value
                if (payment and payment.status and hasattr(payment.status, "value"))
                else (str(payment.status) if (payment and payment.status) else "SUCCESS")
            ) or "SUCCESS"

            item_rows = []
            if sub and sub.items and len(sub.items) > 0:
                for it in sub.items:
                    pname = it.product.name if (it.product and it.product.name) else "Meal Package"
                    p_price = float(it.package_price or 0.0)
                    it_qty = int(it.quantity or 1)
                    item_rows.append([
                        Paragraph(f"<b>{pname}</b><br/><font size=8 color='#666666'>Plan: {str(plan_name).title()}</font>", normal_style),
                        Paragraph(f"INR {p_price:.2f}", right_normal),
                        Paragraph(f"{it_qty}", right_normal),
                        Paragraph(f"INR {(p_price * it_qty):.2f}", right_bold),
                    ])
            else:
                item_rows.append([
                    Paragraph(f"<b>{prod_name}</b><br/><font size=8 color='#666666'>Plan: {str(plan_name).title()}</font>", normal_style),
                    Paragraph(f"INR {price_per:.2f}", right_normal),
                    Paragraph(f"{total_del}", right_normal),
                    Paragraph(f"INR {subtotal:.2f}", right_bold),
                ])

        # Generate PDF using ReportLab
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=letter,
            rightMargin=36,
            leftMargin=36,
            topMargin=36,
            bottomMargin=36
        )

        story = []

        # Header
        story.append(Paragraph("HEALTHY HOME FOODS", title_style))
        story.append(Paragraph("Fresh, Healthy & Home-Cooked Meals", subtitle_style))
        story.append(Spacer(1, 12))
        story.append(HRFlowable(width="100%", thickness=2, color=colors.HexColor('#2E7D32'), spaceAfter=15))

        # Billed To and Invoice Details
        left_info = [
            Paragraph("BILLED TO", h2_style),
            Spacer(1, 4),
            Paragraph(f"<b>{cust_name}</b>", normal_style),
            Paragraph(f"Phone: {cust_phone}", normal_style),
        ]
        if cust_email:
            left_info.append(Paragraph(f"Email: {cust_email}", normal_style))
        if billing_addr:
            left_info.append(Paragraph(f"Address: {billing_addr}", normal_style))

        right_info = [
            Paragraph("INVOICE DETAILS", h2_style),
            Spacer(1, 4),
            Paragraph(f"<b>Invoice No:</b> {invoice_no}", normal_style),
            Paragraph(f"<b>Date:</b> {paid_date}", normal_style),
            Paragraph(f"<b>Payment Method:</b> {pmt_method.upper()}", normal_style),
            Paragraph(f"<b>Status:</b> <font color='#2E7D32'><b>{status_str.upper()}</b></font>", normal_style),
        ]

        info_table = Table([[left_info, right_info]], colWidths=[270, 270])
        info_table.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'TOP'),
            ('LEFTPADDING', (0,0), (-1,-1), 0),
            ('RIGHTPADDING', (0,0), (-1,-1), 0),
        ]))
        story.append(info_table)
        story.append(Spacer(1, 20))

        # Items Table
        headers = [
            Paragraph("<b>Item Description</b>", ParagraphStyle('TH1', parent=normal_style, textColor=colors.white, fontName='Helvetica-Bold')),
            Paragraph("<b>Unit Price</b>", ParagraphStyle('TH2', parent=right_normal, textColor=colors.white, fontName='Helvetica-Bold')),
            Paragraph("<b>Qty / Del.</b>", ParagraphStyle('TH3', parent=right_normal, textColor=colors.white, fontName='Helvetica-Bold')),
            Paragraph("<b>Total</b>", ParagraphStyle('TH4', parent=right_normal, textColor=colors.white, fontName='Helvetica-Bold')),
        ]
        
        table_data = [headers] + item_rows
        items_table = Table(table_data, colWidths=[240, 100, 80, 120])
        items_table.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#2E7D32')),
            ('ALIGN', (1,0), (-1,-1), 'RIGHT'),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('BOTTOMPADDING', (0,0), (-1,-1), 8),
            ('TOPPADDING', (0,0), (-1,-1), 8),
            ('LINEBELOW', (0,1), (-1,1), 1, colors.HexColor('#EEEEEE')),
        ]))
        story.append(items_table)
        story.append(Spacer(1, 15))

        # Summary
        summary_data = [
            [Paragraph("Subtotal", normal_style), Paragraph(f"INR {subtotal:.2f}", right_normal)],
            [Paragraph("Delivery Charge", normal_style), Paragraph(f"INR {del_charge:.2f}", right_normal)],
            [Paragraph("Tax Amount", normal_style), Paragraph(f"INR {tax_amt:.2f}", right_normal)],
            [Paragraph("<b>Total Paid</b>", ParagraphStyle('TotL', parent=normal_style, fontName='Helvetica-Bold', fontSize=12, textColor=colors.HexColor('#2E7D32'))),
             Paragraph(f"<b>INR {total_amt:.2f}</b>", ParagraphStyle('TotR', parent=right_normal, fontName='Helvetica-Bold', fontSize=12, textColor=colors.HexColor('#2E7D32')))],
        ]
        summary_table = Table(summary_data, colWidths=[140, 100])
        summary_table.setStyle(TableStyle([
            ('ALIGN', (1,0), (1,-1), 'RIGHT'),
            ('TOPPADDING', (0,0), (-1,-1), 4),
            ('BOTTOMPADDING', (0,0), (-1,-1), 4),
            ('LINEABOVE', (0,-1), (-1,-1), 1.5, colors.HexColor('#2E7D32')),
        ]))

        wrapper_table = Table([["", summary_table]], colWidths=[300, 240])
        wrapper_table.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'TOP'),
            ('LEFTPADDING', (0,0), (-1,-1), 0),
            ('RIGHTPADDING', (0,0), (-1,-1), 0),
        ]))
        story.append(wrapper_table)
        story.append(Spacer(1, 30))

        # Footer
        story.append(HRFlowable(width="100%", thickness=0.5, color=colors.HexColor('#CCCCCC'), spaceAfter=10))
        story.append(Paragraph("Thank you for subscribing to Healthy Home Foods! For support, contact support@healthyhomefoods.com", ParagraphStyle('Footer', parent=normal_style, alignment=1, fontSize=9, textColor=colors.HexColor('#888888'))))

        doc.build(story)
        pdf_bytes = buffer.getvalue()
        buffer.close()

        return StreamingResponse(
            io.BytesIO(pdf_bytes),
            media_type="application/pdf",
            headers={"Content-Disposition": f"attachment; filename={invoice_no}.pdf"},
        )
    except HTTPException:
        raise
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"Error generating invoice PDF for payment {payment_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate invoice PDF: {str(e)}"
        )
