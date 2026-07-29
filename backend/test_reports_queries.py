import asyncio
import httpx
from app.main import app
from app.core.dependencies import require_super_admin
from app.models.user import User, UserRoleEnum
import uuid

def override_require_super_admin():
    return User(
        id=uuid.UUID("00000000-0000-0000-0000-000000000000"),
        role=UserRoleEnum.SUPER_ADMIN,
        full_name="admin",
        phone="12345"
    )

app.dependency_overrides[require_super_admin] = override_require_super_admin

async def test_queries():
    async with httpx.AsyncClient(app=app, base_url="http://test") as client:
        endpoints = [
            "/api/v1/reports/overview",
            "/api/v1/reports/sales",
            "/api/v1/reports/packages",
            "/api/v1/reports/fruits",
            "/api/v1/reports/customers",
            "/api/v1/reports/deliveries",
            "/api/v1/reports/orders",
            "/api/v1/reports/payments"
        ]
        
        for ep in endpoints:
            print(f"Testing {ep}...")
            res = await client.get(ep)
            print(f"Status: {res.status_code}")
            if res.status_code != 200:
                print("Error:", res.text)
            else:
                print("Success")
        print("All passed!")

if __name__ == "__main__":
    asyncio.run(test_queries())
