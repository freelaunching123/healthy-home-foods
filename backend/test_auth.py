import requests
import json
import time

BASE_URL = 'http://localhost:8000/api/v1'

def test_login(phone, password, role, expect_status):
    resp = requests.post(f'{BASE_URL}/auth/login', json={
        'mobile_number': phone,
        'password': password,
        'role': role
    })
    try:
        msg = resp.json().get('detail', 'Success')
    except:
        msg = resp.text
    print(f'Login {phone} as {role} -> {resp.status_code}: {msg}')
    if resp.status_code != expect_status:
        print(f'  [FAIL] Expected {expect_status} got {resp.status_code}')
        return False
    return True

print('Testing RBAC Logins...')
success = True

# 1. Admin logs in as admin
success &= test_login('9999999999', 'admin123', 'admin', 200)

# 2. Admin logs in as customer
success &= test_login('9999999999', 'admin123', 'customer', 403)

# 3. Create a dummy customer
resp = requests.post(f'{BASE_URL}/auth/register', json={
    'full_name': 'Test Customer',
    'mobile_number': '9876543210',
    'password': 'password123'
})
if resp.status_code not in (200, 400): # 400 if already exists
    print(f'Failed to register customer: {resp.text}')

# 4. Customer logs in as customer
success &= test_login('9876543210', 'password123', 'customer', 200)

# 5. Customer logs in as admin
success &= test_login('9876543210', 'password123', 'admin', 403)

print('All tests passed!' if success else 'Some tests failed.')
