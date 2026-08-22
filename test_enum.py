import enum

class DeliveryStatus(str, enum.Enum):
    DELIVERED = "delivered"
    SKIPPED = "skipped"

s = "skipped"
print(s in [DeliveryStatus.DELIVERED, DeliveryStatus.SKIPPED])
