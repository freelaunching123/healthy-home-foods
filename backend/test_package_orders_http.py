import asyncio
import httpx
from app.main import app
from app.core.dependencies import require_super_admin
from app.models.user import User, UserRoleEnum
import uuid
import json

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
        res = await client.get("/api/v1/packages/orders/admin/package-orders")
        print("Status:", res.status_code)
        if res.status_code != 200:
            print(res.text)

if __name__ == "__main__":
    asyncio.run(main())
