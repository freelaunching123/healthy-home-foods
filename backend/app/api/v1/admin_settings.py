from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.core.dependencies import require_super_admin
from app.models.user import User
from app.models.admin_settings import AdminSettings
from app.schemas.common import AdminSettingsUpdate, AdminSettingsResponse

router = APIRouter(prefix="/admin/settings", tags=["Admin Settings"])


@router.get("/", response_model=AdminSettingsResponse)
async def get_settings(
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(AdminSettings).where(AdminSettings.id == 1))
    settings = result.scalar_one_or_none()
    if not settings:
        raise HTTPException(status_code=404, detail="Settings not found")
    return settings


@router.put("/", response_model=AdminSettingsResponse)
async def update_settings(
    payload: AdminSettingsUpdate,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Update any combination of admin settings. Only provided fields are updated."""
    result = await db.execute(select(AdminSettings).where(AdminSettings.id == 1))
    settings = result.scalar_one_or_none()
    if not settings:
        raise HTTPException(status_code=404, detail="Settings not found")

    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(settings, field, value)

    await db.commit()
    await db.refresh(settings)
    return settings
