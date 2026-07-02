import urllib.request
import json

url = "http://127.0.0.1:8000/api/v1/products/"
try:
    with urllib.request.urlopen(url) as resp:
        print("Status Code:", resp.status)
        data = json.loads(resp.read().decode())
        print("API Response items count:", len(data.get("items", [])))
        print("Response:", json.dumps(data, indent=2)[:1000])
except Exception as e:
    print("Error calling products API:", e)
