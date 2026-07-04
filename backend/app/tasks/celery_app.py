from celery import Celery
from celery.schedules import crontab
from app.core.config import settings

celery_app = Celery(
    "hhf_worker",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=["app.tasks.delivery_tasks", "app.tasks.notification_tasks"],
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="Asia/Kolkata",
    enable_utc=True,
    beat_schedule={
        # Daily delivery generation — runs at 6:00 AM IST every day
        "daily-delivery-generation": {
            "task": "app.tasks.delivery_tasks.run_daily_delivery_job",
            "schedule": crontab(hour=6, minute=0),
        },
        # Auto-assign pending deliveries — runs every 5 minutes
        "auto-assign-deliveries": {
            "task": "app.tasks.delivery_tasks.run_auto_assignment_job",
            "schedule": crontab(minute="*/5"),
        },
        # Send "out for delivery" notifications — 8:00 AM IST
        "morning-delivery-notifications": {
            "task": "app.tasks.notification_tasks.send_morning_delivery_notifications",
            "schedule": crontab(hour=8, minute=0),
        },
        # Expiry reminder — 9:00 PM IST
        "subscription-expiry-reminders": {
            "task": "app.tasks.notification_tasks.send_expiry_reminders",
            "schedule": crontab(hour=21, minute=0),
        },
        # Delivery partner morning reminder — runs at 7:00 AM IST every day
        "delivery-partner-morning-reminder": {
            "task": "app.tasks.notification_tasks.send_delivery_boy_morning_reminders",
            "schedule": crontab(hour=7, minute=0),
        },
    },
)
