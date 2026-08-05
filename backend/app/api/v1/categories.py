from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.db.session import get_db
from app.core.dependencies import get_current_user, require_super_admin
from app.models.user import User
from app.models.product import Product, ProductCategory
from app.schemas.product import ProductCategoryCreate, ProductCategoryResponse
from app.schemas.common import MessageResponse

router = APIRouter(prefix="/categories", tags=["Categories"])

@router.get("", response_model=list[ProductCategoryResponse])
async def list_categories(
    active_only: bool = Query(False),
    category_type: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    query = select(ProductCategory)
    if active_only:
        query = query.where(ProductCategory.is_active == True)
    if category_type:
        query = query.where(ProductCategory.category_type == category_type)
    result = await db.execute(query.order_by(ProductCategory.sort_order))
    return result.scalars().all()

@router.get("/active", response_model=list[ProductCategoryResponse])
async def list_active_categories(
    category_type: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    query = select(ProductCategory).where(ProductCategory.is_active == True)
    if category_type:
        query = query.where(ProductCategory.category_type == category_type)
    result = await db.execute(query.order_by(ProductCategory.sort_order))
    return result.scalars().all()


@router.post("", response_model=ProductCategoryResponse)
async def create_category(
    payload: ProductCategoryCreate,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    cat = ProductCategory(**payload.model_dump())
    db.add(cat)
    await db.commit()
    await db.refresh(cat)
    return cat


@router.put("/{cat_id}", response_model=ProductCategoryResponse)
async def update_category(
    cat_id: UUID,
    payload: ProductCategoryCreate,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(ProductCategory).where(ProductCategory.id == cat_id))
    cat = result.scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    for k, v in payload.model_dump(exclude_none=True).items():
        setattr(cat, k, v)
    await db.commit()
    await db.refresh(cat)
    
    # Also update products linked to this category to keep category_name in sync
    if hasattr(payload, 'name') and payload.name != cat.name:
        await db.execute(
            Product.__table__.update()
            .where(Product.category_id == cat_id)
            .values(category_name=payload.name)
        )
        await db.commit()

    return cat


@router.delete("/{cat_id}", response_model=MessageResponse)
async def delete_category(
    cat_id: UUID,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(ProductCategory).where(ProductCategory.id == cat_id))
    cat = result.scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    
    # Check if any products exist under this category
    product_check = await db.execute(select(func.count(Product.id)).where(Product.category_id == cat_id))
    if product_check.scalar_one() > 0:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete category because it contains products. Please delete or move the products first."
        )
        
    await db.delete(cat)
    await db.commit()
    return MessageResponse(message="Category deleted successfully")
