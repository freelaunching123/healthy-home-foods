from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_

from app.db.session import get_db
from app.core.dependencies import get_current_user, require_super_admin
from app.models.user import User
from app.models.product import Product, ProductCategory
from app.schemas.product import (
    ProductCreate, ProductUpdate, ProductResponse, ProductListResponse,
    ProductCategoryCreate, ProductCategoryResponse,
)
from app.schemas.common import MessageResponse
import os, shutil, uuid as uuid_lib
from app.core.config import settings

router = APIRouter(prefix="/products", tags=["Products"])


# ── Categories ─────────────────────────────────────────────────────────────────

@router.get("/categories", response_model=list[ProductCategoryResponse])
async def list_categories(
    db: AsyncSession = Depends(get_db),
    active_only: bool = Query(True),
):
    query = select(ProductCategory)
    if active_only:
        query = query.where(ProductCategory.is_active == True)
    result = await db.execute(query.order_by(ProductCategory.sort_order))
    return result.scalars().all()


@router.post("/categories", response_model=ProductCategoryResponse)
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


@router.put("/categories/{cat_id}", response_model=ProductCategoryResponse)
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
    return cat


# ── Products ──────────────────────────────────────────────────────────────────

@router.get("/", response_model=ProductListResponse)
async def list_products(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: str = Query(None),
    category_id: UUID = Query(None),
    available_only: bool = Query(True),
    db: AsyncSession = Depends(get_db),
):
    query = select(Product).where(Product.is_active == True)
    if available_only:
        query = query.where(Product.is_available == True)
    if category_id:
        query = query.where(Product.category_id == category_id)
    if search:
        query = query.where(
            or_(Product.name.ilike(f"%{search}%"), Product.description.ilike(f"%{search}%"))
        )

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(query.order_by(Product.sort_order).offset((page - 1) * page_size).limit(page_size))
    items = result.scalars().all()
    return ProductListResponse(total=total, page=page, page_size=page_size, items=items)


@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(product_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


@router.post("/", response_model=ProductResponse)
async def create_product(
    payload: ProductCreate,
    _: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
):
    product = Product(**payload.model_dump())
    db.add(product)
    await db.commit()
    await db.refresh(product)
    return product


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
    await db.commit()
    await db.refresh(product)
    return product


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
    return MessageResponse(message="Product deleted successfully")


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

    with open(filepath, "wb") as f:
        shutil.copyfileobj(file.file, f)

    product.image_url = f"/uploads/products/{filename}"
    await db.commit()
    await db.refresh(product)
    return product
