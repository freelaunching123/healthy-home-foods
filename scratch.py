with open(r'E:\healthy-home-foods-main\backend\app\api\v1\payments.py', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('from app.models.fruit import FruitOrder, FruitPaymentStatus\n', 'from app.models.fruit import FruitOrder, FruitPaymentStatus, FruitOrderItem\n')
content = content.replace('.options(selectinload(FruitOrder.items).selectinload("fruit"))', '.options(selectinload(FruitOrder.items).selectinload(FruitOrderItem.fruit))')

with open(r'E:\healthy-home-foods-main\backend\app\api\v1\payments.py', 'w', encoding='utf-8') as f:
    f.write(content)
