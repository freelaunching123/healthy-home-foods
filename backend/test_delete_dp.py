import json, urllib.request, urllib.error
import time

def req(method, url, data=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token: headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(data).encode() if data else None
    r = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode())

BASE = "http://127.0.0.1:8000/api/v1"

print("1. Logging in as Admin")
_, resp = req("POST", f"{BASE}/auth/login", {"mobile_number": "9876543210", "password": "Admin123"})
token = resp["access_token"]

print("2. Fetching active partners")
code, partners = req("GET", f"{BASE}/delivery-partners", token=token)
if code == 200 and len(partners) > 0:
    pid = partners[0]['id']
    name = partners[0]['full_name']
    print(f"  Target partner to delete: {name} ({pid})")

    print(f"3. Deleting partner {name}")
    c2, r2 = req("DELETE", f"{BASE}/delivery-partners/{pid}", token=token)
    print(f"  Result {c2}: {r2}")

    print("4. Fetching partners again to confirm removal")
    c3, p3 = req("GET", f"{BASE}/delivery-partners", token=token)
    print(f"  Found {len(p3)} partners (was {len(partners)})")
    
    print("5. Attempting to log in as deleted partner")
    c4, r4 = req("POST", f"{BASE}/auth/login", {"mobile_number": partners[0]['mobile_number'], "password": "NewPass123"})
    print(f"  Login Result {c4}: {r4}")
else:
    print("No partners available to test delete.")
