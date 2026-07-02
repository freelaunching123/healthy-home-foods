# 🥗 Healthy Home Foods — Full-Stack Delivery Platform

Production-ready food subscription & delivery management system built with FastAPI, PostgreSQL, Redis, and Docker.

---

## 🚀 Quick Start (Local Development)

### Prerequisites
- Docker Desktop
- Python 3.11+ (for local development without Docker)
- Git

### 1. Clone & Configure Environment

```bash
cd HealthyHomeFoods/backend
cp .env.example .env
# Edit .env with your credentials
```

### 2. Start with Docker Compose

```bash
# From project root
docker-compose up --build -d

# Run database migrations
docker-compose exec backend alembic upgrade head

# View logs
docker-compose logs -f backend
```

### 3. Access Services

| Service | URL |
|---------|-----|
| API (Swagger) | http://localhost:8000/docs |
| API (ReDoc) | http://localhost:8000/redoc |
| Health Check | http://localhost:8000/health |
| DB Admin (Adminer) | http://localhost:8080 |

---

## 🏗 Project Structure

```
HealthyHomeFoods/
├── backend/
│   ├── app/
│   │   ├── api/v1/           ← All REST API routers
│   │   │   ├── auth.py       ← OTP + JWT authentication
│   │   │   ├── users.py      ← User management
│   │   │   ├── products.py   ← Product catalog
│   │   │   ├── subscriptions.py ← Subscription lifecycle
│   │   │   ├── deliveries.py ← Delivery + GPS tracking
│   │   │   ├── payments.py   ← Razorpay payments
│   │   │   ├── admin_settings.py ← Business configuration
│   │   │   └── reports.py    ← Analytics & export
│   │   ├── core/
│   │   │   ├── config.py     ← Pydantic settings
│   │   │   ├── security.py   ← JWT + bcrypt + OTP
│   │   │   └── dependencies.py ← RBAC FastAPI dependencies
│   │   ├── db/
│   │   │   ├── base.py       ← SQLAlchemy declarative base
│   │   │   ├── mixins.py     ← UUID PK + timestamp mixins
│   │   │   ├── session.py    ← Async engine + get_db()
│   │   │   └── models_import.py ← Central model imports for Alembic
│   │   ├── models/           ← 20 SQLAlchemy models
│   │   ├── schemas/          ← Pydantic v2 request/response schemas
│   │   ├── services/
│   │   │   └── subscription_engine.py ← Business logic engine
│   │   ├── tasks/            ← Celery async tasks + scheduler
│   │   ├── utils/            ← OTP sender, email, helpers
│   │   └── main.py           ← FastAPI app entry point
│   ├── alembic/              ← Database migrations
│   ├── tests/                ← pytest test suite
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .env.example
├── nginx/
│   └── nginx.conf
├── docker-compose.yml        ← Development
├── docker-compose.prod.yml   ← Production
└── README.md
```

---

## 🔐 Authentication Flow

### Customer (OTP-based)
```
POST /api/v1/auth/send-otp    → Send 6-digit OTP via SMS
POST /api/v1/auth/verify-otp  → Verify OTP → Returns JWT tokens
POST /api/v1/auth/refresh     → Refresh access token
```

### Admin (Email + Password)
```
POST /api/v1/auth/login       → Returns JWT tokens
```

### JWT Usage
```
Authorization: Bearer <access_token>
```

---

## 📦 Subscription Business Rules

| Plan | Deliveries Required |
|------|-------------------|
| Weekly | 6 successful deliveries |
| Monthly | 26 successful deliveries |

- ✅ Only `DELIVERED` status counts toward completion
- ⏸ Paused days generate no deliveries (no count reduction)
- 🔄 Missed deliveries auto carry-forward to next available slot
- ✔ Subscription completes only when `completed == total`
- 🔁 Customers can pause/resume/cancel/renew anytime

---

## 🛡️ Security Features

- 🔒 bcrypt password hashing
- 🎫 JWT access (15 min) + refresh (7 days) tokens
- 📱 OTP: 6-digit, 5-min expiry, max 3 attempts, 1/min rate limit
- 🚦 API rate limiting: 100 req/min (10/min for auth)
- 🛡 Security headers: X-Frame-Options, CSP, XSS protection
- 🔑 RBAC: Super Admin / Customer / Delivery Boy

---

## 🐳 Production Deployment

### 1. Configure Production Environment
```bash
cp backend/.env.example backend/.env.prod
# Fill in production credentials
```

### 2. Deploy with Docker Compose
```bash
docker-compose -f docker-compose.prod.yml up -d --build
docker-compose -f docker-compose.prod.yml exec backend alembic upgrade head
```

### 3. SSL Setup (Let's Encrypt)
```bash
# On your VPS
sudo apt install certbot
certbot certonly --standalone -d yourdomain.com
# Certs at: /etc/letsencrypt/live/yourdomain.com/
```

### 4. Nginx SSL Configuration
```bash
cp nginx/nginx.conf nginx/nginx.prod.conf
# Update server_name and SSL cert paths
```

---

## 🧪 Running Tests

```bash
cd backend
pip install -r requirements.txt

# Run all tests
pytest tests/ -v --cov=app --cov-report=html

# Run specific module
pytest tests/api/test_auth.py -v
```

---

## 📡 API Endpoints Reference

| Module | Base Path | Auth Required |
|--------|-----------|---------------|
| Auth | `/api/v1/auth/` | No |
| Users | `/api/v1/users/` | Yes |
| Products | `/api/v1/products/` | Partial |
| Subscriptions | `/api/v1/subscriptions/` | Yes |
| Deliveries + GPS | `/api/v1/deliveries/` | Yes |
| Payments | `/api/v1/payments/` | Yes |
| Admin Settings | `/api/v1/admin/settings/` | Super Admin |
| Reports | `/api/v1/reports/` | Super Admin |

Full API documentation: **http://localhost:8000/docs**

---

## 🗄 Database Migrations

```bash
# Create new migration
alembic revision --autogenerate -m "description"

# Apply migrations
alembic upgrade head

# Rollback one step
alembic downgrade -1

# View migration history
alembic history
```

---

## ⚙️ Environment Variables

See [`.env.example`](backend/.env.example) for all required variables.

Key variables:
- `SECRET_KEY` — JWT signing key (min 32 chars, keep secret!)
- `DATABASE_URL` — PostgreSQL async connection string
- `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` — Payment gateway
- `MSG91_AUTH_KEY` — SMS OTP provider
- `GOOGLE_MAPS_API_KEY` — Maps + distance calculation
- `FIREBASE_CREDENTIALS_PATH` — FCM push notifications

---

## 📊 Admin Settings (Configurable)

All business rules are configurable from the Admin Panel:

| Setting | Default | Description |
|---------|---------|-------------|
| `free_delivery_radius_km` | 5.0 km | Free delivery zone radius |
| `delivery_charge_per_km` | ₹10/km | Charge beyond free zone |
| `weekly_deliveries` | 6 | Deliveries in weekly plan |
| `monthly_deliveries` | 26 | Deliveries in monthly plan |
| `max_pause_days_per_subscription` | 10 | Max pause days allowed |
| `tax_percentage` | 0% | GST/tax rate |
| `service_available` | true | Toggle service on/off |

---

*Built with ❤️ for Healthy Home Foods*
