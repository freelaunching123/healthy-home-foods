import logging
from uuid import UUID
from datetime import datetime, timezone
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.payment import Payment, PaymentStatus, PaymentMethod
from app.models.subscription import Subscription, SubscriptionStatus
from app.models.fruit import FruitOrder, FruitOrderStatus, FruitPaymentStatus
from app.models.customer import Customer
from app.models.invoice import Invoice
from app.services import subscription_engine
from app.services.notification_service import NotificationService

logger = logging.getLogger(__name__)

class PaymentService:
    @staticmethod
    async def initiate_mock_payment(db: AsyncSession, customer_id: UUID, subscription_id: UUID, amount: float) -> Payment:
        """Create a mock payment record in INITIATED state."""
        payment = Payment(
            subscription_id=subscription_id,
            customer_id=customer_id,
            gateway_order_id=f"mock_order_{subscription_id}",
            amount=amount,
            status=PaymentStatus.INITIATED,
        )
        db.add(payment)
        await db.commit()
        return payment

    @staticmethod
    async def verify_mock_payment(db: AsyncSession, gateway_order_id: str, gateway_payment_id: str, user) -> Payment:
        """Verify the mock payment and activate subscription/invoicing."""
        # Find payment by order id
        result = await db.execute(
            select(Payment).where(Payment.gateway_order_id == gateway_order_id)
        )
        payment = result.scalar_one_or_none()
        if not payment:
            # Fallback: check if order ID is just subscription ID (as created by some endpoints)
            try:
                sub_id = UUID(gateway_order_id)
                result = await db.execute(
                    select(Payment).where(Payment.subscription_id == sub_id)
                )
                payment = result.scalar_one_or_none()
            except ValueError:
                pass
                
        if not payment:
            raise HTTPException(status_code=404, detail="Payment record not found")

        payment.gateway_payment_id = gateway_payment_id
        payment.gateway_signature = "mock_signature"
        payment.status = PaymentStatus.SUCCESS
        payment.payment_method = PaymentMethod.MOCK_PAYMENT
        payment.paid_at = datetime.now(timezone.utc)

        # Activate subscription
        sub = await db.get(Subscription, payment.subscription_id)
        if not sub:
            raise HTTPException(status_code=404, detail="Subscription not found")

        await subscription_engine.activate_subscription(db, sub)

        # Generate invoice
        invoice_number = f"INV-{datetime.now().strftime('%Y%m')}-{str(payment.id)[:8].upper()}"
        invoice = Invoice(
            payment_id=payment.id,
            invoice_number=invoice_number,
            customer_name=user.full_name or "Customer",
            customer_phone=user.phone,
            customer_email=user.email,
            billing_address="",
            product_name="Multi-package subscription" if not sub.product_id else "Healthy Meal Plan",
            plan_name=f"{sub.plan_type.upper()} Plan" if sub.plan_type else "Subscription Plan",
            total_deliveries=sub.total_deliveries,
            price_per_delivery=0.0 if not sub.product_id or sub.price_per_delivery is None else float(sub.price_per_delivery),
            subtotal=float(sub.total_amount) - float(sub.delivery_charge) - float(sub.tax_amount),
            delivery_charge=float(sub.delivery_charge),
            tax_percentage=0.0,
            tax_amount=float(sub.tax_amount),
            total_amount=float(sub.total_amount)
        )
        db.add(invoice)

        # In-app notifications
        await NotificationService.create_in_app_notification(
            db=db,
            user_id=user.id,
            title="Payment Successful",
            body=f"Your payment of ₹{payment.amount} was successful.",
            category="payment",
            action_type="payment",
            reference_id=str(payment.id)
        )
        await NotificationService.create_in_app_notification(
            db=db,
            user_id=user.id,
            title="Subscription Activated",
            body="Your package subscription has been activated! Deliveries will begin as scheduled.",
            category="subscription",
            action_type="subscription",
            reference_id=str(sub.id)
        )
        
        await db.commit()
        return payment

    @staticmethod
    async def verify_mock_fruit_payment(db: AsyncSession, order_id: UUID, user) -> FruitOrder:
        """Verify mock fruit payment and set order status to PENDING (Pending Assignment)."""
        order = await db.get(FruitOrder, order_id)
        if not order:
            raise HTTPException(status_code=404, detail="Fruit order not found")

        order.gateway_payment_id = f"mock_pay_fruit_{order_id}"
        order.gateway_signature = "mock_signature"
        order.payment_status = FruitPaymentStatus.SUCCESS
        order.paid_at = datetime.now(timezone.utc)
        order.order_status = FruitOrderStatus.PENDING # Pending Assignment

        # Clear the customer's fruit cart
        from app.models.fruit import FruitCart
        from app.models.customer import Customer
        
        cust_res = await db.execute(select(Customer).where(Customer.user_id == user.id))
        customer = cust_res.scalar_one()
        
        cart_result = await db.execute(select(FruitCart).where(FruitCart.customer_id == customer.id))
        for item in cart_result.scalars().all():
            await db.delete(item)

        await db.commit()
        return order
