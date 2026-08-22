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
    GRC-DDMMYY-00001
    - GRC: Grocery prefix
    - DDMMYY: Date, Month, Year
    - 00001: 5-digit sequential counter
    """
    now = datetime.now(timezone.utc)
    
    from sqlalchemy import text
    try:
        res = await db.execute(text("SELECT nextval('grocery_order_number_seq')"))
        seq = res.scalar()
    except Exception:
        # Fallback if sequence is not yet created
        from app.models.fruit import FruitOrder
        count_res = await db.execute(select(func.count(FruitOrder.id)))
        count = count_res.scalar() or 0
        seq = 1 + count
        
    date_str = now.strftime('%d%m%y')
    return f"GRC-{date_str}-{seq:05d}"


async def generate_delivery_partner_employee_code(db: AsyncSession) -> str:
    """
    Generates a unique Employee ID for a Delivery Partner.
    Format: HHF-DEL-<SEQUENCE>
    Sequence is a 3-digit zero-padded number, starting at 001 (max 999).
    """
    from app.models.delivery_partner import DeliveryPartner
    
    # Get the maximum sequence number currently in use
    max_code_result = await db.execute(
        select(func.max(DeliveryPartner.employee_code))
        .where(DeliveryPartner.employee_code.like("HHF-DEL-%"))
    )
    max_code = max_code_result.scalar()
    
    new_seq = 1
    if max_code:
        try:
            # Extract the sequence number from HHF-DEL-XXX
            seq = int(max_code.split("-")[-1])
            new_seq = seq + 1
        except ValueError:
            new_seq = 1
            
    if new_seq > 999:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=400,
            detail="Maximum delivery partner capacity reached. Please alert admin to raise digit count."
        )
        
    return f"HHF-DEL-{new_seq:03d}"
