"""Test all new delivery partner management endpoints on the new /delivery-partners path"""
import json, urllib.request, urllib.error

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

_, resp = req("POST", f"{BASE}/auth/login", {"mobile_number": "9876543210", "password": "Admin123"})
token = resp["access_token"]
print("Login: OK")

# Test new dedicated endpoint
code, partners = req("GET", f"{BASE}/delivery-partners", token=token)
print(f"\n[GET /delivery-partners] Status: {code}")
if code == 200:
    print(f"  Found {len(partners)} partners")
    if partners:
        p = partners[0]
        pid = p['id']
        print(f"  First: {p['full_name']} | Active: {p['is_active']} | Assigned: {p['assigned_count']}")

        # Get single
        c2, d2 = req("GET", f"{BASE}/delivery-partners/{pid}", token=token)
        print(f"\n[GET /{pid[:8]}...] Status: {c2}")
        if c2 == 200:
            print(f"  Completed: {d2['completed_deliveries']} | Pending: {d2['pending_deliveries']}")

        # Update
        c3, d3 = req("PUT", f"{BASE}/delivery-partners/{pid}", {"full_name": p['full_name'], "age": 27}, token=token)
        print(f"\n[PUT update] {c3} — {d3.get('message')}")

        # Deactivate
        c4, d4 = req("PATCH", f"{BASE}/delivery-partners/{pid}/status", {"is_active": False}, token=token)
        print(f"\n[PATCH deactivate] {c4} — {d4.get('message')}")

        # Reactivate
        c5, d5 = req("PATCH", f"{BASE}/delivery-partners/{pid}/status", {"is_active": True}, token=token)
        print(f"\n[PATCH reactivate] {c5} — {d5.get('message')}")

        # Reset password
        c6, d6 = req("PATCH", f"{BASE}/delivery-partners/{pid}/password", {"new_password": "NewPass123"}, token=token)
        print(f"\n[PATCH password] {c6} — {d6.get('message')}")

        # Search
        c7, d7 = req("GET", f"{BASE}/delivery-partners?search={p['full_name'].split()[0]}", token=token)
        print(f"\n[GET search] {c7} — {len(d7)} results")

        # Filter active
        c8, d8 = req("GET", f"{BASE}/delivery-partners?is_active=true", token=token)
        print(f"\n[GET active filter] {c8} — {len(d8)} active")

        print("\nAll delivery-partners endpoints working!")
    else:
        print("  No partners yet — create one from the app first")
else:
    print(f"  Error: {partners}")
