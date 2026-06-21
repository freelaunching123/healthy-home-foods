import json
import urllib.request
import urllib.error
import sys

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

def run_tests():
    print("=" * 60)
    print("RUNNING ADMIN DELIVERIES API TESTS")
    print("=" * 60)

    # 1. Login
    print("\n[1] Logging in as Admin...")
    code, resp = api_request("/auth/login", method="POST", data={"mobile_number": "9876543210", "password": "Admin123"})
    if code != 200:
        print(f"❌ Login failed: {code} -> {resp}")
        sys.exit(1)
    
    token = resp["access_token"]
    print("✅ Admin logged in successfully!")

    # 2. Get Deliveries List (Today)
    print("\n[2] Fetching deliveries for today...")
    code, resp = api_request("/admin/deliveries", token=token)
    if code != 200:
        print(f"❌ Failed to fetch deliveries: {code} -> {resp}")
        sys.exit(1)
    print(f"✅ Fetched deliveries list. Found {len(resp)} deliveries.")
    
    if not resp:
        print("⚠️ No deliveries scheduled for today in DB. Cannot test details/status/assign directly.")
        # We can still test analytics and export
    else:
        first_delivery = resp[0]
        delivery_id = first_delivery["id"]
        partner_id = first_delivery["delivery_partner_id"]
        print(f"Found delivery: id={delivery_id}, partner={partner_id}")

        # 3. Get Delivery Details
        print(f"\n[3] Fetching details for delivery {delivery_id}...")
        code, detail_resp = api_request(f"/admin/deliveries/{delivery_id}", token=token)
        if code != 200:
            print(f"❌ Failed to fetch delivery details: {code} -> {detail_resp}")
            sys.exit(1)
        print("✅ Fetched delivery details successfully!")
        print(f"   Customer: {detail_resp['customer']['full_name']}")
        print(f"   Address: {detail_resp['address']['address_line1']}")
        print(f"   Products: {[p['product_name'] for p in detail_resp['products']]}")
        print(f"   Timeline steps: {[t['stage'] for t in detail_resp['timeline']]}")

        # 4. Test Partner Assignment
        # Let's get active delivery partners
        print("\n[4] Fetching delivery partners...")
        p_code, p_resp = api_request("/delivery-partners", token=token)
        if p_code != 200:
            print(f"❌ Failed to fetch delivery partners: {p_code} -> {p_resp}")
            sys.exit(1)
        
        if p_resp:
            test_partner = p_resp[0]
            print(f"   Assigning delivery to partner: {test_partner['full_name']} (id={test_partner['id']})")
            a_code, a_resp = api_request(
                f"/admin/deliveries/{delivery_id}/assign",
                method="POST",
                data={"delivery_partner_id": test_partner["id"]},
                token=token
            )
            if a_code != 200:
                print(f"❌ Assignment failed: {a_code} -> {a_resp}")
                sys.exit(1)
            print("✅ Delivery assigned successfully!")

            # 5. Test Status Update (Out for delivery)
            print("\n[5] Updating delivery status to 'out_for_delivery'...")
            s_code, s_resp = api_request(
                f"/admin/deliveries/{delivery_id}/status",
                method="PUT",
                data={"status": "out_for_delivery"},
                token=token
            )
            if s_code != 200:
                print(f"❌ Status update failed: {s_code} -> {s_resp}")
                sys.exit(1)
            print("✅ Delivery status updated to 'out_for_delivery' successfully!")
        else:
            print("⚠️ No delivery partners found. Skipping assignment and status tests.")

    # 6. Fetch Analytics
    print("\n[6] Fetching delivery analytics...")
    an_code, an_resp = api_request("/admin/deliveries/analytics", token=token)
    if an_code != 200:
        print(f"❌ Analytics request failed: {an_code} -> {an_resp}")
        sys.exit(1)
    print("✅ Analytics fetched successfully!")
    print(f"   Total scheduled: {an_resp['total_deliveries']}")
    print(f"   Success rate: {an_resp['success_rate']}%")
    print(f"   Average delivery time: {an_resp['average_delivery_time']} mins")
    print(f"   Top partner: {an_resp['top_partner_name']}")

    # 7. CSV and Excel Export
    print("\n[7] Testing CSV and Excel exports...")
    csv_code, csv_data = api_request("/admin/deliveries/export?format=csv", token=token)
    if csv_code != 200:
        print(f"❌ CSV export failed: {csv_code}")
        sys.exit(1)
    print(f"✅ CSV export works! Downloaded {len(csv_data)} bytes.")

    xlsx_code, xlsx_data = api_request("/admin/deliveries/export?format=excel", token=token)
    if xlsx_code != 200:
        print(f"❌ Excel export failed: {xlsx_code}")
        sys.exit(1)
    print(f"✅ Excel export works! Downloaded {len(xlsx_data)} bytes.")

    print("\n" + "=" * 60)
    print("ALL TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)

if __name__ == "__main__":
    run_tests()
