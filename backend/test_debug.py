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

code, body = req("GET", f"{BASE}/users/delivery-partners", token=token)
print(f"Status: {code}")
print(f"Body type: {type(body)}")
print(f"Body: {json.dumps(body, indent=2)}")
