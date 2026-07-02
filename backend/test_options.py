import urllib.request, urllib.error

url = "http://127.0.0.1:8000/api/v1/users/delivery-partners"
req = urllib.request.Request(url, method="OPTIONS")
req.add_header("Origin", "http://localhost:12345")
req.add_header("Access-Control-Request-Method", "POST")

try:
    with urllib.request.urlopen(req) as response:
        print("Success:", response.code)
        print("Headers:", response.headers)
except urllib.error.HTTPError as e:
    print("HTTPError:", e.code)
    print("Headers:", e.headers)
except Exception as e:
    print("Error:", str(e))
