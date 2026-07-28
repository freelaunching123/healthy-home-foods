from datetime import date, datetime, timedelta, timezone
from uuid import UUID
from typing import Optional, List
from fastapi import APIRouter, Depends, Query, HTTPException
from fastapi.responses import JSONResponse, StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, desc, or_
import io

from app.db.session import get_db
from app.core.dependencies import require_super_admin
from app.models.user import User
from app.models.subscription import Subscription, SubscriptionStatus, SubscriptionItem
from app.models.payment import Payment, PaymentStatus
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.delivery_assignment import DeliveryAssignment
from app.models.delivery_partner import DeliveryPartner
from app.models.customer import Customer
from app.models.product import Product, ProductCategory
from app.models.fruit import Fruit, FruitOrder, FruitOrderItem, FruitAvailability, FruitOrderStatus, FruitPaymentStatus
from app.schemas.common import MessageResponse, DashboardStats, DeliveryPartnerPerformance

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
            .join(SubscriptionDelivery, DeliveryAssignment.subscription_delivery_id == SubscriptionDelivery.id)
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


@router.get("/product-performance-summary")
async def get_product_performance_summary(
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    # Total, Active, Inactive product counts
    total_products = await db.scalar(select(func.count(Product.id)))
    active_products = await db.scalar(select(func.count(Product.id)).where(Product.is_active == True))
    inactive_products = await db.scalar(select(func.count(Product.id)).where(Product.is_active == False))

    # Query all products and their successful (DELIVERED) delivery counts
    # This will allow us to sort them in python to get top 5 and bottom 5.
    query = (
        select(
            Product.id,
            Product.name,
            func.count(SubscriptionDelivery.id).label("delivered_count")
        )
        .outerjoin(SubscriptionItem, SubscriptionItem.product_id == Product.id)
        .outerjoin(Subscription, Subscription.id == SubscriptionItem.subscription_id)
        .outerjoin(
            SubscriptionDelivery,
            and_(
                SubscriptionDelivery.subscription_id == Subscription.id,
                SubscriptionDelivery.status == DeliveryStatus.DELIVERED
            )
        )
        .group_by(Product.id, Product.name)
    )

    result = await db.execute(query)
    rows = result.all()
    
    performance_list = [
        {
            "id": str(row[0]),
            "name": row[1],
            "delivered_count": row[2]
        }
        for row in rows
    ]

    # Sort for top performing (descending)
    top_performing = sorted(performance_list, key=lambda x: x["delivered_count"], reverse=True)[:5]
    # Sort for worst performing (ascending)
    worst_performing = sorted(performance_list, key=lambda x: x["delivered_count"])[:5]

    return {
        "total_products": total_products or 0,
        "active_products": active_products or 0,
        "inactive_products": inactive_products or 0,
        "top_performing": top_performing,
        "worst_performing": worst_performing,
    }


@router.get("/category-performance")
async def get_category_performance(
    category_id: UUID,
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    # Verify if category exists
    cat_result = await db.execute(select(ProductCategory).where(ProductCategory.id == category_id))
    if not cat_result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Category not found")

    # Filter conditions for deliveries
    delivery_filter = [SubscriptionDelivery.status == DeliveryStatus.DELIVERED]
    if start_date:
        delivery_filter.append(SubscriptionDelivery.scheduled_date >= start_date)
    if end_date:
        delivery_filter.append(SubscriptionDelivery.scheduled_date <= end_date)

    query = (
        select(
            Product.id,
            Product.name,
            func.count(SubscriptionDelivery.id).label("delivered_count")
        )
        .where(Product.category_id == category_id)
        .outerjoin(SubscriptionItem, SubscriptionItem.product_id == Product.id)
        .outerjoin(Subscription, Subscription.id == SubscriptionItem.subscription_id)
        .outerjoin(
            SubscriptionDelivery,
            and_(
                SubscriptionDelivery.subscription_id == Subscription.id,
                *delivery_filter
            )
        )
        .group_by(Product.id, Product.name)
    )

    result = await db.execute(query)
    rows = result.all()

    performance = [
        {
            "id": str(row[0]),
            "name": row[1],
            "delivered_count": row[2]
        }
        for row in rows
    ]

    return performance


# ── Admin Overview Dashboard ──────────────────────────────────────────────────

@router.get("/admin-overview")
async def get_admin_overview(
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Single aggregated endpoint for the Admin Dashboard Overview screen.
    Returns: summary cards, quick insights, 7-day revenue chart, recent activity.
    All values are computed live from the database — no hardcoded data.
    """
    today = date.today()
    now_utc = datetime.now(timezone.utc)

    # ── 1. Summary Cards ───────────────────────────────────────────────────────

    # Today's revenue (successful payments today)
    todays_revenue_result = await db.execute(
        select(func.coalesce(func.sum(Payment.amount), 0))
        .where(
            Payment.status == PaymentStatus.SUCCESS,
            func.date(Payment.paid_at) == today,
        )
    )
    todays_revenue = float(todays_revenue_result.scalar_one())

    # Orders today = subscription deliveries scheduled today + fruit orders created today
    sub_deliveries_today = await db.scalar(
        select(func.count(SubscriptionDelivery.id))
        .where(SubscriptionDelivery.scheduled_date == today)
    )
    fruit_orders_today = await db.scalar(
        select(func.count(FruitOrder.id))
        .where(
            func.date(FruitOrder.created_at) == today,
            FruitOrder.payment_status == FruitPaymentStatus.SUCCESS,
        )
    )
    orders_today = (sub_deliveries_today or 0) + (fruit_orders_today or 0)

    # Active subscribers
    active_subscribers = await db.scalar(
        select(func.count(Subscription.id))
        .where(Subscription.status == SubscriptionStatus.ACTIVE)
    )

    # Pending deliveries today
    pending_deliveries = await db.scalar(
        select(func.count(SubscriptionDelivery.id))
        .where(
            SubscriptionDelivery.scheduled_date == today,
            SubscriptionDelivery.status == DeliveryStatus.PENDING,
        )
    )

    # ── 2. Quick Insights ──────────────────────────────────────────────────────

    # Top selling package — product with most active/completed subscriptions
    top_package_result = await db.execute(
        select(
            Product.id,
            Product.name,
            Product.image_url,
            func.count(Subscription.id).label("sub_count"),
        )
        .join(Subscription, and_(
            Subscription.product_id == Product.id,
            Subscription.status.in_([SubscriptionStatus.ACTIVE, SubscriptionStatus.COMPLETED])
        ))
        .group_by(Product.id, Product.name, Product.image_url)
        .order_by(desc("sub_count"))
        .limit(1)
    )
    top_package_row = top_package_result.first()
    top_selling_package = None
    if top_package_row and top_package_row[3] > 0:
        top_selling_package = {
            "name": top_package_row[1],
            "image_url": top_package_row[2],
            "count": top_package_row[3],
        }

    # Most ordered fruit — by number of order items (count of distinct paid orders containing the fruit)
    most_ordered_fruit_result = await db.execute(
        select(
            Fruit.id,
            Fruit.name,
            Fruit.image_url,
            func.count(FruitOrder.id).label("order_count"),
        )
        .join(FruitOrderItem, FruitOrderItem.fruit_id == Fruit.id)
        .join(FruitOrder, and_(
            FruitOrder.id == FruitOrderItem.order_id, 
            FruitOrder.payment_status == FruitPaymentStatus.SUCCESS
        ))
        .group_by(Fruit.id, Fruit.name, Fruit.image_url)
        .order_by(desc("order_count"))
        .limit(1)
    )
    most_fruit_row = most_ordered_fruit_result.first()
    most_ordered_fruit = None
    if most_fruit_row and most_fruit_row[3] > 0:
        most_ordered_fruit = {
            "name": most_fruit_row[1],
            "image_url": most_fruit_row[2],
            "count": most_fruit_row[3],
        }

    # Low stock alerts — fruits that are out of stock or temporarily unavailable (max 5)
    low_stock_result = await db.execute(
        select(Fruit.name, Fruit.availability_status)
        .where(
            Fruit.is_active == True,
            Fruit.availability_status.in_([
                FruitAvailability.OUT_OF_STOCK,
                FruitAvailability.TEMPORARILY_UNAVAILABLE,
            ])
        )
        .order_by(Fruit.name)
        .limit(5)
    )
    low_stock_alerts = [
        {"name": row[0], "status": row[1].value if hasattr(row[1], "value") else str(row[1])}
        for row in low_stock_result.all()
    ]

    # ── 3. Revenue Chart — Last 7 Days ─────────────────────────────────────────

    revenue_chart = []
    for i in range(6, -1, -1):  # 6 days ago → today
        chart_date = today - timedelta(days=i)
        rev_result = await db.execute(
            select(func.coalesce(func.sum(Payment.amount), 0))
            .where(
                Payment.status == PaymentStatus.SUCCESS,
                func.date(Payment.paid_at) == chart_date,
            )
        )
        revenue_chart.append({
            "date": str(chart_date),
            "revenue": float(rev_result.scalar_one()),
        })

    # ── 4. Recent Activity Feed ────────────────────────────────────────────────
    # Collect recent events from multiple sources, merge and sort by timestamp.

    activity: List[dict] = []

    # New customer registrations (last 30 days)
    new_customers_result = await db.execute(
        select(Customer.id, Customer.created_at)
        .order_by(desc(Customer.created_at))
        .limit(5)
    )
    for row in new_customers_result.all():
        if row[1]:
            activity.append({
                "type": "new_customer",
                "description": "New customer registered",
                "timestamp": row[1].isoformat() if row[1] else None,
            })

    # Recent subscriptions created
    new_subs_result = await db.execute(
        select(Subscription.id, Subscription.created_at, Subscription.status)
        .order_by(desc(Subscription.created_at))
        .limit(5)
    )
    for row in new_subs_result.all():
        if row[1]:
            activity.append({
                "type": "new_subscription",
                "description": f"New subscription placed",
                "timestamp": row[1].isoformat() if row[1] else None,
            })

    # Completed deliveries (recent)
    completed_deliveries_result = await db.execute(
        select(SubscriptionDelivery.id, SubscriptionDelivery.updated_at, SubscriptionDelivery.scheduled_date)
        .where(SubscriptionDelivery.status == DeliveryStatus.DELIVERED)
        .order_by(desc(SubscriptionDelivery.updated_at))
        .limit(5)
    )
    for row in completed_deliveries_result.all():
        ts = row[1]
        if ts:
            activity.append({
                "type": "delivery_completed",
                "description": f"Delivery completed",
                "timestamp": ts.isoformat(),
            })

    # Products added (recently created)
    new_products_result = await db.execute(
        select(Product.id, Product.name, Product.created_at)
        .order_by(desc(Product.created_at))
        .limit(3)
    )
    for row in new_products_result.all():
        if row[2]:
            activity.append({
                "type": "product_added",
                "description": f"Product added: {row[1]}",
                "timestamp": row[2].isoformat() if row[2] else None,
            })

    # Recent successful payments
    recent_payments_result = await db.execute(
        select(Payment.id, Payment.amount, Payment.paid_at)
        .where(Payment.status == PaymentStatus.SUCCESS)
        .order_by(desc(Payment.paid_at))
        .limit(5)
    )
    for row in recent_payments_result.all():
        if row[2]:
            activity.append({
                "type": "payment_received",
                "description": f"Payment received: \u20b9{float(row[1]):.0f}",
                "timestamp": row[2].isoformat(),
            })

    # Sort all activity by timestamp descending, keep top 15
    activity_sorted = sorted(
        [a for a in activity if a.get("timestamp")],
        key=lambda x: x["timestamp"],
        reverse=True,
    )[:5]

    return {
        "summary": {
            "todays_revenue": todays_revenue,
            "orders_today": orders_today,
            "active_subscribers": active_subscribers or 0,
            "pending_deliveries": pending_deliveries or 0,
        },
        "quick_insights": {
            "top_selling_package": top_selling_package,
            "most_ordered_fruit": most_ordered_fruit,
            "low_stock_alerts": low_stock_alerts,
        },
        "revenue_chart": revenue_chart,
        "recent_activity": activity_sorted,
    }
