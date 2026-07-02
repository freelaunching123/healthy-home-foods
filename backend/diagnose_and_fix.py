







































































"""
Diagnostic + Fix Script for Healthy Home Foods
- Checks what roles and admin users exist in DB
- Seeds missing roles (delivery_partner) and admin user
- Tests the full login flow and token generation
- Tests delivery partner creation with that token
"""
import asyncio
import json
import urllib.request
import urllib.error
from sqlalchemy import select, text
import app.db.models_import  # noqa — MUST be first to register all ORM relationships
from app.db.session import AsyncSessionLocal
from app.models.user import User
from app.models.role import Role, UserRole
from app.core.security import hash_password, verify_password, create_access_token
import logging

logging.basicConfig(level=logging.WARNING)

async def diagnose_and_fix():
    print("=" * 60)
    print("HEALTHY HOME FOODS — DIAGNOSTIC & FIX")
    print("=" * 60)

    async with AsyncSessionLocal() as db:
        # ── 1. Check existing roles ───────────────────────────────
        print("\n[1] Checking roles in database...")
        result = await db.execute(select(Role))
        roles = result.scalars().all()
        role_names = [r.name for r in roles]
        print(f"    Found roles: {role_names}")

        # Fix: ensure all required roles exist
        required_roles = ["super_admin", "customer", "delivery_partner"]
        for rname in required_roles:
            if rname not in role_names:
                db.add(Role(name=rname))
                print(f"    ✅ Created missing role: {rname}")
        await db.commit()

        # Refresh role list
        result = await db.execute(select(Role))
        roles = result.scalars().all()
        role_map = {r.name: r for r in roles}
        print(f"    Roles now: {list(role_map.keys())}")

        # ── 2. Check admin user ───────────────────────────────────
        print("\n[2] Checking admin user (phone: 9876543210)...")
        result = await db.execute(select(User).where(User.phone == "9876543210"))
        admin = result.scalar_one_or_none()

        if not admin:
            print("    ⚠️  Admin user NOT found — creating...")
            admin = User(
                phone="9876543210",
                full_name="Super Admin",
                password_hash=hash_password("Admin@123"),
                is_verified=True,
            )
            db.add(admin)
            await db.flush()

            super_admin_role = role_map.get("super_admin")
            if super_admin_role:
                db.add(UserRole(user_id=admin.id, role_id=super_admin_role.id))
            await db.commit()
            await db.refresh(admin)
            print(f"    ✅ Admin user created: id={admin.id}")
        else:
            print(f"    Found admin: id={admin.id}, name={admin.full_name}, status={admin.status}")
            # Check password
            pwd_ok = verify_password("Admin@123", admin.password_hash) if admin.password_hash else False
            pwd_ok2 = verify_password("Admin123", admin.password_hash) if admin.password_hash else False
            print(f"    Password 'Admin@123' valid: {pwd_ok}")
            print(f"    Password 'Admin123' valid: {pwd_ok2}")
            
            if not pwd_ok and not pwd_ok2:
                # Reset to a known password
                admin.password_hash = hash_password("Admin@123")
                await db.commit()
                print("    ✅ Admin password reset to: Admin@123")

        # ── 3. Check admin role assignment ────────────────────────
        print("\n[3] Checking admin role assignment...")
        result = await db.execute(
            select(Role.name)
            .join(UserRole, UserRole.role_id == Role.id)
            .where(UserRole.user_id == admin.id)
        )
        admin_roles = [r[0] for r in result.fetchall()]
        print(f"    Admin's roles: {admin_roles}")

        if "super_admin" not in admin_roles:
            super_admin_role = role_map.get("super_admin")
            if super_admin_role:
                db.add(UserRole(user_id=admin.id, role_id=super_admin_role.id))
                await db.commit()
                print("    ✅ Assigned super_admin role to admin user")
        else:
            print("    ✅ super_admin role is correctly assigned")

        # ── 4. Generate a valid JWT token ─────────────────────────
        print("\n[4] Generating JWT access token for admin...")
        token_data = {"sub": str(admin.id), "role": "super_admin"}
        access_token = create_access_token(token_data)
        print(f"    ✅ Token generated successfully")
        print(f"\n{'='*60}")
        print("ADMIN LOGIN CREDENTIALS:")
        print(f"  Mobile Number : 9876543210")
        print(f"  Password      : Admin@123")
        print(f"{'='*60}")
        print("\nSWAGGER TEST TOKEN (copy this):")
        print(f"  {access_token}")
        print(f"{'='*60}")

        # ── 5. Test login API endpoint ────────────────────────────
        print("\n[5] Testing login API endpoint...")
        try:
            login_data = json.dumps({"mobile_number": "9876543210", "password": "Admin@123"}).encode()
            req = urllib.request.Request(
                "http://127.0.0.1:8000/api/v1/auth/login",
                data=login_data,
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read().decode())
                print(f"    ✅ Login API SUCCESS!")
                print(f"    Token type: {data.get('token_type')}")
                print(f"    Role: {data.get('role')}")
                live_token = data.get("access_token")
        except urllib.error.HTTPError as e:
            body = e.read().decode()
            print(f"    ❌ Login API failed: {e.code} — {body}")
            live_token = access_token  # fallback to locally generated token

        # ── 6. Test delivery partner creation ─────────────────────
        print("\n[6] Testing delivery partner creation...")
        test_phone = "9999900001"
        # clean up test user if exists
        result = await db.execute(select(User).where(User.phone == test_phone))
        existing = result.scalar_one_or_none()
        if existing:
            await db.execute(text(f"DELETE FROM delivery_partners WHERE user_id = '{existing.id}'"))
            await db.execute(text(f"DELETE FROM user_roles WHERE user_id = '{existing.id}'"))
            await db.delete(existing)
            await db.commit()

        try:
            dp_data = json.dumps({
                "full_name": "Test Partner",
                "mobile_number": test_phone,
                "password": "Test@1234",
                "age": 25,
                "gender": "Male"
            }).encode()
            req2 = urllib.request.Request(
                "http://127.0.0.1:8000/api/v1/users/delivery-partners",
                data=dp_data,
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {live_token}"
                },
                method="POST"
            )
            with urllib.request.urlopen(req2) as resp2:
                result2 = json.loads(resp2.read().decode())
                print(f"    ✅ Delivery partner creation SUCCESS: {result2}")
        except urllib.error.HTTPError as e:
            body = e.read().decode()
            print(f"    ❌ Delivery partner creation failed: {e.code} — {body}")

        print("\n✅ Diagnosis complete!")

asyncio.run(diagnose_and_fix())
