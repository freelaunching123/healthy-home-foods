import json, urllib.request, urllib.error

url = "http://127.0.0.1:8000/api/v1/users/delivery-partners"
data = json.dumps({}).encode("utf-8")
req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")

try:
    with urllib.request.urlopen(req) as response:
        print("Success:", response.read().decode())
except urllib.error.HTTPError as e:
    print("HTTPError:", e.code)
    print("Response:", e.read().decode())
except Exception as e:
    print("Error:", str(e))
