"""
Healthy Home Foods — FastAPI Application Entry Point
"""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
import os

from app.core.config import settings
import app.db.models_import  # noqa: F401 — registers ALL models so SQLAlchemy can resolve relationships
from app.api.v1 import auth, users, products, subscriptions, deliveries, payments, admin_settings, reports

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown lifecycle."""
    logger.info("🚀 Healthy Home Foods API starting up...")
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    os.makedirs(os.path.join(settings.UPLOAD_DIR, "products"), exist_ok=True)
    os.makedirs(os.path.join(settings.UPLOAD_DIR, "proofs"), exist_ok=True)
    yield
    logger.info("👋 Healthy Home Foods API shutting down...")


# ── Rate Limiter ──────────────────────────────────────────────────────────────
limiter = Limiter(key_func=get_remote_address, default_limits=["100/minute"])

# ── FastAPI App ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="Healthy Home Foods API",
    description="""
## 🥗 Healthy Home Foods — Subscription Delivery Platform

Production-ready REST API for managing food subscriptions, deliveries, GPS tracking, and payments.

### Features
- 🔐 JWT Authentication + OTP Verification
- 📦 Subscription Management (Weekly 6 / Monthly 26 deliveries)
- 🚚 Real-time GPS Delivery Tracking (WebSocket)
- 💳 Razorpay Payment Integration
- 📊 Admin Analytics & Reports (PDF/Excel)
- 👤 Role-Based Access Control (Super Admin / Customer / Delivery Boy)
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

# ── Middleware ─────────────────────────────────────────────────────────────────
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_origin_regex=r"https?://localhost:.*|https?://127.0.0.1:.*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["*"],  # Tighten in production
)


@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    """Add security headers to every response."""
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "geolocation=(self)"
    return response


# ── Global exception handler ──────────────────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "An internal server error occurred", "success": False},
    )


# ── Static files (uploaded images) ───────────────────────────────────────────
# Ensure upload directories exist before mounting
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
os.makedirs(os.path.join(settings.UPLOAD_DIR, "products"), exist_ok=True)
os.makedirs(os.path.join(settings.UPLOAD_DIR, "proofs"), exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")


# ── API Routers ───────────────────────────────────────────────────────────────
PREFIX = settings.API_V1_PREFIX

app.include_router(auth.router,            prefix=PREFIX)
app.include_router(users.router,           prefix=PREFIX)
app.include_router(products.router,        prefix=PREFIX)
app.include_router(subscriptions.router,   prefix=PREFIX)
app.include_router(deliveries.router,      prefix=PREFIX)
app.include_router(payments.router,        prefix=PREFIX)
app.include_router(admin_settings.router,  prefix=PREFIX)
app.include_router(reports.router,         prefix=PREFIX)


# ── Health check ──────────────────────────────────────────────────────────────
@app.get("/health", tags=["Health"], include_in_schema=False)
async def health_check():
    return {"status": "healthy", "service": "Healthy Home Foods API", "version": "1.0.0"}


@app.get("/", tags=["Root"], include_in_schema=False)
async def root():
    return {
        "message": "Welcome to Healthy Home Foods API",
        "docs": "/docs",
        "version": "1.0.0",
    }
