import base64

script = """import sys
from app.db.session import sync_engine
from sqlalchemy.orm import Session
from app.models.user import User, UserRoleEnum, UserStatus
from app.models.admin import Admin
from app.core.security import hash_password

with Session(sync_engine) as session:
    user = session.query(User).filter(User.phone == "9876543210").first()
    if not user:
        user = User(
            phone="9876543210",
            full_name="Super Admin",
            role=UserRoleEnum.SUPER_ADMIN,
            status=UserStatus.ACTIVE,
            is_verified=True,
            password_hash=hash_password("SuperAdmin123!")
        )
        session.add(user)
        session.flush()
        
    admin = session.query(Admin).filter(Admin.user_id == user.id).first()
    if not admin:
        admin = Admin(
            user_id=user.id,
            is_super_admin=True,
            department="Management"
        )
        session.add(admin)
    
    session.commit()
    print("\\n[+] Admin user 9876543210 created successfully.")
"""

print(base64.b64encode(script.encode('utf-8')).decode('utf-8'))
