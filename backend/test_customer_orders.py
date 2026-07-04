import json
import urllib.request
import urllib.error
import sys
from datetime import datetime, date

BASE = "http://127.0.0.1:8000/api/v1"

def api_request(path, method="GET", data=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    
    url = f"{BASE}{path}"
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            content = r.read()
            if r.headers.get("Content-Type") == "application/json":
                return r.status, json.loads(content.decode())
            return r.status, content
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode())
        except Exception:
            return e.code, e.read()

def main():
    print("=" * 60)
    print("CUSTOMER END-TO-END FLOW (MOCK PAYMENTS)")
    print("=" * 60)

    # 1. Register customer
    phone = "9876543288"
    password = "password123"
    print(f"\n[1] Registering customer (phone: {phone})...")
    code, resp = api_request("/auth/register", method="POST", data={
        "full_name": "E2E Test Customer",
        "mobile_number": phone,
        "password": password
    })
    if code == 200:
        print("✅ Customer registered successfully!")
    elif code == 400 and "already registered" in resp.get("detail", ""):
        print("ℹ️ Customer already registered, proceeding to login...")
    else:
        print(f"❌ Registration failed: {code} -> {resp}")
        sys.exit(1)

    # 2. Login customer
    print("\n[2] Logging in as customer...")
    code, resp = api_request("/auth/login", method="POST", data={
        "mobile_number": phone,
        "password": password,
        "role": "customer"
    })
    if code != 200:
        print(f"❌ Login failed: {code} -> {resp}")
        sys.exit(1)
    
    token = resp["access_token"]
    user_id = resp["user_id"]
    print(f"✅ Logged in successfully! Token obtained.")

    # 3. Add address
    print("\n[3] Setting up delivery address...")
    # List existing addresses first
    code, addrs = api_request("/users/me/addresses", token=token)
    address_id = None
    if code == 200 and addrs:
        address_id = addrs[0]["id"]
        print(f"ℹ️ Found existing address: id={address_id}")
    else:
        code, resp = api_request("/users/me/addresses", method="POST", data={
            "label": "Home",
            "address_type": "home",
            "address_line1": "Flat 302, Green Glen Layout",
            "city": "Madurai",
            "state": "Tamil Nadu",
            "pincode": "625020",
            "latitude": 10.0494454,
            "longitude": 78.1131231,
            "is_default": True
        }, token=token)
        if code == 200:
            address_id = resp["id"]
            print(f"✅ Address added successfully: id={address_id}")
        else:
            print(f"❌ Failed to add address: {code} -> {resp}")
            sys.exit(1)

    # 4. Add Package to Cart
    product_id = "c21b3beb-09a9-4380-9686-f573c4053f6d" # Basic Pack
    print(f"\n[4] Adding package (product_id: {product_id}) to cart...")
    code, resp = api_request("/packages/cart/add", method="POST", data={
        "product_id": product_id,
        "quantity": 1
    }, token=token)
    if code == 200:
        print("✅ Added package to cart!")
    else:
        print(f"❌ Failed to add package to cart: {code} -> {resp}")
        sys.exit(1)

    # 5. Checkout Package (initiates mock payment)
    print("\n[5] Checking out package cart...")
    code, resp = api_request("/packages/orders/checkout", method="POST", data={
        "address_id": address_id
    }, token=token)
    if code != 200:
        print(f"❌ Package checkout failed: {code} -> {resp}")
        sys.exit(1)
    
    order_id = resp["gateway_order_id"]
    total_amount = resp["total_amount"]
    subscription_id = resp.get("gateway_order_id", "").replace("mock_order_", "")
    print(f"✅ Package checkout successful! Amount: {total_amount}, Order ID: {order_id}")

    # 6. Verify Package Payment (activates subscription)
    print("\n[6] Verifying package payment...")
    code, resp = api_request("/packages/orders/verify-payment", method="POST", data={
        "razorpay_order_id": order_id,
        "razorpay_payment_id": f"mock_pay_pkg_{int(datetime.now().timestamp())}",
        "razorpay_signature": "mock_sig"
    }, token=token)
    if code == 200:
        print(f"✅ Package payment verified & subscription activated!")
    else:
        print(f"❌ Package payment verification failed: {code} -> {resp}")
        sys.exit(1)

    # 7. Add Fruit to Cart
    fruit_id = "c27771e3-611b-41b7-917a-95e909617015" # Pappya
    print(f"\n[7] Adding fruit (fruit_id: {fruit_id}) to cart...")
    code, resp = api_request("/fruits/cart/add", method="POST", data={
        "fruit_id": fruit_id,
        "quantity_kg": 2.0
    }, token=token)
    if code == 200:
        print("✅ Added fruit to cart!")
    else:
        print(f"❌ Failed to add fruit to cart: {code} -> {resp}")
        sys.exit(1)

    # 8. Checkout Fruit Order (creates pending order)
    print("\n[8] Checking out fruit cart...")
    today = date.today().strftime("%Y-%m-%d")
    code, resp = api_request("/fruits/orders/checkout", method="POST", data={
        "address_id": address_id,
        "delivery_date": today,
        "delivery_slot": "morning",
        "notes": "Please deliver fresh fruits"
    }, token=token)
    if code not in (200, 201):
        print(f"❌ Fruit checkout failed: {code} -> {resp}")
        sys.exit(1)
    
    fruit_order_id = resp["id"]
    order_number = resp["order_number"]
    total_amount = resp["total_amount"]
    print(f"✅ Fruit order created! Order Number: {order_number}, Amount: {total_amount}")

    # 9. Initiate Fruit Payment
    print(f"\n[9] Initiating payment for fruit order: {fruit_order_id}...")
    code, resp = api_request(f"/fruits/orders/{fruit_order_id}/payment/initiate", method="POST", token=token)
    if code != 200:
        print(f"❌ Failed to initiate fruit payment: {code} -> {resp}")
        sys.exit(1)
    
    gateway_order_id = resp["order_id"]
    print(f"✅ Fruit payment initiated! Gateway Order ID: {gateway_order_id}")

    # 10. Verify Fruit Payment (marks order paid)
    print("\n[10] Verifying fruit payment...")
    code, resp = api_request(f"/fruits/orders/{fruit_order_id}/payment/verify", method="POST", data={
        "razorpay_order_id": gateway_order_id,
        "razorpay_payment_id": f"mock_pay_frt_{int(datetime.now().timestamp())}",
        "razorpay_signature": "mock_sig"
    }, token=token)
    if code == 200:
        print(f"✅ Fruit payment verified & order completed!")
    else:
        print(f"❌ Fruit payment verification failed: {code} -> {resp}")
        sys.exit(1)

    print("\n" + "=" * 60)
    print("CUSTOMER FLOW COMPLETE - PROCEEDING TO ADMIN MODULE VERIFICATION")
    print("=" * 60)

    # 11. Admin Login
    print("\n[11] Logging in as Admin...")
    code, resp = api_request("/auth/login", method="POST", data={
        "mobile_number": "9876543210",
        "password": "Admin123",
        "role": "admin"
    })
    if code != 200:
        print(f"❌ Admin login failed: {code} -> {resp}")
        sys.exit(1)
    
    admin_token = resp["access_token"]
    print("✅ Admin logged in successfully!")

    # 12. Verify package subscription is visible to admin
    print("\n[12] Querying subscriptions in admin module...")
    code, subscriptions = api_request("/subscriptions", token=admin_token)
    if code == 200:
        found_sub = False
        for s in subscriptions:
            if s["id"] == subscription_id or s["customer_name"] == "E2E Test Customer":
                found_sub = True
                print(f"✅ Found created subscription in Admin List!")
                print(f"   ID: {s['id']}")
                print(f"   Customer: {s['customer_name']}")
                print(f"   Status: {s['status']}")
                print(f"   Total Amount: ₹{s['total_amount']}")
                print(f"   Deliveries: {s['completed_deliveries']}/{s['total_deliveries']}")
                break
        if not found_sub:
            print("❌ Subscription NOT found in Admin List!")
            sys.exit(1)
    else:
        print(f"❌ Failed to fetch admin subscriptions: {code} -> {subscriptions}")
        sys.exit(1)

    # 13. Verify fruit order is visible to admin
    print("\n[13] Querying fruit orders in admin module...")
    code, fruit_orders = api_request("/fruits/admin/orders", token=admin_token)
    if code == 200:
        found_order = False
        for o in fruit_orders:
            if o["id"] == fruit_order_id or o["order_number"] == order_number:
                found_order = True
                print(f"✅ Found created fruit order in Admin List!")
                print(f"   ID: {o['id']}")
                print(f"   Order Number: {o['order_number']}")
                print(f"   Customer: {o['customer_name']} ({o['customer_phone']})")
                print(f"   Status: {o['order_status']}")
                print(f"   Payment Status: {o['payment_status']}")
                print(f"   Total Amount: ₹{o['total_amount']}")
                break
        if not found_order:
            print("❌ Fruit order NOT found in Admin List!")
            sys.exit(1)
    else:
        print(f"❌ Failed to fetch admin fruit orders: {code} -> {fruit_orders}")
        sys.exit(1)

    print("\n" + "=" * 60)
    print("VERIFICATION COMPLETE - BOTH ORDERS DISPLAY CORRECTLY IN ADMIN MODULE!")
    print("=" * 60)

if __name__ == "__main__":
    main()
