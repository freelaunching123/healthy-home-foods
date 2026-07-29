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

async def main():
    async with httpx.AsyncClient(app=app, base_url="http://test") as client:
        print("Testing /api/v1/admin/deliveries/")
        res1 = await client.get("/api/v1/admin/deliveries/")
        print(f"Status: {res1.status_code}")
        if res1.status_code == 500:
            print(res1.text)
            
        print("Testing /api/v1/admin/deliveries/analytics")
        res2 = await client.get("/api/v1/admin/deliveries/analytics")
        print(f"Status: {res2.status_code}")
        if res2.status_code == 500:
            print(res2.text)

        print("Testing /api/v1/packages/orders/admin/package-orders")
        res3 = await client.get("/api/v1/packages/orders/admin/package-orders")
        print(f"Status: {res3.status_code}")
        if res3.status_code == 500:
            print(res3.text)

if __name__ == "__main__":
    asyncio.run(main())
