"""
Final end-to-end test: Admin login + Create Delivery Partner
"""
import asyncio, json, urllib.request, urllib.error, sys

def post(url, data, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=json.dumps(data).encode(), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode())

BASE = "http://127.0.0.1:8000/api/v1"

print("--- Step 1: Admin Login ---")
code, resp = post(f"{BASE}/auth/login", {"mobile_number": "9876543210", "password": "Admin123"})
print(f"Status: {code}")
print(f"Response: {resp}")

if code != 200:
    print("LOGIN FAILED. Check credentials or restart uvicorn after changing .env")
    sys.exit(1)

token = resp["access_token"]
print(f"\nRole returned: {resp['role']}")
print(f"Token obtained: YES")

print("\n--- Step 2: Create Delivery Partner ---")
code2, resp2 = post(f"{BASE}/users/delivery-partners", {
    "full_name": "Test Partner",
    "mobile_number": "9111100001",
    "password": "Test@1234",
    "age": 25,
    "gender": "Male"
}, token=token)
print(f"Status: {code2}")
print(f"Response: {resp2}")

if code2 == 200:
    print("\nSUCCESS! Full flow works correctly.")
else:
    print("\nFAILED at delivery partner creation.")
