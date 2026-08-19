from datetime import date, datetime, timezone
from typing import Optional
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func


def format_subscription_order_id(
    scheduled_date: Optional[date] = None,
    preferred_time: Optional[str] = None,
    delivery_id: Optional[uuid.UUID] = None,
    sequence: Optional[int] = None
) -> str:
    """
    Generates a subscription order ID in the required sequence format:
    SUB-YYYYMMDD-S-SEQUENCE (e.g., SUB-20260819-1-100001)
    - SUB: Subscription prefix
    - YYYYMMDD: Year, Month, Date
    - S: 1 (Morning), 2 (Afternoon), 3 (Evening)
    - SEQUENCE: 5/6-digit sequential number
    """
    d_str = (scheduled_date or date.today()).strftime('%Y%m%d')
    slot_code = "1"
    if preferred_time:
        st = str(preferred_time).lower()
        if "afternoon" in st or "12:" in st or "1:" in st or "2:" in st or "3:" in st or "4:" in st:
            slot_code = "2"
        elif "evening" in st or "5:" in st or "6:" in st or "7:" in st or "8:" in st:
            slot_code = "3"
        elif "morning" in st:
            slot_code = "1"

    if sequence is not None:
        seq_str = f"{sequence}"
    elif delivery_id is not None:
        seq_str = f"{100001 + (abs(hash(str(delivery_id))) % 90000)}"
    else:
        seq_str = "100001"

    return f"SUB-{d_str}-{slot_code}-{seq_str}"


async def format_grocery_order_id(db: AsyncSession, slot: Optional[str] = None) -> str:
    """
    Generates a grocery order ID in the required sequence format:
    GRC-YYYYMMDD-S-SEQUENCE (e.g., GRC-20260819-1-100001)
    - GRC: Grocery prefix
    - YYYYMMDD: Year, Month, Date
    - S: 1 (Morning), 2 (Afternoon), 3 (Evening)
    - SEQUENCE: 6-digit sequential counter starting from 100001
    """
    now = datetime.now(timezone.utc)
    slot_code = "1"
    if slot:
        s = str(slot).lower()
        if "afternoon" in s or "12:" in s or "1:" in s or "2:" in s or "3:" in s or "4:" in s:
            slot_code = "2"
        elif "evening" in s or "5:" in s or "6:" in s or "7:" in s or "8:" in s:
            slot_code = "3"
        elif "morning" in s:
            slot_code = "1"

    from app.models.fruit import FruitOrder
    count_res = await db.execute(select(func.count(FruitOrder.id)))
    count = count_res.scalar() or 0
    seq = 100001 + count
    return f"GRC-{now.strftime('%Y%m%d')}-{slot_code}-{seq}"
