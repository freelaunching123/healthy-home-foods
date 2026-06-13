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
        return e.code, e.read().decode()

BASE = "http://127.0.0.1:8000/api/v1"
_, resp = req("POST", f"{BASE}/auth/login", {"mobile_number": "9876543210", "password": "Admin123"})
token = resp["access_token"]

_, partners = req("GET", f"{BASE}/delivery-partners", token=token)
pid = partners[0]['id']

c, body = req("GET", f"{BASE}/delivery-partners/{pid}", token=token)
print(f"GET single: {c}\n{body[:500]}")

c2, body2 = req("PATCH", f"{BASE}/delivery-partners/{pid}/status", {"is_active": False}, token=token)
print(f"\nPATCH status: {c2}\n{body2[:500]}")

c3, body3 = req("GET", f"{BASE}/delivery-partners?is_active=true", token=token)
print(f"\nGET filter: {c3}\n{str(body3)[:300]}")
