import requests
import json

BASE_URL = 'http://localhost:8000/api/v1'

def test_login(phone, password):
    resp = requests.post(f'{BASE_URL}/auth/login', json={
        'mobile_number': phone,
        'password': password
    })
    return resp

print('Testing Refactored Authentication & RBAC Rules...')
success = True

# 1. Admin logs in
resp = test_login('9876543210', 'Admin123')
if resp.status_code == 200:
    data = resp.json()
    role = data.get('role')
    admin_token = data.get('access_token')
    print(f'[OK] Admin login successful. Detected Role: {role}')
    if role not in ('super_admin', 'admin'):
        print(f'  [FAIL] Expected admin/super_admin role, got {role}')
        success = False
else:
    print(f'  [FAIL] Admin login failed: {resp.status_code} - {resp.text}')
    success = False

# 2. Block registration with Admin's reserved phone number
resp = requests.post(f'{BASE_URL}/auth/register', json={
    'full_name': 'Fake Admin',
    'mobile_number': '9876543210',
    'password': 'Admin@NewPassword123'
})
if resp.status_code == 400:
    print('[OK] Admin phone number registration blocked correctly.')
else:
    print(f'  [FAIL] Expected admin phone registration to fail (400), got {resp.status_code}')
    success = False

import random
test_phone = f"9876{random.randint(100000, 999999)}"

# 3. Block registration with weak password
resp = requests.post(f'{BASE_URL}/auth/register', json={
    'full_name': 'Test Customer',
    'mobile_number': test_phone,
    'password': 'weak'
})
if resp.status_code == 400:
    print('[OK] Weak password registration blocked correctly.')
else:
    print(f'  [FAIL] Expected weak password registration to fail (400), got {resp.status_code}')
    success = False

# 4. Successful registration with strong password
resp = requests.post(f'{BASE_URL}/auth/register', json={
    'full_name': 'Test Customer',
    'mobile_number': test_phone,
    'password': 'Cust@Password123'
})
if resp.status_code == 200:
    print('[OK] Customer registered successfully.')
else:
    print(f'  [FAIL] Expected customer registration to succeed (200), got {resp.status_code} - {resp.text}')
    success = False

# 5. Customer logs in
resp = test_login(test_phone, 'Cust@Password123')
if resp.status_code == 200:
    data = resp.json()
    role = data.get('role')
    customer_token = data.get('access_token')
    print(f'[OK] Customer login successful. Detected Role: {role}')
    if role != 'customer':
        print(f'  [FAIL] Expected customer role, got {role}')
        success = False
else:
    print(f'  [FAIL] Customer login failed: {resp.status_code} - {resp.text}')
    success = False

# 6. Admin tries to access Customer endpoint (Rule 1)
# Fetch fruits cart endpoint (requires customer role)
if resp.status_code == 200:
    headers = {'Authorization': f'Bearer {admin_token}'}
    resp_api = requests.get(f'{BASE_URL}/fruits/cart', headers=headers)
    print(f'Admin accessing Customer API -> Status: {resp_api.status_code}')
    if resp_api.status_code == 403:
         print('[OK] Rule 1 enforced: Admin blocked from Customer Module API.')
    else:
         print(f'  [FAIL] Expected 403 Forbidden for Admin on Customer API, got {resp_api.status_code}')
         success = False

# 7. Customer tries to access Admin endpoint (Rule 2)
# Fetch delivery partners endpoint (requires admin/super_admin role)
if resp.status_code == 200:
    headers = {'Authorization': f'Bearer {customer_token}'}
    resp_api = requests.get(f'{BASE_URL}/delivery-partners', headers=headers)
    print(f'Customer accessing Admin API -> Status: {resp_api.status_code}')
    if resp_api.status_code == 403:
         print('[OK] Rule 2 enforced: Customer blocked from Admin Module API.')
    else:
         print(f'  [FAIL] Expected 403 Forbidden for Customer on Admin API, got {resp_api.status_code}')
         success = False

print('All authentication tests passed!' if success else 'Some tests failed.')
