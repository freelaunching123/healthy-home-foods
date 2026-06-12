from datetime import date, timedelta
from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
import io

from app.db.session import get_db
from app.core.dependencies import require_super_admin
from app.models.user import User
from app.models.subscription import Subscription, SubscriptionStatus
from app.models.payment import Payment, PaymentStatus
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.delivery_assignment import DeliveryAssignment
from app.models.delivery_partner import DeliveryPartner
from app.models.customer import Customer
from app.schemas.common import DashboardStats, DeliveryPartnerPerformance

router = APIRouter(prefix="/reports", tags=["Reports & Analytics"])


@router.get("/dashboard", response_model=DashboardStats)
async def get_dashboard_stats(
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    today = date.today()
    week_ago = today - timedelta(days=7)
    month_ago = today - timedelta(days=30)
    month_start = today.replace(day=1)

    # Revenue aggregations
    async def revenue_between(start: date, end: date) -> float:
        result = await db.execute(
            select(func.coalesce(func.sum(Payment.amount), 0))
            .where(and_(Payment.status == PaymentStatus.SUCCESS,
                        func.date(Payment.paid_at) >= start,
                        func.date(Payment.paid_at) <= end))
        )
        return float(result.scalar_one())

    daily_rev = await revenue_between(today, today)
    weekly_rev = await revenue_between(week_ago, today)
    monthly_rev = await revenue_between(month_ago, today)

    # Subscription counts
    active_subs = await db.execute(select(func.count(Subscription.id)).where(Subscription.status == SubscriptionStatus.ACTIVE))
    expired_subs = await db.execute(select(func.count(Subscription.id)).where(Subscription.status == SubscriptionStatus.COMPLETED))

    # Customer growth
    total_customers = await db.execute(select(func.count(Customer.id)))
    new_customers = await db.execute(select(func.count(Customer.id)).where(func.date(Customer.created_at) >= month_start))

    # Delivery performance
    total_del = await db.execute(select(func.count(SubscriptionDelivery.id)).where(
        SubscriptionDelivery.status.in_([DeliveryStatus.DELIVERED, DeliveryStatus.MISSED])
    ))
    delivered = await db.execute(select(func.count(SubscriptionDelivery.id)).where(SubscriptionDelivery.status == DeliveryStatus.DELIVERED))
    total_count = total_del.scalar_one() or 1
    success_rate = round((delivered.scalar_one() / total_count) * 100, 1)

    pending_del = await db.execute(select(func.count(SubscriptionDelivery.id)).where(
        and_(SubscriptionDelivery.scheduled_date == today, SubscriptionDelivery.status == DeliveryStatus.PENDING)
    ))
    missed_today = await db.execute(select(func.count(SubscriptionDelivery.id)).where(
        and_(SubscriptionDelivery.scheduled_date == today, SubscriptionDelivery.status == DeliveryStatus.MISSED)
    ))

    return DashboardStats(
        daily_revenue=daily_rev,
        weekly_revenue=weekly_rev,
        monthly_revenue=monthly_rev,
        active_subscriptions=active_subs.scalar_one(),
        expired_subscriptions=expired_subs.scalar_one(),
        total_customers=total_customers.scalar_one(),
        new_customers_this_month=new_customers.scalar_one(),
        delivery_success_rate=success_rate,
        pending_deliveries=pending_del.scalar_one(),
        missed_deliveries_today=missed_today.scalar_one(),
    )


@router.get("/delivery-partners", response_model=list[DeliveryPartnerPerformance])
async def delivery_partner_performance(
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
    days: int = Query(30, ge=1, le=365),
):
    """Performance report for all delivery partners over last N days."""
    since = date.today() - timedelta(days=days)
    partners_result = await db.execute(select(DeliveryPartner))
    partners = partners_result.scalars().all()
    performance = []
    for partner in partners:
        user_result = await db.execute(select(User).where(User.id == partner.user_id))
        user = user_result.scalar_one()
        assigned = await db.execute(
            select(func.count(DeliveryAssignment.id))
            .where(and_(DeliveryAssignment.delivery_partner_id == partner.id,
                        func.date(DeliveryAssignment.created_at) >= since))
        )
        delivered = await db.execute(
            select(func.count(DeliveryAssignment.id))
            .join(SubscriptionDelivery, DeliveryAssignment.delivery_id == SubscriptionDelivery.id)
            .where(and_(DeliveryAssignment.delivery_partner_id == partner.id,
                        SubscriptionDelivery.status == DeliveryStatus.DELIVERED,
                        func.date(DeliveryAssignment.created_at) >= since))
        )
        total_a = assigned.scalar_one() or 1
        total_d = delivered.scalar_one()
        performance.append(DeliveryPartnerPerformance(
            delivery_partner_id=partner.id,
            name=user.full_name,
            total_assigned=total_a,
            total_delivered=total_d,
            success_rate=round((total_d / total_a) * 100, 1),
            avg_rating=float(partner.rating) if partner.rating else None,
        ))
    return performance


@router.get("/export/excel")
async def export_excel(
    report_type: str = Query("revenue"),
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Export reports as Excel (.xlsx)."""
    import openpyxl
    from openpyxl.styles import Font, PatternFill, Alignment

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = report_type.title()

    header_font = Font(bold=True, color="FFFFFF")
    header_fill = PatternFill("solid", fgColor="2E7D32")

    if report_type == "revenue":
        headers = ["Date", "Revenue (₹)", "Subscriptions Sold", "New Customers"]
        ws.append(headers)
        for i, h in enumerate(headers, 1):
            cell = ws.cell(row=1, column=i)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = Alignment(horizontal="center")
        # Last 30 days data
        for i in range(30, 0, -1):
            d = date.today() - timedelta(days=i)
            rev_result = await db.execute(
                select(func.coalesce(func.sum(Payment.amount), 0))
                .where(and_(Payment.status == PaymentStatus.SUCCESS, func.date(Payment.paid_at) == d))
            )
            ws.append([str(d), float(rev_result.scalar_one()), 0, 0])

    elif report_type == "deliveries":
        headers = ["Date", "Total", "Delivered", "Missed", "Success Rate (%)"]
        ws.append(headers)
        for i, h in enumerate(headers, 1):
            cell = ws.cell(row=1, column=i)
            cell.font = header_font
            cell.fill = header_fill
        for i in range(30, 0, -1):
            d = date.today() - timedelta(days=i)
            total_r = await db.execute(select(func.count(SubscriptionDelivery.id)).where(func.date(SubscriptionDelivery.scheduled_date) == d))
            deliv_r = await db.execute(select(func.count(SubscriptionDelivery.id)).where(and_(func.date(SubscriptionDelivery.scheduled_date) == d, SubscriptionDelivery.status == DeliveryStatus.DELIVERED)))
            missed_r = await db.execute(select(func.count(SubscriptionDelivery.id)).where(and_(func.date(SubscriptionDelivery.scheduled_date) == d, SubscriptionDelivery.status == DeliveryStatus.MISSED)))
            total_v = total_r.scalar_one() or 1
            deliv_v = deliv_r.scalar_one()
            ws.append([str(d), total_v, deliv_v, missed_r.scalar_one(), round(deliv_v / total_v * 100, 1)])

    buffer = io.BytesIO()
    wb.save(buffer)
    buffer.seek(0)
    return StreamingResponse(
        buffer,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename={report_type}_report.xlsx"},
    )


@router.get("/export/pdf")
async def export_pdf(
    report_type: str = Query("revenue"),
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Export report as PDF using WeasyPrint."""
    from jinja2 import Environment, BaseLoader
    import weasyprint

    html_content = f"""
    <html>
    <head>
      <style>
        body {{ font-family: Arial; margin: 40px; }}
        h1 {{ color: #2E7D32; }}
        table {{ width: 100%; border-collapse: collapse; }}
        th {{ background: #2E7D32; color: white; padding: 8px; }}
        td {{ padding: 6px; border-bottom: 1px solid #ddd; }}
      </style>
    </head>
    <body>
      <h1>Healthy Home Foods — {report_type.title()} Report</h1>
      <p>Generated: {date.today()}</p>
      <p>Report: {report_type}</p>
    </body>
    </html>
    """
    pdf_bytes = weasyprint.HTML(string=html_content).write_pdf()
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename={report_type}_report.pdf"},
    )
