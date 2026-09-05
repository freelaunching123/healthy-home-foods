import requests

url = 'http://34.227.103.251:1234/api/v1/auth/login'
res = requests.post(url, json={'mobile_number': '9876543210', 'password': 'Admin123'})
if res.status_code != 200:
    print('Login failed:', res.status_code, res.text)
    exit(1)

token = res.json()['access_token']
fruits_url = 'http://34.227.103.251:1234/api/v1/fruits/admin/fruits'
res2 = requests.get(fruits_url, headers={'Authorization': f'Bearer {token}'})
print('Fruits:', res2.status_code, res2.text[:200])
