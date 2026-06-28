import os
import re

files = [
    r'e:\HealthyHomeFoods\backend\app\api\v1\users.py',
    r'e:\HealthyHomeFoods\backend\app\api\v1\subscriptions.py',
    r'e:\HealthyHomeFoods\backend\app\api\v1\delivery_partners.py'
]

for file in files:
    if not os.path.exists(file): continue
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove the imports
    content = re.sub(r'from app\.models\.role import Role, UserRole\n\s*', '', content)
    
    # Replace the query in subscriptions.py
    content = re.sub(
        r'role_query = await db\.execute\(\s*select\(Role\.name\)\.join\(UserRole, UserRole\.role_id == Role\.id\)\.where\(UserRole\.user_id == current_user\.id\)\s*\)',
        'role_query = await db.execute(select(User.role).where(User.id == current_user.id))',
        content
    )
    
    # Replace query in users.py
    content = re.sub(
        r'query\.join\(UserRole, UserRole\.user_id == User\.id\)\s*\.join\(Role, Role\.id == UserRole\.role_id\)\s*\.where\(Role\.name == role\)',
        'query.where(User.role == role)',
        content
    )
    
    # Remove role assigning in delivery_partners.py and users.py
    content = re.sub(
        r'role_result = await db\.execute\(select\(Role\)\.where\(Role\.name == "delivery_partner"\)\)\s*role = role_result\.scalar_one_or_none\(\)\s*if role:\s*db\.add\(UserRole\(user_id=user\.id, role_id=role\.id\)\)',
        '',
        content
    )
    
    content = re.sub(
        r'role_result = await db\.execute\(select\(Role\)\.where\(Role\.name == role_name\)\)\s*role = role_result\.scalar_one_or_none\(\)\s*if role:\s*db\.add\(UserRole\(user_id=user\.id, role_id=role\.id\)\)',
        '',
        content
    )
    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)
print('Done!')
