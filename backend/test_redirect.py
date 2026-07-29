import asyncio
import httpx
from app.main import app

async def main():
    async with httpx.AsyncClient(app=app, base_url="http://test") as client:
        # without trailing slash
        res = await client.get("/api/v1/admin/deliveries?delivery_partner_id=123e4567-e89b-12d3-a456-426614174000")
        print("Without slash:")
        print(f"Status: {res.status_code}")
        print(f"URL: {res.url}")
        if res.status_code in (307, 308):
            print(f"Redirect location: {res.headers.get('location')}")
        
        # follow redirect manually to see if params are kept
        res2 = await client.get("/api/v1/admin/deliveries/?delivery_partner_id=123e4567-e89b-12d3-a456-426614174000")
        print("\nWith slash:")
        print(f"Status: {res2.status_code}")

if __name__ == "__main__":
    asyncio.run(main())
