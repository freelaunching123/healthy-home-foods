import asyncio
import app.db.models_import
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.db.session import AsyncSessionLocal
from app.models.customer import Customer
from app.models.product import Product, ProductCategory
from app.models.subscription import SubscriptionPlan, Subscription, SubscriptionItem, SubscriptionStatusHistory, SubscriptionPauseHistory
from app.services import subscription_engine

async def test_sub_flow():
    async with AsyncSessionLocal() as db:
        print("--- Testing Subscription Flow ---")
        
        # 1. Fetch or create a Customer
        cust_res = await db.execute(select(Customer).limit(1))
        customer = cust_res.scalar_one_or_none()
        if not customer:
            print("No customer found in DB to test. Creating one...")
            from app.models.user import User
            from app.core.security import hash_password
            import uuid
            user = User(phone="9999999999", full_name="Test Customer", password_hash=hash_password("Cust@123"))
            db.add(user)
            await db.flush()
            customer = Customer(user_id=user.id, customer_code=f"CUST{uuid.uuid4().hex[:6].upper()}")
            db.add(customer)
            await db.flush()
            
        print(f"Using customer: {customer.customer_code}")

        # 2. Fetch or create Subscription Plan
        plan_res = await db.execute(select(SubscriptionPlan).limit(1))
        plan = plan_res.scalar_one_or_none()
        if not plan:
            print("Creating plan...")
            from app.models.subscription import PlanType
            plan = SubscriptionPlan(name="Weekly Plan", plan_type=PlanType.WEEKLY, total_deliveries=6)
            db.add(plan)
            await db.flush()
            
        print(f"Using plan: {plan.name} ({plan.total_deliveries} deliveries)")

        # 3. Fetch or create two Products
        prod_res = await db.execute(select(Product).limit(2))
        products = prod_res.scalars().all()
        
        if len(products) < 2:
            print("Creating products...")
            cat_res = await db.execute(select(ProductCategory).limit(1))
            cat = cat_res.scalar_one_or_none()
            if not cat:
                cat = ProductCategory(name="Dairy", slug="dairy")
                db.add(cat)
                await db.flush()
            
            p1 = Product(category_id=cat.id, name="Fresh Milk 1L", slug="fresh-milk-1l", price=60.0, is_active=True)
            p2 = Product(category_id=cat.id, name="Whole Wheat Bread", slug="whole-wheat-bread", price=45.0, is_active=True)
            db.add(p1)
            db.add(p2)
            await db.flush()
            products = [p1, p2]

        print(f"Using products: {[p.name for p in products]}")

        # 4. Create Address if not exist
        from app.models.address import Address
        addr_res = await db.execute(select(Address).where(Address.user_id == customer.user_id).limit(1))
        addr = addr_res.scalar_one_or_none()
        if not addr:
            addr = Address(user_id=customer.user_id, label="Home", address_line1="123 Test St", city="Testville", state="TS", pincode="123456")
            db.add(addr)
            await db.flush()

        # 5. Create Subscription containing both products
        items_data = [
            {"product": products[0], "quantity": 2}, # 2 * 60 = 120
            {"product": products[1], "quantity": 1}  # 1 * 45 = 45
        ] # price_per_delivery = 165.0
        
        print("\n--- Step 1: Create Subscription ---")
        sub = await subscription_engine.create_subscription(
            db=db,
            customer=customer,
            plan=plan,
            items_data=items_data,
            address_id=addr.id,
            delivery_charge=10.0,
            tax_amount=5.0,
            notes="Testing multi-product"
        )
        await db.commit()
        print(f"Created Subscription ID: {sub.id}")
        print(f"Price Per Delivery: ₹{sub.price_per_delivery} (Expected: 165)")
        print(f"Total Amount: ₹{sub.total_amount} (Expected: 165*6 + 10 + 5 = 1005)")

        # Verify items saved
        res = await db.execute(
            select(Subscription)
            .where(Subscription.id == sub.id)
            .options(selectinload(Subscription.items).selectinload(SubscriptionItem.product))
        )
        sub_check = res.scalar_one()
        print(f"Verified items saved count: {len(sub_check.items)}")
        for idx, item in enumerate(sub_check.items):
            print(f"  Item {idx+1}: {item.product.name} (Qty: {item.quantity})")

        # 6. Activate Subscription
        print("\n--- Step 2: Activate Subscription ---")
        # We need a payment record to avoid errors during activate
        from app.models.payment import Payment
        payment = Payment(subscription_id=sub.id, customer_id=customer.id, amount=sub.total_amount, status="success")
        db.add(payment)
        await db.flush()
        
        await subscription_engine.activate_subscription(db, sub)
        await db.commit()
        print(f"Subscription status: {sub.status}")

        # Check status history
        hist_res = await db.execute(select(SubscriptionStatusHistory).where(SubscriptionStatusHistory.subscription_id == sub.id))
        histories = hist_res.scalars().all()
        print("Status Audit History Logs:")
        for h in histories:
            print(f"  Old: '{h.old_status}' -> New: '{h.new_status}' (Reason: {h.reason})")

        # 7. Pause Subscription
        print("\n--- Step 3: Pause Subscription ---")
        await subscription_engine.pause_subscription(db, sub, "On vacation")
        await db.commit()
        print(f"Subscription status: {sub.status}")
        
        # Verify pause history
        pause_res = await db.execute(select(SubscriptionPauseHistory).where(SubscriptionPauseHistory.subscription_id == sub.id))
        pauses = pause_res.scalars().all()
        for p in pauses:
            print(f"  Paused At: {p.paused_at} (Reason: {p.pause_reason})")

        # 8. Resume Subscription
        print("\n--- Step 4: Resume Subscription ---")
        await subscription_engine.resume_subscription(db, sub)
        await db.commit()
        print(f"Subscription status: {sub.status}")
        
        # Verify updated pause history
        pause_res = await db.execute(select(SubscriptionPauseHistory).where(SubscriptionPauseHistory.subscription_id == sub.id))
        pauses = pause_res.scalars().all()
        for p in pauses:
            print(f"  Resumed At: {p.resumed_at} (Paused Days count: {p.paused_days})")

        # 9. Renew Subscription
        print("\n--- Step 5: Renew Subscription ---")
        renewed_sub = await subscription_engine.renew_subscription(db, sub)
        await db.commit()
        print(f"Renewed Subscription ID: {renewed_sub.id}")
        print(f"Renewed status: {renewed_sub.status}")
        
        # Clean up
        print("\n--- Cleaning up test records ---")
        await db.delete(payment)
        await db.delete(sub)
        await db.delete(renewed_sub)
        await db.commit()
        print("Cleanup done!")

if __name__ == "__main__":
    asyncio.run(test_sub_flow())
