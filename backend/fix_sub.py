import os
import re

files = [
    r'e:\HealthyHomeFoods\backend\app\api\v1\subscriptions.py'
]

for file in files:
    if not os.path.exists(file): continue
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace the query in subscriptions.py
    content = re.sub(
        r'select\(Role\.name\)\.join\(UserRole, UserRole\.role_id == Role\.id\)\.where\(UserRole\.user_id == current_user\.id\)',
        r'select(User.role).where(User.id == current_user.id)',
        content
    )
    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)
print('Done!')
