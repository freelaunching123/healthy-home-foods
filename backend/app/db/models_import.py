from app.db.base import Base  # noqa: F401 — import all models so Alembic sees them

from app.models.user import User  # noqa

from app.models.customer import Customer  # noqa
from app.models.admin import Admin  # noqa
from app.models.delivery_partner import DeliveryPartner  # noqa
from app.models.address import Address  # noqa
from app.models.product import Product, ProductCategory  # noqa
from app.models.subscription import SubscriptionPlan, Subscription, SubscriptionItem, SubscriptionPauseHistory, SubscriptionStatusHistory, SubscriptionPaymentHistory  # noqa
from app.models.subscription_delivery import SubscriptionDelivery, SubscriptionDeliveryHistory  # noqa
from app.models.delivery_assignment import DeliveryAssignment, DeliveryAssignmentHistory  # noqa
from app.models.payment import Payment  # noqa
from app.models.invoice import Invoice  # noqa
from app.models.notification import Notification  # noqa
from app.models.otp_log import OtpLog  # noqa
from app.models.gps_tracking import GpsTrackingLog  # noqa
from app.models.audit_log import AuditLog  # noqa
from app.models.admin_settings import AdminSettings  # noqa
from app.models.fruit import Fruit, FruitCart, FruitOrder, FruitOrderItem  # noqa
