import asyncio
import logging
from app.tasks.celery_app import celery_app
from app.db.session import AsyncSessionLocal
from app.services.subscription_engine import daily_delivery_generation_job
from app.services.delivery_engine import process_unassigned_deliveries
logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.delivery_tasks.run_daily_delivery_job", bind=True, max_retries=3)
def run_daily_delivery_job(self):
    """
    Celery Beat task — runs every morning at 6 AM IST.
    1. Marks yesterday's undelivered deliveries as MISSED
    2. Generates carry-forward deliveries for missed ones
    3. Creates today's delivery records for all active subscriptions
    """
    async def _run():
        async with AsyncSessionLocal() as db:
            stats = await daily_delivery_generation_job(db)
            logger.info(f"Daily job completed: {stats}")
            return stats

    try:
        return asyncio.run(_run())
    except Exception as exc:
        logger.error(f"Daily delivery job failed: {exc}")
        raise self.retry(exc=exc, countdown=300)  # Retry after 5 minutes

@celery_app.task(name="app.tasks.delivery_tasks.run_auto_assignment_job", bind=True, max_retries=2)
def run_auto_assignment_job(self):
    """
    Celery Beat task — runs periodically (e.g., every 5 minutes) to assign pending deliveries.
    """
    async def _run():
        async with AsyncSessionLocal() as db:
            assigned_count = await process_unassigned_deliveries(db)
            logger.info(f"Auto-assignment job completed: assigned {assigned_count} deliveries.")
            return assigned_count

    try:
        return asyncio.run(_run())
    except Exception as exc:
        logger.error(f"Auto-assignment job failed: {exc}")
        raise self.retry(exc=exc, countdown=60)
