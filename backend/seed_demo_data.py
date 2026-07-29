import asyncio
import uuid
import random
from datetime import date, datetime, timedelta, timezone

from app.db.session import AsyncSessionLocal
from sqlalchemy import select, delete

from app.models.user import User, UserRoleEnum, UserStatus
from app.models.customer import Customer
from app.models.address import Address, AddressType
from app.models.delivery_partner import DeliveryPartner
from app.models.admin import Admin
from app.models.notification import Notification
from app.models.audit_log import AuditLog
from app.models.package_cart import PackageCart
from app.models.product import Product
from app.models.fruit import (
    Fruit, FruitAvailability, FruitOrder, FruitOrderStatus, FruitOrderItem, FruitPaymentStatus
)
from app.models.subscription import SubscriptionPlan, PlanType, Subscription, SubscriptionStatus
from app.models.subscription_delivery import SubscriptionDelivery, DeliveryStatus
from app.models.delivery_assignment import DeliveryAssignment, AssignmentStatus

async def seed():
    async with AsyncSessionLocal() as db:
        print("Cleaning up old demo data...")
        await db.execute(delete(User).where(User.phone.like('555%')))
        await db.commit()

        # 1. Create 10 Customers
        customer_names = ["Arun Kumar", "Priya", "Karthik", "Divya", "Naveen", "Meena", "Sanjay", "Harini", "Vignesh", "Keerthana"]
        customers_data = []
        for i, name in enumerate(customer_names):
            user = User(
                id=uuid.uuid4(),
                phone=f"55500010{i:02d}",
                email=f"demo_customer{i}@healthyhome.com",
                full_name=name,
                role=UserRoleEnum.CUSTOMER,
                status=UserStatus.ACTIVE
            )
            db.add(user)
            
            customer = Customer(
                id=uuid.uuid4(),
                user_id=user.id,
            )
            db.add(customer)

            address = Address(
                id=uuid.uuid4(),
                user_id=user.id,
                address_line1=f"{100 + i} Demo Street, Area {i}",
                city="Chennai",
                state="Tamil Nadu",
                pincode="600001",
                latitude=13.0827 + (i * 0.01),
                longitude=80.2707 + (i * 0.01),
                address_type="home"
            )
            db.add(address)
            customers_data.append((customer, address, user))

        # 2. Create 3 Delivery Partners
        partner_names = ["Dinesh", "Prakash", "Surya"]
        partners_data = []
        for i, name in enumerate(partner_names):
            user = User(
                id=uuid.uuid4(),
                phone=f"55500020{i:02d}",
                email=f"demo_partner{i}@healthyhome.com",
                full_name=name,
                role=UserRoleEnum.DELIVERY_PARTNER,
                status=UserStatus.ACTIVE
            )
            db.add(user)
            
            partner = DeliveryPartner(
                id=uuid.uuid4(),
                user_id=user.id,
                is_active=True,
                vehicle_type="Bike",
                vehicle_number=f"TN0{i} AB {1234+i}",
            )
            db.add(partner)
            partners_data.append(partner)

        # 3. Setup Fruits
        fruit_names = [("Apple", 120), ("Banana", 50), ("Orange", 80), ("Grapes", 150), ("Papaya", 60)]
        fruits = []
        for name, price in fruit_names:
            f = Fruit(
                id=uuid.uuid4(),
                name=name,
                price_per_kg=price,
                availability_status=FruitAvailability.IN_STOCK
            )
            db.add(f)
            fruits.append(f)

        # 4. Setup Packages
        plan1 = SubscriptionPlan(
            id=uuid.uuid4(),
            name="Healthy Family Pack",
            plan_type=PlanType.WEEKLY,
            total_deliveries=6,
            is_active=True
        )
        plan2 = SubscriptionPlan(
            id=uuid.uuid4(),
            name="Fruit Combo Pack",
            plan_type=PlanType.MONTHLY,
            total_deliveries=26,
            is_active=True
        )
        db.add_all([plan1, plan2])

        await db.commit()

        # Distribution rules
        status_pool = [
            ("pending", "pending"),
            ("pending", "pending"),
            ("assigned", "assigned"),
            ("assigned", "assigned"),
            ("out_for_delivery", "out"),
            ("out_for_delivery", "out"),
            ("delivered", "delivered"),
            ("delivered", "delivered"),
            ("failed", "failed"),
            ("cancelled", "cancelled")
        ]
        
        dates_pool = [
            date.today(), date.today(), date.today(),
            date.today() - timedelta(days=1), date.today() - timedelta(days=1),
            date.today() - timedelta(days=2), date.today() - timedelta(days=3),
            date.today() - timedelta(days=7), date.today() - timedelta(days=10),
            date.today() - timedelta(days=15)
        ]

        # 5. Create 5 Fruit Orders
        for i in range(5):
            c, a, u = customers_data[i]
            deliv_status, assign_status_val = status_pool[i]
            d = dates_pool[i]
            partner = partners_data[i % 3]
            
            pay_status = FruitPaymentStatus.SUCCESS if deliv_status != "cancelled" else FruitPaymentStatus.FAILED
            
            f_order = FruitOrder(
                id=uuid.uuid4(),
                customer_id=c.id,
                address_id=a.id,
                order_number=f"FO-100{i+1}",
                total_amount=220.0 + (i*50),
                payment_status=pay_status,
                order_status=FruitOrderStatus(deliv_status),
                delivery_date=d,
                delivery_slot="Morning (8 AM - 10 AM)",
                created_at=datetime.combine(d, datetime.min.time()).replace(tzinfo=timezone.utc)
            )
            db.add(f_order)
            
            # items
            item1 = FruitOrderItem(
                id=uuid.uuid4(),
                order_id=f_order.id,
                fruit_id=fruits[0].id,
                quantity_kg=1,
                price_per_kg=fruits[0].price_per_kg,
                subtotal=fruits[0].price_per_kg
            )
            db.add(item1)
            
            if deliv_status != "pending":
                assign = DeliveryAssignment(
                    id=uuid.uuid4(),
                    fruit_order_id=f_order.id,
                    delivery_partner_id=partner.id,
                    status=AssignmentStatus.ACCEPTED if deliv_status == "assigned" else 
                           AssignmentStatus.OUT_FOR_DELIVERY if deliv_status == "out_for_delivery" else
                           AssignmentStatus.DELIVERED if deliv_status == "delivered" else
                           AssignmentStatus.FAILED if deliv_status == "failed" else AssignmentStatus.REJECTED,
                    assigned_at=datetime.combine(d, datetime.min.time()).replace(tzinfo=timezone.utc),
                    created_at=datetime.combine(d, datetime.min.time()).replace(tzinfo=timezone.utc)
                )
                db.add(assign)

        # 6. Create 5 Package Orders (Subscriptions)
        for i in range(5, 10):
            c, a, u = customers_data[i]
            sub_status, assign_status_val = status_pool[i]
            d = dates_pool[i]
            partner = partners_data[i % 3]
            
            plan = plan1 if i % 2 == 0 else plan2
            
            sub = Subscription(
                id=uuid.uuid4(),
                customer_id=c.id,
                plan_id=plan.id,
                address_id=a.id,
                status=SubscriptionStatus.ACTIVE if sub_status != "cancelled" else SubscriptionStatus.CANCELLED,
                delivery_partner_id=partner.id,
                total_deliveries=plan.total_deliveries,
                total_amount=899.0 if plan == plan1 else 2499.0,
                preferred_delivery_time="Evening (5 PM - 7 PM)",
                created_at=datetime.combine(d, datetime.min.time()).replace(tzinfo=timezone.utc)
            )
            db.add(sub)
            
            # Sub delivery status
            sd_status = DeliveryStatus.PENDING
            if sub_status == "assigned": sd_status = DeliveryStatus.ASSIGNED
            if sub_status == "out_for_delivery": sd_status = DeliveryStatus.OUT_FOR_DELIVERY
            if sub_status == "delivered": sd_status = DeliveryStatus.DELIVERED
            if sub_status == "failed": sd_status = DeliveryStatus.MISSED
            if sub_status == "cancelled": sd_status = DeliveryStatus.SKIPPED
            
            sd = SubscriptionDelivery(
                id=uuid.uuid4(),
                subscription_id=sub.id,
                scheduled_date=d,
                status=sd_status,
                created_at=datetime.combine(d, datetime.min.time()).replace(tzinfo=timezone.utc)
            )
            db.add(sd)
            
            if sub_status != "pending":
                assign = DeliveryAssignment(
                    id=uuid.uuid4(),
                    subscription_delivery_id=sd.id,
                    delivery_partner_id=partner.id,
                    status=AssignmentStatus.ACCEPTED if sub_status == "assigned" else 
                           AssignmentStatus.OUT_FOR_DELIVERY if sub_status == "out_for_delivery" else
                           AssignmentStatus.DELIVERED if sub_status == "delivered" else
                           AssignmentStatus.FAILED if sub_status == "failed" else AssignmentStatus.REJECTED,
                    assigned_at=datetime.combine(d, datetime.min.time()).replace(tzinfo=timezone.utc),
                    created_at=datetime.combine(d, datetime.min.time()).replace(tzinfo=timezone.utc)
                )
                db.add(assign)

        await db.commit()
        print("Demo data successfully created!")

if __name__ == "__main__":
    asyncio.run(seed())
