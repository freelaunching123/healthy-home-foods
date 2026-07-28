import logging
import razorpay
from uuid import UUID
from datetime import datetime, timezone
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.config import settings
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
    def _get_razorpay_client():
        if settings.RAZORPAY_KEY_ID and settings.RAZORPAY_KEY_SECRET and settings.RAZORPAY_KEY_ID != "mock":
            return razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))
        return None

    @staticmethod
    async def initiate_payment(db: AsyncSession, customer_id: UUID, subscription_id: UUID, amount: float) -> Payment:
        """Create a payment record and create Razorpay order if key is present."""
        client = PaymentService._get_razorpay_client()
        gateway_order_id = f"mock_order_{subscription_id}"

        if client:
            try:
                rzp_order = client.order.create({
                    "amount": int(round(amount * 100)),
                    "currency": "INR",
                    "receipt": f"sub_{str(subscription_id)[:8]}"
                })
                gateway_order_id = rzp_order["id"]
            except Exception as e:
                logger.error(f"Razorpay order creation failed: {e}")
                raise HTTPException(status_code=500, detail=f"Failed to create Razorpay order: {str(e)}")

        payment = Payment(
            subscription_id=subscription_id,
            customer_id=customer_id,
            gateway_order_id=gateway_order_id,
            amount=amount,
            status=PaymentStatus.INITIATED,
        )
        db.add(payment)
        await db.commit()
        return payment

    # Alias for backwards compatibility
    initiate_mock_payment = initiate_payment

    @staticmethod
    async def verify_payment(db: AsyncSession, gateway_order_id: str, gateway_payment_id: str, gateway_signature: str, user) -> Payment:
        """Verify Razorpay payment signature (or mock fallback) and activate subscription/invoicing."""
        result = await db.execute(
            select(Payment).where(Payment.gateway_order_id == gateway_order_id)
        )
        payment = result.scalar_one_or_none()
        if not payment:
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

        client = PaymentService._get_razorpay_client()
        if client and gateway_signature and gateway_signature != "mock_signature":
            try:
                client.utility.verify_payment_signature({
                    'razorpay_order_id': gateway_order_id,
                    'razorpay_payment_id': gateway_payment_id,
                    'razorpay_signature': gateway_signature
                })
                payment.payment_method = PaymentMethod.RAZORPAY
            except razorpay.errors.SignatureVerificationError:
                logger.error(f"Razorpay signature verification failed for order {gateway_order_id}")
                raise HTTPException(status_code=400, detail="Invalid payment signature")
            except Exception as e:
                logger.error(f"Razorpay verification error: {e}")
                raise HTTPException(status_code=400, detail=f"Payment verification failed: {str(e)}")
        else:
            payment.payment_method = PaymentMethod.MOCK_PAYMENT

        payment.gateway_payment_id = gateway_payment_id
        payment.gateway_signature = gateway_signature or "mock_signature"
        payment.status = PaymentStatus.SUCCESS
        payment.paid_at = datetime.now(timezone.utc)

        # Activate subscription
        sub = await db.get(Subscription, payment.subscription_id)
        if not sub:
            raise HTTPException(status_code=404, detail="Subscription not found")

        await subscription_engine.activate_subscription(db, sub)

        # Generate invoice safely guarding None values
        invoice_number = f"INV-{datetime.now().strftime('%Y%m')}-{str(payment.id)[:8].upper()}"
        del_charge = float(sub.delivery_charge) if sub.delivery_charge is not None else 0.0
        tax_amt = float(sub.tax_amount) if sub.tax_amount is not None else 0.0
        tot_amt = float(sub.total_amount) if sub.total_amount is not None else float(payment.amount or 0.0)
        subtot = tot_amt - del_charge - tax_amt

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
            subtotal=subtot,
            delivery_charge=del_charge,
            tax_percentage=0.0,
            tax_amount=tax_amt,
            total_amount=tot_amt
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

    # Alias for backwards compatibility
    @staticmethod
    async def verify_mock_payment(db: AsyncSession, gateway_order_id: str, gateway_payment_id: str, user, gateway_signature: str = "mock_signature") -> Payment:
        return await PaymentService.verify_payment(db, gateway_order_id, gateway_payment_id, gateway_signature, user)

    @staticmethod
    async def initiate_fruit_payment(db: AsyncSession, order: FruitOrder) -> str:
        """Create Razorpay order for fruit order."""
        client = PaymentService._get_razorpay_client()
        gateway_order_id = f"mock_order_fruit_{order.id}"
        if client:
            try:
                rzp_order = client.order.create({
                    "amount": int(round(float(order.total_amount) * 100)),
                    "currency": "INR",
                    "receipt": f"frt_{str(order.id)[:8]}"
                })
                gateway_order_id = rzp_order["id"]
            except Exception as e:
                logger.error(f"Razorpay fruit order creation failed: {e}")
                raise HTTPException(status_code=500, detail=f"Failed to create Razorpay order: {str(e)}")

        order.gateway_order_id = gateway_order_id
        order.payment_status = FruitPaymentStatus.INITIATED
        await db.commit()
        return gateway_order_id

    @staticmethod
    async def verify_fruit_payment(db: AsyncSession, order_id: UUID, gateway_payment_id: str, gateway_signature: str, user) -> FruitOrder:
        """Verify fruit payment and set order status to PENDING."""
        order = await db.get(FruitOrder, order_id)
        if not order:
            raise HTTPException(status_code=404, detail="Fruit order not found")

        client = PaymentService._get_razorpay_client()
        if client and gateway_signature and gateway_signature != "mock_signature":
            try:
                client.utility.verify_payment_signature({
                    'razorpay_order_id': order.gateway_order_id,
                    'razorpay_payment_id': gateway_payment_id,
                    'razorpay_signature': gateway_signature
                })
            except razorpay.errors.SignatureVerificationError:
                logger.error(f"Razorpay signature verification failed for fruit order {order_id}")
                raise HTTPException(status_code=400, detail="Invalid payment signature")
            except Exception as e:
                logger.error(f"Razorpay verification error: {e}")
                raise HTTPException(status_code=400, detail=f"Payment verification failed: {str(e)}")

        order.gateway_payment_id = gateway_payment_id
        order.gateway_signature = gateway_signature or "mock_signature"
        order.payment_status = FruitPaymentStatus.SUCCESS
        order.paid_at = datetime.now(timezone.utc)
        order.order_status = FruitOrderStatus.PENDING  # Pending Assignment

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

    # Alias for backwards compatibility
    @staticmethod
    async def verify_mock_fruit_payment(db: AsyncSession, order_id: UUID, user, gateway_payment_id: str = "mock_pay", gateway_signature: str = "mock_signature") -> FruitOrder:
        return await PaymentService.verify_fruit_payment(db, order_id, gateway_payment_id, gateway_signature, user)
