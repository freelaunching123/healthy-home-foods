import logging

logger = logging.getLogger(__name__)

class NotificationService:
    """
    Mock service for sending Push Notifications (FCM) and SMS (MSG91).
    Once real API keys are added, the HTTP requests can be implemented here.
    """

    @staticmethod
    async def send_push_notification(user_id: str, title: str, body: str, data: dict = None):
        """Mock FCM Push Notification"""
        # In real implementation:
        # 1. Fetch user's FCM token from DB (add fcm_token field to User model if not exists)
        # 2. Send request to Firebase Admin SDK or FCM HTTP v1 API
        logger.info(f"========== PUSH NOTIFICATION (FCM) ==========")
        logger.info(f"To User ID: {user_id}")
        logger.info(f"Title: {title}")
        logger.info(f"Body: {body}")
        logger.info(f"Data: {data}")
        logger.info(f"=============================================")
        return True

    @staticmethod
    async def send_sms(phone_number: str, message: str):
        """Mock MSG91 SMS Notification"""
        # In real implementation:
        # 1. Prepare MSG91 payload
        # 2. Send HTTP POST to MSG91 API
        logger.info(f"========== SMS NOTIFICATION (MSG91) =========")
        logger.info(f"To Phone: {phone_number}")
        logger.info(f"Message: {message}")
        logger.info(f"=============================================")
        return True

    @staticmethod
    async def send_otp(phone_number: str, otp: str):
        """Mock OTP SMS"""
        message = f"Your Healthy Home Foods verification code is {otp}. Do not share this with anyone."
        return await NotificationService.send_sms(phone_number, message)
