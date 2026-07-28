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
import logging
from app.core.config import settings

logger = logging.getLogger(__name__)

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
    current_user: User = Depends(require_super_admin),
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
    
    # Send Notifications
    try:
        from app.services.notification_service import NotificationService
        
        # 1. Notify all admins
        try:
            await NotificationService.send_notification_to_role(
                db=db,
                role="admin",
                title="Product Added Successfully",
                body=f"Product '{product.name}' has been successfully added to the catalog.",
                notification_type="system",
                reference_id=str(product.id)
            )
        except Exception as e:
            logger.error(f"Failed to notify admins of new product: {e}")
        
        # 2. Notify all customers
        try:
            body_text = f"{product.name}\n₹{product.package_price}\n{product.plan_type.capitalize()} Plan ({product.package_days} Deliveries)\nTap to view."
            await NotificationService.send_notification_to_all_customers(
                db=db,
                title="New Healthy Pack Available",
                body=body_text,
                notification_type="promo",
                reference_id=str(product.id)
            )
        except Exception as e:
            logger.error(f"Failed to notify customers of new product: {e}")
    except Exception as e:
        logger.error(f"General notification processing error: {e}")
    
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

    # 1. Delete cart items referencing this product
    from app.models.package_cart import PackageCart
    cart_result = await db.execute(select(PackageCart).where(PackageCart.product_id == product_id))
    for cart_item in cart_result.scalars().all():
        await db.delete(cart_item)

    # 2. Delete subscription items referencing this product
    from app.models.subscription import SubscriptionItem, Subscription
    sub_items_res = await db.execute(select(SubscriptionItem).where(SubscriptionItem.product_id == product_id))
    for sub_item in sub_items_res.scalars().all():
        await db.delete(sub_item)

    # 3. Disassociate subscriptions referencing this product (set product_id=None)
    subs_res = await db.execute(select(Subscription).where(Subscription.product_id == product_id))
    for sub in subs_res.scalars().all():
        sub.product_id = None

    # 4. Perform complete delete of product
    await db.delete(product)
    await db.commit()
    return MessageResponse(message="Product permanently deleted")


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


@router.get("/{product_id}/reviews", response_model=__import__('app.schemas.review', fromlist=['ReviewListResponse']).ReviewListResponse)
async def list_product_reviews(
    product_id: UUID,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    from app.models.review import Review, ReviewItemType
    from app.schemas.review import ReviewListResponse, ReviewResponse
    
    query = select(Review).options(joinedload(Review.customer).joinedload(Customer.user)).where(
        Review.item_id == product_id,
        Review.item_type == ReviewItemType.PRODUCT,
        Review.is_visible == True
    )
    
    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()
    
    # Calculate average
    avg_result = await db.execute(select(func.avg(Review.rating)).where(
        Review.item_id == product_id,
        Review.item_type == ReviewItemType.PRODUCT,
        Review.is_visible == True
    ))
    avg = avg_result.scalar() or 0.0
    
    result = await db.execute(query.order_by(Review.created_at.desc()).offset((page - 1) * page_size).limit(page_size))
    items = result.scalars().all()
    
    formatted_items = []
    for item in items:
        formatted_items.append(ReviewResponse(
            id=item.id,
            customer_id=item.customer_id,
            customer_name=item.customer.user.full_name if item.customer and item.customer.user else "Anonymous",
            item_type=item.item_type,
            item_id=item.item_id,
            rating=item.rating,
            review_text=item.review_text,
            created_at=item.created_at
        ))
        
    return ReviewListResponse(total=total, page=page, page_size=page_size, items=formatted_items, average_rating=float(avg))


@router.post("/{product_id}/reviews", response_model=MessageResponse)
async def create_product_review(
    product_id: UUID,
    payload: __import__('app.schemas.review', fromlist=['ReviewCreate']).ReviewCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.models.review import Review, ReviewItemType
    from app.models.subscription import Subscription, SubscriptionStatus, SubscriptionItem
    from app.models.customer import Customer

    # Get customer
    result = await db.execute(select(Customer).where(Customer.user_id == current_user.id))
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=403, detail="Only customers can leave reviews")

    # Verify they have completed a subscription for this product
    sub_query = select(SubscriptionItem).join(Subscription, Subscription.id == SubscriptionItem.subscription_id).where(
        Subscription.customer_id == customer.id,
        SubscriptionItem.product_id == product_id,
        Subscription.status == SubscriptionStatus.COMPLETED
    ).limit(1)
    
    sub_res = await db.execute(sub_query)
    if not sub_res.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="You can only review products you have completely subscribed to")

    # Check for existing review
    existing_res = await db.execute(select(Review).where(
        Review.customer_id == customer.id,
        Review.item_id == product_id,
        Review.item_type == ReviewItemType.PRODUCT
    ))
    if existing_res.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="You have already reviewed this product")

    # Create review
    review = Review(
        customer_id=customer.id,
        item_type=ReviewItemType.PRODUCT,
        item_id=product_id,
        rating=payload.rating,
        review_text=payload.review_text
    )
    db.add(review)
    await db.commit()
    return MessageResponse(message="Review submitted successfully")

