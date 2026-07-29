import asyncio
import httpx
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test():
    # Login as admin to get token
    login_res = client.post("/api/v1/auth/login", json={"mobile_number": "9876543210", "password": "Admin123"})
    if login_res.status_code != 200:
        print("Login failed:", login_res.text)
        return
    token = login_res.json()["access_token"] if "access_token" in login_res.json() else login_res.json().get("data", {}).get("access_token")
    headers = {"Authorization": f"Bearer {token}"}
    
    print("Testing package orders...")
    res = client.get("/api/v1/packages/orders/admin/package-orders", headers={"Authorization": f"Bearer {token}"})
    print("Status:", res.status_code)
    print("Response:", res.text[:200])

    r2 = client.get("/api/v1/delivery-partners", headers=headers)
    print("Delivery Partners Response:", r2.status_code)

if __name__ == "__main__":
    test()
