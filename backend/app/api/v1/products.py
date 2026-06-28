from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
from sqlalchemy.orm import joinedload

from app.db.session import get_db
from app.core.dependencies import get_current_user, require_super_admin
from app.models.user import User
from app.models.product import Product, ProductCategory, ProductStatus, ProductAvailability
from app.schemas.product import (
    ProductCreate, ProductUpdate, ProductResponse, ProductListResponse,
    ProductCategoryCreate, ProductCategoryResponse,
)
from app.schemas.common import MessageResponse
from sqlalchemy.exc import IntegrityError
import os, shutil, uuid as uuid_lib
from app.core.config import settings

router = APIRouter(prefix="/products", tags=["Products"])


# ── Products ──────────────────────────────────────────────────────────────────

@router.get("", response_model=ProductListResponse)
async def list_products(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: str = Query(None),
    category_id: UUID = Query(None),
    status: Optional[ProductStatus] = Query(None),
    availability: Optional[ProductAvailability] = Query(None),
    is_featured: Optional[bool] = Query(None),
    is_today_special: Optional[bool] = Query(None),
    is_popular: Optional[bool] = Query(None),
    active_only: bool = Query(True),
    db: AsyncSession = Depends(get_db),
):
    query = select(Product).options(joinedload(Product.category))
    if active_only:
        query = query.where(Product.is_active == True)
    if status:
        query = query.where(Product.status == status)
    if availability:
        query = query.where(Product.availability == availability)
    if category_id:
        query = query.where(Product.category_id == category_id)
    if is_featured is not None:
        query = query.where(Product.is_featured == is_featured)
    if is_today_special is not None:
        query = query.where(Product.is_today_special == is_today_special)
    if is_popular is not None:
        query = query.where(Product.is_popular == is_popular)
    if search:
        query = query.where(
            or_(Product.name.ilike(f"%{search}%"), Product.description.ilike(f"%{search}%"))
        )

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(query.order_by(Product.display_order, Product.created_at.desc()).offset((page - 1) * page_size).limit(page_size))
    items = result.scalars().all()
    return ProductListResponse(total=total, page=page, page_size=page_size, items=items)


@router.get("/analytics/dashboard")
async def get_product_analytics(
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    total = await db.scalar(select(func.count(Product.id)))
    active = await db.scalar(select(func.count(Product.id)).where(Product.is_active == True))
    inactive = await db.scalar(select(func.count(Product.id)).where(Product.is_active == False))
    return {
        "total_products": total,
        "active_products": active,
        "inactive_products": inactive,
        "most_ordered": [], # This would typically join with subscriptions/deliveries
        "least_ordered": []
    }

@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(product_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Product).options(joinedload(Product.category)).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


from sqlalchemy.exc import IntegrityError

@router.post("", response_model=ProductResponse)
async def create_product(
    payload: ProductCreate,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    product = Product(**payload.model_dump())
    cat_res = await db.execute(select(ProductCategory).where(ProductCategory.id == product.category_id))
    cat = cat_res.scalar_one_or_none()
    if cat:
        product.category_name = cat.name

    db.add(product)
    try:
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(
            status_code=400,
            detail=f"Database constraint violation: Check category or unique constraints. Details: {str(e)}"
        )
    
    res = await db.execute(select(Product).options(joinedload(Product.category)).where(Product.id == product.id))
    return res.scalar_one()



@router.put("/{product_id}", response_model=ProductResponse)
async def update_product(
    product_id: UUID,
    payload: ProductUpdate,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    for k, v in payload.model_dump(exclude_none=True).items():
        setattr(product, k, v)
        
    if payload.category_id:
        cat_res = await db.execute(select(ProductCategory).where(ProductCategory.id == payload.category_id))
        cat = cat_res.scalar_one_or_none()
        if cat:
            product.category_name = cat.name
            
    await db.commit()
    
    res = await db.execute(select(Product).options(joinedload(Product.category)).where(Product.id == product_id))
    return res.scalar_one()


@router.delete("/{product_id}", response_model=MessageResponse)
async def delete_product(
    product_id: UUID,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    product.is_active = False
    await db.commit()
    return MessageResponse(message="Product deactivated successfully")


@router.delete("/{product_id}/hard", response_model=MessageResponse)
async def hard_delete_product(
    product_id: UUID,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    try:
        await db.delete(product)
        await db.commit()
        return MessageResponse(message="Product permanently deleted")
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=400, 
            detail="Cannot delete product because it is associated with active orders or subscriptions. Please deactivate it instead."
        )


@router.post("/{product_id}/restore", response_model=MessageResponse)
async def restore_product(
    product_id: UUID,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    product.is_active = True
    await db.commit()
    return MessageResponse(message="Product restored successfully")




@router.post("/{product_id}/image", response_model=ProductResponse)
async def upload_product_image(
    product_id: UUID,
    file: UploadFile = File(...),
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    """Upload product image — stores in /uploads/products/."""
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in [".jpg", ".jpeg", ".png", ".webp"]:
        raise HTTPException(status_code=400, detail="Invalid image format")

    upload_dir = os.path.join(settings.UPLOAD_DIR, "products")
    os.makedirs(upload_dir, exist_ok=True)
    filename = f"{uuid_lib.uuid4()}{ext}"
    filepath = os.path.join(upload_dir, filename)

    # Delete old image if it exists to overwrite/rewrite it
    if product.image_url:
        old_filename = os.path.basename(product.image_url)
        old_filepath = os.path.join(upload_dir, old_filename)
        if os.path.exists(old_filepath):
            try:
                os.remove(old_filepath)
            except Exception:
                pass

    with open(filepath, "wb") as f:
        shutil.copyfileobj(file.file, f)

    product.image_url = f"/uploads/products/{filename}"
    await db.commit()
    res = await db.execute(select(Product).options(joinedload(Product.category)).where(Product.id == product_id))
    return res.scalar_one()
