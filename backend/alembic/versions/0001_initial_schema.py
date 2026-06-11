"""Initial schema — all tables

Revision ID: 0001
Revises: 
Create Date: 2026-06-08
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── ENUMS ────────────────────────────────────────────────────────────────
    op.execute("CREATE TYPE user_status_enum AS ENUM ('active', 'inactive', 'suspended')")
    op.execute("CREATE TYPE address_type_enum AS ENUM ('home', 'work', 'other')")
    op.execute("CREATE TYPE vehicle_type_enum AS ENUM ('bicycle', 'motorcycle', 'car', 'van')")
    op.execute("CREATE TYPE plan_type_enum AS ENUM ('weekly', 'monthly')")
    op.execute("CREATE TYPE subscription_status_enum AS ENUM ('active','paused','completed','cancelled','pending_payment')")
    op.execute("CREATE TYPE delivery_status_enum AS ENUM ('pending','assigned','out_for_delivery','delivered','missed','skipped','carry_forward')")
    op.execute("CREATE TYPE assignment_status_enum AS ENUM ('pending','accepted','rejected','out_for_delivery','delivered','failed')")
    op.execute("CREATE TYPE payment_status_enum AS ENUM ('pending','initiated','success','failed','refunded','partially_refunded')")
    op.execute("CREATE TYPE payment_method_enum AS ENUM ('razorpay','upi','card','netbanking','wallet','cash')")
    op.execute("CREATE TYPE notification_channel_enum AS ENUM ('sms','email','push')")
    op.execute("CREATE TYPE notification_status_enum AS ENUM ('pending','sent','failed')")
    op.execute("CREATE TYPE otp_purpose_enum AS ENUM ('login','register','reset_password','verify_phone')")

    # ── USERS ────────────────────────────────────────────────────────────────
    op.create_table("users",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("phone", sa.String(15), nullable=False),
        sa.Column("email", sa.String(255), nullable=True),
        sa.Column("full_name", sa.String(255), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=True),
        sa.Column("status", postgresql.ENUM("active","inactive","suspended", name="user_status_enum", create_type=False), nullable=False, server_default="active"),
        sa.Column("is_verified", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("profile_photo_url", sa.String(500), nullable=True),
        sa.Column("fcm_token", sa.String(500), nullable=True),
        sa.Column("last_login_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_users_phone", "users", ["phone"], unique=True)
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    # ── ROLES ────────────────────────────────────────────────────────────────
    op.create_table("roles",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(50), nullable=False),
        sa.Column("description", sa.String(255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name"),
    )

    # ── USER_ROLES ───────────────────────────────────────────────────────────
    op.create_table("user_roles",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("role_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["role_id"], ["roles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "role_id", name="uq_user_role"),
    )
    op.create_index("ix_user_roles_user_id", "user_roles", ["user_id"])

    # ── CUSTOMERS ────────────────────────────────────────────────────────────
    op.create_table("customers",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("customer_code", sa.String(20), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
        sa.UniqueConstraint("customer_code"),
    )
    op.create_index("ix_customers_user_id", "customers", ["user_id"])

    # ── ADMINS ───────────────────────────────────────────────────────────────
    op.create_table("admins",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("is_super_admin", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("department", sa.String(100), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
    )

    # ── DELIVERY_BOYS ────────────────────────────────────────────────────────
    op.create_table("delivery_boys",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("employee_code", sa.String(20), nullable=False),
        sa.Column("vehicle_type", postgresql.ENUM("bicycle","motorcycle","car","van", name="vehicle_type_enum", create_type=False), nullable=True),
        sa.Column("vehicle_number", sa.String(20), nullable=True),
        sa.Column("license_number", sa.String(50), nullable=True),
        sa.Column("service_zone", sa.String(100), nullable=True),
        sa.Column("is_available", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("current_lat", sa.Numeric(10, 7), nullable=True),
        sa.Column("current_lng", sa.Numeric(10, 7), nullable=True),
        sa.Column("total_deliveries", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("rating", sa.Numeric(3, 2), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
        sa.UniqueConstraint("employee_code"),
    )

    # ── ADDRESSES ────────────────────────────────────────────────────────────
    op.create_table("addresses",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("label", sa.String(100), nullable=True),
        sa.Column("address_type", postgresql.ENUM("home","work","other", name="address_type_enum", create_type=False), nullable=False, server_default="home"),
        sa.Column("address_line1", sa.String(500), nullable=False),
        sa.Column("address_line2", sa.String(500), nullable=True),
        sa.Column("city", sa.String(100), nullable=False),
        sa.Column("state", sa.String(100), nullable=False),
        sa.Column("pincode", sa.String(10), nullable=False),
        sa.Column("landmark", sa.String(255), nullable=True),
        sa.Column("latitude", sa.Numeric(10, 7), nullable=True),
        sa.Column("longitude", sa.Numeric(10, 7), nullable=True),
        sa.Column("is_default", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_addresses_user_id", "addresses", ["user_id"])
    op.create_index("ix_addresses_pincode", "addresses", ["pincode"])

    # ── PRODUCT_CATEGORIES ───────────────────────────────────────────────────
    op.create_table("product_categories",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(150), nullable=False),
        sa.Column("slug", sa.String(200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("image_url", sa.String(500), nullable=True),
        sa.Column("parent_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["parent_id"], ["product_categories.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("slug"),
    )

    # ── PRODUCTS ─────────────────────────────────────────────────────────────
    op.create_table("products",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("category_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("slug", sa.String(300), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("short_description", sa.String(500), nullable=True),
        sa.Column("image_url", sa.String(500), nullable=True),
        sa.Column("unit", sa.String(50), nullable=False),
        sa.Column("unit_size", sa.Numeric(10, 3), nullable=True),
        sa.Column("price_per_unit", sa.Numeric(10, 2), nullable=False),
        sa.Column("mrp", sa.Numeric(10, 2), nullable=True),
        sa.Column("is_available", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["category_id"], ["product_categories.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("slug"),
    )
    op.create_index("ix_products_category_id", "products", ["category_id"])

    # ── SUBSCRIPTION_PLANS ───────────────────────────────────────────────────
    op.create_table("subscription_plans",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("plan_type", postgresql.ENUM("weekly","monthly", name="plan_type_enum", create_type=False), nullable=False),
        sa.Column("total_deliveries", sa.Integer(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )

    # ── SUBSCRIPTIONS ────────────────────────────────────────────────────────
    op.create_table("subscriptions",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("customer_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("plan_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("address_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("status", postgresql.ENUM("active","paused","completed","cancelled","pending_payment", name="subscription_status_enum", create_type=False), nullable=False, server_default="pending_payment"),
        sa.Column("total_deliveries", sa.Integer(), nullable=False),
        sa.Column("completed_deliveries", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("missed_deliveries", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("start_date", sa.Date(), nullable=True),
        sa.Column("expected_end_date", sa.Date(), nullable=True),
        sa.Column("actual_end_date", sa.Date(), nullable=True),
        sa.Column("paused_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("pause_reason", sa.String(500), nullable=True),
        sa.Column("total_paused_days", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("price_per_delivery", sa.Numeric(10, 2), nullable=False),
        sa.Column("total_amount", sa.Numeric(10, 2), nullable=False),
        sa.Column("delivery_charge", sa.Numeric(10, 2), nullable=False, server_default="0"),
        sa.Column("tax_amount", sa.Numeric(10, 2), nullable=False, server_default="0"),
        sa.Column("auto_renew", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("preferred_delivery_time", sa.String(50), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["customer_id"], ["customers.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["plan_id"], ["subscription_plans.id"]),
        sa.ForeignKeyConstraint(["product_id"], ["products.id"]),
        sa.ForeignKeyConstraint(["address_id"], ["addresses.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_subscriptions_customer_id", "subscriptions", ["customer_id"])
    op.create_index("ix_subscriptions_status", "subscriptions", ["status"])
    op.create_index("ix_subscriptions_product_id", "subscriptions", ["product_id"])

    # ── SUBSCRIPTION_DELIVERIES ──────────────────────────────────────────────
    op.create_table("subscription_deliveries",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("subscription_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("scheduled_date", sa.Date(), nullable=False),
        sa.Column("status", postgresql.ENUM("pending","assigned","out_for_delivery","delivered","missed","skipped","carry_forward", name="delivery_status_enum", create_type=False), nullable=False, server_default="pending"),
        sa.Column("parent_delivery_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("is_carry_forward", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("delivered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("delivery_proof_url", sa.String(500), nullable=True),
        sa.Column("customer_rating", sa.SmallInteger(), nullable=True),
        sa.Column("customer_feedback", sa.Text(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["subscription_id"], ["subscriptions.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["parent_delivery_id"], ["subscription_deliveries.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_sub_deliveries_subscription_id", "subscription_deliveries", ["subscription_id"])
    op.create_index("ix_sub_deliveries_scheduled_date", "subscription_deliveries", ["scheduled_date"])
    op.create_index("ix_sub_deliveries_status", "subscription_deliveries", ["status"])

    # ── DELIVERY_ASSIGNMENTS ─────────────────────────────────────────────────
    op.create_table("delivery_assignments",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("delivery_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("delivery_boy_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("status", postgresql.ENUM("pending","accepted","rejected","out_for_delivery","delivered","failed", name="assignment_status_enum", create_type=False), nullable=False, server_default="pending"),
        sa.Column("assigned_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("accepted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("out_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("delivered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("failed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("failure_reason", sa.Text(), nullable=True),
        sa.Column("distance_km", sa.Numeric(8, 3), nullable=True),
        sa.Column("estimated_minutes", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["delivery_id"], ["subscription_deliveries.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["delivery_boy_id"], ["delivery_boys.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("delivery_id"),
    )
    op.create_index("ix_assignments_delivery_boy_id", "delivery_assignments", ["delivery_boy_id"])

    # ── PAYMENTS ─────────────────────────────────────────────────────────────
    op.create_table("payments",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("subscription_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("customer_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("gateway_order_id", sa.String(200), nullable=True),
        sa.Column("gateway_payment_id", sa.String(200), nullable=True),
        sa.Column("gateway_signature", sa.String(500), nullable=True),
        sa.Column("amount", sa.Numeric(10, 2), nullable=False),
        sa.Column("currency", sa.String(10), nullable=False, server_default="INR"),
        sa.Column("status", postgresql.ENUM("pending","initiated","success","failed","refunded","partially_refunded", name="payment_status_enum", create_type=False), nullable=False, server_default="pending"),
        sa.Column("payment_method", postgresql.ENUM("razorpay","upi","card","netbanking","wallet","cash", name="payment_method_enum", create_type=False), nullable=True),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("failure_reason", sa.Text(), nullable=True),
        sa.Column("refund_amount", sa.Numeric(10, 2), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["subscription_id"], ["subscriptions.id"]),
        sa.ForeignKeyConstraint(["customer_id"], ["customers.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_payments_subscription_id", "payments", ["subscription_id"])
    op.create_index("ix_payments_gateway_payment_id", "payments", ["gateway_payment_id"])

    # ── INVOICES ─────────────────────────────────────────────────────────────
    op.create_table("invoices",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("payment_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("invoice_number", sa.String(50), nullable=False),
        sa.Column("customer_name", sa.String(255), nullable=False),
        sa.Column("customer_phone", sa.String(15), nullable=False),
        sa.Column("customer_email", sa.String(255), nullable=True),
        sa.Column("billing_address", sa.Text(), nullable=False),
        sa.Column("product_name", sa.String(255), nullable=False),
        sa.Column("plan_name", sa.String(100), nullable=False),
        sa.Column("total_deliveries", sa.Integer(), nullable=False),
        sa.Column("price_per_delivery", sa.Numeric(10, 2), nullable=False),
        sa.Column("subtotal", sa.Numeric(10, 2), nullable=False),
        sa.Column("delivery_charge", sa.Numeric(10, 2), nullable=False, server_default="0"),
        sa.Column("tax_percentage", sa.Numeric(5, 2), nullable=False, server_default="0"),
        sa.Column("tax_amount", sa.Numeric(10, 2), nullable=False, server_default="0"),
        sa.Column("total_amount", sa.Numeric(10, 2), nullable=False),
        sa.Column("currency", sa.String(10), nullable=False, server_default="INR"),
        sa.Column("pdf_url", sa.String(500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["payment_id"], ["payments.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("payment_id"),
        sa.UniqueConstraint("invoice_number"),
    )

    # ── NOTIFICATIONS ────────────────────────────────────────────────────────
    op.create_table("notifications",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("channel", postgresql.ENUM("sms","email","push", name="notification_channel_enum", create_type=False), nullable=False),
        sa.Column("event_type", sa.String(100), nullable=False),
        sa.Column("title", sa.String(255), nullable=True),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("status", postgresql.ENUM("pending","sent","failed", name="notification_status_enum", create_type=False), nullable=False, server_default="pending"),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("metadata_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_notifications_user_id", "notifications", ["user_id"])

    # ── OTP_LOGS ─────────────────────────────────────────────────────────────
    op.create_table("otp_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("phone", sa.String(15), nullable=False),
        sa.Column("otp_code", sa.String(10), nullable=False),
        sa.Column("purpose", postgresql.ENUM("login","register","reset_password","verify_phone", name="otp_purpose_enum", create_type=False), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("is_used", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("ip_address", sa.String(50), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_otp_logs_phone", "otp_logs", ["phone"])

    # ── GPS_TRACKING_LOGS ────────────────────────────────────────────────────
    op.create_table("gps_tracking_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("assignment_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("delivery_boy_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("latitude", sa.Numeric(10, 7), nullable=False),
        sa.Column("longitude", sa.Numeric(10, 7), nullable=False),
        sa.Column("accuracy_meters", sa.Numeric(8, 2), nullable=True),
        sa.Column("speed_kmph", sa.Numeric(6, 2), nullable=True),
        sa.Column("heading", sa.Numeric(6, 2), nullable=True),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["assignment_id"], ["delivery_assignments.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["delivery_boy_id"], ["delivery_boys.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_gps_logs_assignment_id", "gps_tracking_logs", ["assignment_id"])
    op.create_index("ix_gps_logs_recorded_at", "gps_tracking_logs", ["recorded_at"])

    # ── AUDIT_LOGS ───────────────────────────────────────────────────────────
    op.create_table("audit_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("action", sa.String(100), nullable=False),
        sa.Column("entity_type", sa.String(100), nullable=False),
        sa.Column("entity_id", sa.String(50), nullable=True),
        sa.Column("old_value", sa.Text(), nullable=True),
        sa.Column("new_value", sa.Text(), nullable=True),
        sa.Column("ip_address", sa.String(50), nullable=True),
        sa.Column("user_agent", sa.String(500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_audit_logs_user_id", "audit_logs", ["user_id"])
    op.create_index("ix_audit_logs_entity_type", "audit_logs", ["entity_type"])
    op.create_index("ix_audit_logs_created_at", "audit_logs", ["created_at"])

    # ── ADMIN_SETTINGS ───────────────────────────────────────────────────────
    op.create_table("admin_settings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("free_delivery_radius_km", sa.Numeric(5, 2), nullable=False, server_default="5.0"),
        sa.Column("delivery_charge_per_km", sa.Numeric(8, 2), nullable=False, server_default="10.0"),
        sa.Column("business_name", sa.String(255), nullable=False, server_default="Healthy Home Foods"),
        sa.Column("business_address", sa.Text(), nullable=True),
        sa.Column("business_lat", sa.Numeric(10, 7), nullable=True),
        sa.Column("business_lng", sa.Numeric(10, 7), nullable=True),
        sa.Column("business_phone", sa.String(15), nullable=True),
        sa.Column("business_email", sa.String(255), nullable=True),
        sa.Column("working_hours_start", sa.Time(), nullable=True),
        sa.Column("working_hours_end", sa.Time(), nullable=True),
        sa.Column("otp_provider", sa.String(50), nullable=False, server_default="msg91"),
        sa.Column("otp_api_key", sa.Text(), nullable=True),
        sa.Column("otp_template_id", sa.String(100), nullable=True),
        sa.Column("otp_sender_id", sa.String(50), nullable=True),
        sa.Column("notification_email", sa.String(255), nullable=True),
        sa.Column("sms_notifications_enabled", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("email_notifications_enabled", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("push_notifications_enabled", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("maps_provider", sa.String(50), nullable=False, server_default="google"),
        sa.Column("maps_api_key", sa.Text(), nullable=True),
        sa.Column("gps_update_interval_seconds", sa.Integer(), nullable=False, server_default="10"),
        sa.Column("payment_gateway", sa.String(50), nullable=False, server_default="razorpay"),
        sa.Column("payment_key_id", sa.Text(), nullable=True),
        sa.Column("payment_key_secret", sa.Text(), nullable=True),
        sa.Column("weekly_deliveries", sa.Integer(), nullable=False, server_default="6"),
        sa.Column("monthly_deliveries", sa.Integer(), nullable=False, server_default="26"),
        sa.Column("max_pause_days_per_subscription", sa.Integer(), nullable=False, server_default="10"),
        sa.Column("allow_carry_forward", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("tax_percentage", sa.Numeric(5, 2), nullable=False, server_default="0.0"),
        sa.Column("service_available", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("maintenance_message", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    # Seed default roles and singleton admin_settings
    op.execute("""
        INSERT INTO roles (id, name, description, created_at, updated_at) VALUES
        (gen_random_uuid(), 'super_admin', 'Full system access', now(), now()),
        (gen_random_uuid(), 'customer', 'Customer account', now(), now()),
        (gen_random_uuid(), 'delivery_boy', 'Delivery personnel', now(), now());
    """)
    op.execute("INSERT INTO admin_settings (id) VALUES (1);")


def downgrade() -> None:
    op.drop_table("admin_settings")
    op.drop_table("audit_logs")
    op.drop_table("gps_tracking_logs")
    op.drop_table("otp_logs")
    op.drop_table("notifications")
    op.drop_table("invoices")
    op.drop_table("payments")
    op.drop_table("delivery_assignments")
    op.drop_table("subscription_deliveries")
    op.drop_table("subscriptions")
    op.drop_table("subscription_plans")
    op.drop_table("products")
    op.drop_table("product_categories")
    op.drop_table("addresses")
    op.drop_table("delivery_boys")
    op.drop_table("admins")
    op.drop_table("customers")
    op.drop_table("user_roles")
    op.drop_table("roles")
    op.drop_table("users")
    for enum in ["user_status_enum","address_type_enum","vehicle_type_enum","plan_type_enum",
                 "subscription_status_enum","delivery_status_enum","assignment_status_enum",
                 "payment_status_enum","payment_method_enum","notification_channel_enum",
                 "notification_status_enum","otp_purpose_enum"]:
        op.execute(f"DROP TYPE IF EXISTS {enum}")
