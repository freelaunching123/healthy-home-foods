from datetime import date, datetime, timedelta, timezone
from uuid import UUID
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, Query, HTTPException
from fastapi.responses import JSONResponse, StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, desc, or_, case
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

router = APIRouter(prefix="/reports", tags=["Reports & Analytics"])

def parse_dates(start_date: str | None, end_date: str | None):
    try:
        sd = datetime.strptime(start_date, "%Y-%m-%d").date() if start_date else (date.today() - timedelta(days=30))
        ed = datetime.strptime(end_date, "%Y-%m-%d").date() if end_date else date.today()
        return sd, ed
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")

@router.get("/overview")
async def get_overview(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    sd, ed = parse_dates(start_date, end_date)
    
    # 1. Total Revenue
    pkg_rev = await db.scalar(select(func.coalesce(func.sum(Payment.amount), 0)).where(and_(Payment.status == PaymentStatus.SUCCESS, func.date(Payment.paid_at) >= sd, func.date(Payment.paid_at) <= ed)))
    frt_rev = await db.scalar(select(func.coalesce(func.sum(FruitOrder.total_amount), 0)).where(and_(FruitOrder.payment_status == FruitPaymentStatus.SUCCESS, func.date(FruitOrder.paid_at) >= sd, func.date(FruitOrder.paid_at) <= ed)))
    total_revenue = float(pkg_rev or 0) + float(frt_rev or 0)
    
    # 2. Total Orders (Subscriptions + Fruit Orders)
    pkg_orders = await db.scalar(select(func.count(Subscription.id)).where(and_(func.date(Subscription.created_at) >= sd, func.date(Subscription.created_at) <= ed)))
    frt_orders = await db.scalar(select(func.count(FruitOrder.id)).where(and_(func.date(FruitOrder.created_at) >= sd, func.date(FruitOrder.created_at) <= ed)))
    total_orders = (pkg_orders or 0) + (frt_orders or 0)
    
    avg_order_value = total_revenue / total_orders if total_orders > 0 else 0
    
    # 3. Total Customers
    total_customers = await db.scalar(select(func.count(Customer.id)))
    
    # 4. Total Deliveries & Pending (for the period)
    total_deliv = await db.scalar(select(func.count(SubscriptionDelivery.id)).where(and_(func.date(SubscriptionDelivery.scheduled_date) >= sd, func.date(SubscriptionDelivery.scheduled_date) <= ed)))
    pending_deliv = await db.scalar(select(func.count(SubscriptionDelivery.id)).where(and_(func.date(SubscriptionDelivery.scheduled_date) >= sd, func.date(SubscriptionDelivery.scheduled_date) <= ed, SubscriptionDelivery.status == DeliveryStatus.PENDING)))
    
    # 5. Cancelled Orders
    canc_pkg = await db.scalar(select(func.count(Subscription.id)).where(and_(Subscription.status == SubscriptionStatus.CANCELLED, func.date(Subscription.created_at) >= sd, func.date(Subscription.created_at) <= ed)))
    canc_frt = await db.scalar(select(func.count(FruitOrder.id)).where(and_(FruitOrder.order_status == FruitOrderStatus.CANCELLED, func.date(FruitOrder.created_at) >= sd, func.date(FruitOrder.created_at) <= ed)))
    cancelled_orders = (canc_pkg or 0) + (canc_frt or 0)
    
    # 6. Active Subscriptions
    active_subs = await db.scalar(select(func.count(Subscription.id)).where(Subscription.status == SubscriptionStatus.ACTIVE))

    return {
        "total_revenue": total_revenue,
        "package_revenue": float(pkg_rev or 0),
        "fruit_revenue": float(frt_rev or 0),
        "total_orders": total_orders,
        "package_orders_count": pkg_orders or 0,
        "fruit_orders_count": frt_orders or 0,
        "total_customers": total_customers or 0,
        "total_deliveries": total_deliv or 0,
        "pending_deliveries": pending_deliv or 0,
        "cancelled_orders": cancelled_orders,
        "avg_order_value": avg_order_value,
        "active_subscriptions": active_subs or 0
    }

@router.get("/sales")
async def get_sales(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    sd, ed = parse_dates(start_date, end_date)
    # Return daily revenue grouped by date
    pkg_stmt = select(func.date(Payment.paid_at).label('d'), func.sum(Payment.amount)).where(and_(Payment.status == PaymentStatus.SUCCESS, func.date(Payment.paid_at) >= sd, func.date(Payment.paid_at) <= ed)).group_by(func.date(Payment.paid_at))
    frt_stmt = select(func.date(FruitOrder.paid_at).label('d'), func.sum(FruitOrder.total_amount)).where(and_(FruitOrder.payment_status == FruitPaymentStatus.SUCCESS, func.date(FruitOrder.paid_at) >= sd, func.date(FruitOrder.paid_at) <= ed)).group_by(func.date(FruitOrder.paid_at))
    
    pkg_res = await db.execute(pkg_stmt)
    frt_res = await db.execute(frt_stmt)
    
    sales_dict = {}
    for d, amt in pkg_res.all():
        if d:
            ds = str(d)
            sales_dict[ds] = sales_dict.get(ds, 0) + float(amt)
    for d, amt in frt_res.all():
        if d:
            ds = str(d)
            sales_dict[ds] = sales_dict.get(ds, 0) + float(amt)
        
    daily_sales = [{"date": k, "revenue": v} for k, v in sorted(sales_dict.items())]
    return {"daily_sales": daily_sales}

@router.get("/packages")
async def get_packages(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    sd, ed = parse_dates(start_date, end_date)
    stmt = (
        select(Product.name, func.count(Subscription.id).label('c'), func.sum(Subscription.total_amount))
        .join(Subscription, Subscription.product_id == Product.id)
        .where(and_(func.date(Subscription.created_at) >= sd, func.date(Subscription.created_at) <= ed))
        .group_by(Product.id, Product.name)
        .order_by(desc('c'))
    )
    res = await db.execute(stmt)
    items = []
    for row in res.all():
        items.append({"name": row[0], "orders": row[1], "revenue": float(row[2] or 0)})
    return {
        "top_selling": items[:5],
        "least_selling": items[-5:] if len(items) > 5 else list(reversed(items)),
        "all": items
    }

@router.get("/fruits")
async def get_fruits(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    sd, ed = parse_dates(start_date, end_date)
    stmt = (
        select(Fruit.name, func.sum(FruitOrderItem.quantity_kg).label('q'), func.sum(FruitOrderItem.price_per_kg * FruitOrderItem.quantity_kg).label('rev'))
        .join(FruitOrderItem, FruitOrderItem.fruit_id == Fruit.id)
        .join(FruitOrder, FruitOrder.id == FruitOrderItem.order_id)
        .where(and_(func.date(FruitOrder.created_at) >= sd, func.date(FruitOrder.created_at) <= ed))
        .group_by(Fruit.id, Fruit.name)
        .order_by(desc('q'))
    )
    res = await db.execute(stmt)
    items = []
    for row in res.all():
        items.append({"name": row[0], "quantity": int(row[1] or 0), "revenue": float(row[2] or 0)})
        
    return {
        "top_selling": items[:5],
        "least_selling": items[-5:] if len(items) > 5 else list(reversed(items)),
        "all": items
    }

@router.get("/customers")
async def get_customers(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    sd, ed = parse_dates(start_date, end_date)
    total = await db.scalar(select(func.count(Customer.id)))
    new_c = await db.scalar(select(func.count(Customer.id)).where(and_(func.date(Customer.created_at) >= sd, func.date(Customer.created_at) <= ed)))
    return {
        "total": total,
        "new": new_c,
        "active": total, 
        "inactive": 0
    }

@router.get("/deliveries")
async def get_deliveries(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    sd, ed = parse_dates(start_date, end_date)
    stmt = select(SubscriptionDelivery.status, func.count(SubscriptionDelivery.id)).where(and_(func.date(SubscriptionDelivery.scheduled_date) >= sd, func.date(SubscriptionDelivery.scheduled_date) <= ed)).group_by(SubscriptionDelivery.status)
    res = await db.execute(stmt)
    status_counts = {str(k.value if hasattr(k, 'value') else k): v for k, v in res.all()}
    
    return {
        "status_breakdown": status_counts
    }

@router.get("/orders")
async def get_orders(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    sd, ed = parse_dates(start_date, end_date)
    pkg_stmt = select(Subscription.status, func.count(Subscription.id)).where(and_(func.date(Subscription.created_at) >= sd, func.date(Subscription.created_at) <= ed)).group_by(Subscription.status)
    pkg_res = await db.execute(pkg_stmt)
    pkg_counts = {str(k.value if hasattr(k, 'value') else k): v for k, v in pkg_res.all()}
    
    frt_stmt = select(FruitOrder.order_status, func.count(FruitOrder.id)).where(and_(func.date(FruitOrder.created_at) >= sd, func.date(FruitOrder.created_at) <= ed)).group_by(FruitOrder.order_status)
    frt_res = await db.execute(frt_stmt)
    frt_counts = {str(k.value if hasattr(k, 'value') else k): v for k, v in frt_res.all()}
    
    return {
        "package_orders": pkg_counts,
        "fruit_orders": frt_counts,
    }

@router.get("/payments")
async def get_payments(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    sd, ed = parse_dates(start_date, end_date)
    pkg_stmt = select(Payment.status, func.count(Payment.id), func.sum(Payment.amount)).where(and_(func.date(Payment.created_at) >= sd, func.date(Payment.created_at) <= ed)).group_by(Payment.status)
    pkg_res = await db.execute(pkg_stmt)
    
    counts = {}
    total_collected = 0.0
    for st, c, amt in pkg_res.all():
        if st is not None:
            s = str(st.value if hasattr(st, 'value') else st)
            counts[s] = counts.get(s, 0) + c
            if s == 'success':
                total_collected += float(amt or 0)
            
    return {
        "status_counts": counts,
        "total_collected": total_collected
    }

@router.get("/export/excel")
async def export_excel(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_super_admin)
):
    import openpyxl
    overview = await get_admin_overview(db=db)
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Overview Report"
    
    ws.append(["Report generated on", date.today().isoformat()])
    ws.append([])
    
    ws.append(["--- SUMMARY ---"])
    summary = overview["summary"]
    ws.append(["Today's Revenue", f"Rs. {summary['todays_revenue']:.2f}"])
    ws.append(["Orders Today", summary['orders_today']])
    ws.append(["Active Subscribers", summary['active_subscribers']])
    ws.append(["Pending Deliveries", summary['pending_deliveries']])
    ws.append([])
    
    ws.append(["--- QUICK INSIGHTS ---"])
    insights = overview["quick_insights"]
    if insights["top_selling_package"]:
        ws.append(["Top Selling Package", f"{insights['top_selling_package']['name']} (x{insights['top_selling_package']['count']})"])
    if insights["most_ordered_fruit"]:
        ws.append(["Most Ordered Fruit", f"{insights['most_ordered_fruit']['name']} (x{insights['most_ordered_fruit']['count']})"])
    ws.append([])
    
    ws.append(["--- REVENUE CHART (LAST 7 DAYS) ---"])
    ws.append(["Date", "Revenue"])
    for day in overview["revenue_chart"]:
        ws.append([day["date"], f"Rs. {day['revenue']:.2f}"])
        
    buffer = io.BytesIO()
    wb.save(buffer)
    buffer.seek(0)
    return StreamingResponse(
        buffer,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=report.xlsx"},
    )

@router.get("/export/pdf")
async def export_pdf(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_super_admin)
):
    from fpdf import FPDF
    
    overview = await get_admin_overview(db=db)
    summary = overview["summary"]
    insights = overview["quick_insights"]
    
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("helvetica", size=16, style="B")
    pdf.cell(200, 10, txt="Healthy Home Foods - Admin Report", ln=True, align='C')
    pdf.set_font("helvetica", size=10)
    pdf.cell(200, 10, txt=f"Generated on: {date.today().isoformat()}", ln=True, align='C')
    pdf.ln(10)
    
    pdf.set_font("helvetica", size=14, style="B")
    pdf.cell(200, 10, txt="Summary", ln=True)
    pdf.set_font("helvetica", size=12)
    pdf.cell(200, 10, txt=f"Today's Revenue: Rs. {summary['todays_revenue']:.2f}", ln=True)
    pdf.cell(200, 10, txt=f"Orders Today: {summary['orders_today']}", ln=True)
    pdf.cell(200, 10, txt=f"Active Subscribers: {summary['active_subscribers']}", ln=True)
    pdf.cell(200, 10, txt=f"Pending Deliveries: {summary['pending_deliveries']}", ln=True)
    pdf.ln(5)
    
    pdf.set_font("helvetica", size=14, style="B")
    pdf.cell(200, 10, txt="Quick Insights", ln=True)
    pdf.set_font("helvetica", size=12)
    if insights["top_selling_package"]:
        pdf.cell(200, 10, txt=f"Top Selling Package: {insights['top_selling_package']['name']} (x{insights['top_selling_package']['count']})", ln=True)
    if insights["most_ordered_fruit"]:
        pdf.cell(200, 10, txt=f"Most Ordered Fruit: {insights['most_ordered_fruit']['name']} (x{insights['most_ordered_fruit']['count']})", ln=True)
    pdf.ln(5)
    
    pdf.set_font("helvetica", size=14, style="B")
    pdf.cell(200, 10, txt="Revenue Last 7 Days", ln=True)
    pdf.set_font("helvetica", size=12)
    for day in overview["revenue_chart"]:
        pdf.cell(200, 10, txt=f"{day['date']}: Rs. {day['revenue']:.2f}", ln=True)
    
    pdf_bytes = pdf.output(dest='S')
    
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf", 
        headers={"Content-Disposition": "attachment; filename=report.pdf"}
    )

@router.get("/admin-overview")
async def get_admin_overview(
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    today = date.today()
    sd_7 = today - timedelta(days=6)
    
    # Summary
    todays_pkg_rev = await db.scalar(select(func.sum(Payment.amount)).where(and_(Payment.status == PaymentStatus.SUCCESS, func.date(Payment.paid_at) == today)))
    todays_frt_rev = await db.scalar(select(func.sum(FruitOrder.total_amount)).where(and_(FruitOrder.payment_status == FruitPaymentStatus.SUCCESS, func.date(FruitOrder.paid_at) == today)))
    todays_revenue = float(todays_pkg_rev or 0) + float(todays_frt_rev or 0)
    
    orders_pkg = await db.scalar(select(func.count(Subscription.id)).where(func.date(Subscription.created_at) == today))
    orders_frt = await db.scalar(select(func.count(FruitOrder.id)).where(func.date(FruitOrder.created_at) == today))
    orders_today = (orders_pkg or 0) + (orders_frt or 0)
    
    active_subscribers = await db.scalar(select(func.count(Subscription.id)).where(Subscription.status == SubscriptionStatus.ACTIVE))
    
    pending_deliveries = await db.scalar(select(func.count(SubscriptionDelivery.id)).where(and_(SubscriptionDelivery.status == DeliveryStatus.PENDING, func.date(SubscriptionDelivery.scheduled_date) == today)))
    
    # Insights
    top_pkg_res = await db.execute(select(Product.name, func.count(Subscription.id).label('c')).join(Subscription, Subscription.product_id == Product.id).group_by(Product.id).order_by(desc('c')).limit(1))
    top_pkg_row = top_pkg_res.first()
    top_selling_package = {"name": top_pkg_row[0], "count": top_pkg_row[1]} if top_pkg_row else None
    
    top_frt_res = await db.execute(select(Fruit.name, func.count(FruitOrderItem.id).label('c')).join(FruitOrderItem, FruitOrderItem.fruit_id == Fruit.id).group_by(Fruit.id).order_by(desc('c')).limit(1))
    top_frt_row = top_frt_res.first()
    most_ordered_fruit = {"name": top_frt_row[0], "count": top_frt_row[1]} if top_frt_row else None
    
    # Revenue Chart (Last 7 days)
    chart_data = []
    for i in range(7):
        d = sd_7 + timedelta(days=i)
        p_rev = await db.scalar(select(func.sum(Payment.amount)).where(and_(Payment.status == PaymentStatus.SUCCESS, func.date(Payment.paid_at) == d)))
        f_rev = await db.scalar(select(func.sum(FruitOrder.total_amount)).where(and_(FruitOrder.payment_status == FruitPaymentStatus.SUCCESS, func.date(FruitOrder.paid_at) == d)))
        chart_data.append({
            "date": d.strftime("%Y-%m-%d"),
            "revenue": float(p_rev or 0) + float(f_rev or 0)
        })
        
    # Recent Activity Logic
    activities = []
    
    # 1. Fruit Orders
    frt_stmt = select(FruitOrder, User.full_name).join(Customer, FruitOrder.customer_id == Customer.id).join(User, Customer.user_id == User.id).order_by(FruitOrder.created_at.desc()).limit(5)
    frt_res = await db.execute(frt_stmt)
    for fo, fname in frt_res:
        activities.append({
            "type": "fruit_order", "title": "New Fruit Order",
            "description": f"{fname or 'Customer'} placed Order #{fo.order_number}",
            "timestamp": fo.created_at
        })

    # 2. Subscriptions
    sub_stmt = select(Subscription, User.full_name).join(Customer, Subscription.customer_id == Customer.id).join(User, Customer.user_id == User.id).order_by(Subscription.created_at.desc()).limit(5)
    sub_res = await db.execute(sub_stmt)
    for sub, fname in sub_res:
        activities.append({
            "type": "subscription", "title": "New Subscription",
            "description": f"{fname or 'Customer'} purchased a package",
            "timestamp": sub.created_at
        })

    # 3. Deliveries
    del_stmt = select(DeliveryAssignment, User.full_name).join(DeliveryPartner, DeliveryAssignment.delivery_partner_id == DeliveryPartner.id).join(User, DeliveryPartner.user_id == User.id).order_by(func.coalesce(DeliveryAssignment.delivered_at, DeliveryAssignment.out_at, DeliveryAssignment.assigned_at).desc()).limit(5)
    del_res = await db.execute(del_stmt)
    for assign, dpname in del_res:
        ts = assign.delivered_at or assign.out_at or assign.assigned_at
        if assign.status == AssignmentStatus.DELIVERED:
            title, activity_desc = "Order Delivered", f"{dpname} delivered an order"
        elif assign.status == AssignmentStatus.OUT_FOR_DELIVERY:
            title, activity_desc = "Out for Delivery", f"{dpname} is out for delivery"
        else:
            title, activity_desc = "Delivery Partner Assigned", f"Assigned to {dpname}"
        activities.append({
            "type": "delivery", "title": title, "description": activity_desc, "timestamp": ts
        })

    # 4. Customers
    cust_stmt = select(Customer, User.full_name).join(User, Customer.user_id == User.id).order_by(Customer.created_at.desc()).limit(5)
    cust_res = await db.execute(cust_stmt)
    for cust, fname in cust_res:
        activities.append({
            "type": "customer", "title": "New Customer",
            "description": f"{fname or 'A new customer'} registered",
            "timestamp": cust.created_at
        })

    activities.sort(key=lambda x: x["timestamp"] if x["timestamp"] else datetime.min.replace(tzinfo=timezone.utc), reverse=True)
    recent_activity = []
    for a in activities[:5]:
        a["timestamp"] = a["timestamp"].isoformat() if a["timestamp"] else None
        recent_activity.append(a)

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
        },
        "revenue_chart": chart_data,
        "recent_activity": recent_activity
    }
