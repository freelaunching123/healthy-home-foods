import logging
import os
from datetime import datetime, timezone
from sqlalchemy import select

logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK
firebase_initialized = False
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    try:
        firebase_admin.get_app()
        firebase_initialized = True
    except ValueError:
        cred_json = os.getenv("FIREBASE_CREDENTIALS_JSON")
        if cred_json:
            try:
                import json
                cred_dict = json.loads(cred_json)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
                firebase_initialized = True
                logger.info("Firebase Admin SDK initialized successfully from env var JSON.")
            except Exception as e:
                logger.error(f"Error initializing Firebase Admin SDK from env var JSON: {e}")

        if not firebase_initialized:
            cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "./firebase-credentials.json")
            if os.path.exists(cred_path):
                try:
                    cred = credentials.Certificate(cred_path)
                    firebase_admin.initialize_app(cred)
                    firebase_initialized = True
                    logger.info("Firebase Admin SDK initialized successfully.")
                except Exception as e:
                    logger.error(f"Error initializing Firebase Admin SDK from file: {e}")
            else:
                logger.warning(f"Firebase credentials not found. Push notifications will run in Mock mode.")
except ImportError:
    logger.info("firebase_admin package not installed, push notifications disabled.")


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

    @staticmethod
    async def create_in_app_notification(
        db,
        user_id,
        title: str,
        body: str,
        category: str = "system",
        action_type: str = "system",
        reference_id: str = None,
    ):
        """Create an in-app notification for a user."""
        try:
            from app.models.notification import Notification, NotificationChannel, NotificationStatus
            
            async with db.begin_nested():
                new_notification = Notification(
                    user_id=user_id,
                    title=title,
                    body=body,
                    channel=NotificationChannel.IN_APP,
                    status=NotificationStatus.SENT,
                    event_type="in_app",
                    category=category,
                    action_type=action_type,
                    reference_id=reference_id,
                    is_read=False,
                    is_deleted=False,
                )
                db.add(new_notification)
                await db.flush()
                return new_notification
        except Exception as e:
            logger.error(f"Error creating in-app notification: {e}")
            return None

    # ── Reusable Production Notification Methods ──────────────────────────────────────────

    @staticmethod
    async def save_notification_history(
        db,
        user_id,
        role: str,
        title: str,
        body: str,
        notification_type: str,
        reference_id: str = None
    ):
        """Saves a notification to the notification_history table."""
        try:
            from app.models.notification_history import NotificationHistory
            
            async with db.begin_nested():
                history = NotificationHistory(
                    user_id=user_id,
                    role=role,
                    title=title,
                    body=body,
                    notification_type=notification_type,
                    reference_id=reference_id,
                    is_read=False
                )
                db.add(history)
                await db.flush()
                return history
        except Exception as e:
            logger.error(f"Error saving notification history: {e}")
            return None

    @staticmethod
    async def update_fcm_token(db, user_id, fcm_token: str, device_type: str = None) -> bool:
        """Updates user's FCM token, device type, and metadata."""
        from app.models.user import User
        
        user = await db.get(User, user_id)
        if user:
            user.fcm_token = fcm_token
            user.device_type = device_type
            user.last_token_update = datetime.now(timezone.utc)
            user.notification_enabled = True
            await db.commit()
            return True
        return False

    @staticmethod
    async def send_push_to_token(fcm_token: str, title: str, body: str, data: dict = None) -> bool:
        """Sends raw FCM message to a specific token."""
        if not fcm_token:
            return False
            
        logger.info(f"========== SENDING FCM PUSH NOTIFICATION ==========")
        logger.info(f"Token: {fcm_token}")
        logger.info(f"Title: {title}")
        logger.info(f"Body: {body}")
        logger.info(f"Data: {data}")
        logger.info(f"====================================================")
        
        if not firebase_initialized:
            logger.warning("Firebase Admin SDK not initialized. Running in mock mode.")
            return True
            
        try:
            # Construct messaging.Message
            # Ensure all data values are strings as required by FCM
            fcm_data = {}
            if data:
                for k, v in data.items():
                    fcm_data[k] = str(v)
            
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=fcm_data,
                token=fcm_token,
            )
            response = messaging.send(message)
            logger.info(f"FCM message sent successfully: {response}")
            return True
        except Exception as e:
            logger.error(f"Error sending FCM message: {e}")
            return False

    @staticmethod
    async def send_notification_to_user(
        db,
        user_id,
        title: str,
        body: str,
        notification_type: str,
        reference_id: str = None,
        data: dict = None
    ) -> bool:
        """Sends a notification to a specific user and logs it in history."""
        from app.models.user import User
        
        user = await db.get(User, user_id)
        if not user or user.is_deleted:
            return False
            
        # 1. Send Push notification if FCM token exists and notifications enabled
        success = False
        if user.fcm_token and user.notification_enabled:
            # Prepare payload for client routing
            payload = data or {}
            payload["action_type"] = notification_type
            if reference_id:
                payload["reference_id"] = str(reference_id)
            success = await NotificationService.send_push_to_token(
                fcm_token=user.fcm_token,
                title=title,
                body=body,
                data=payload
            )
            
        # 2. Save history in database
        role_str = user.role.value if hasattr(user.role, "value") else str(user.role)
        await NotificationService.save_notification_history(
            db=db,
            user_id=user.id,
            role=role_str,
            title=title,
            body=body,
            notification_type=notification_type,
            reference_id=str(reference_id) if reference_id else None
        )
        
        # 3. Create backward-compatible in_app notification in notifications table
        try:
            await NotificationService.create_in_app_notification(
                db=db,
                user_id=user.id,
                title=title,
                body=body,
                category=notification_type,
                action_type=notification_type,
                reference_id=str(reference_id) if reference_id else None
            )
        except Exception as ex:
            logger.error(f"Error creating backward-compatible in-app notification: {ex}")
            
        return success

    @staticmethod
    async def send_notification_to_role(
        db,
        role: str,
        title: str,
        body: str,
        notification_type: str,
        reference_id: str = None,
        data: dict = None
    ) -> bool:
        """Sends notification to all active users belonging to a specific role."""
        from app.models.user import User, UserRoleEnum
        
        target_roles = []
        if role.lower() in ("admin", "super_admin"):
            target_roles = [UserRoleEnum.ADMIN, UserRoleEnum.SUPER_ADMIN]
        elif hasattr(UserRoleEnum, role.upper()):
            target_roles = [getattr(UserRoleEnum, role.upper())]
        else:
            for r in UserRoleEnum:
                if r.value == role.lower():
                    target_roles.append(r)

        if not target_roles:
            return True

        result = await db.execute(
            select(User).where(User.role.in_(target_roles), User.is_deleted == False)
        )
        users = result.scalars().all()
        
        for user in users:
            try:
                await NotificationService.send_notification_to_user(
                    db=db,
                    user_id=user.id,
                    title=title,
                    body=body,
                    notification_type=notification_type,
                    reference_id=reference_id,
                    data=data
                )
            except Exception as ex:
                logger.error(f"Error sending notification to user {user.id}: {ex}")
        return True

    @staticmethod
    async def send_notification_to_all_customers(
        db,
        title: str,
        body: str,
        notification_type: str,
        reference_id: str = None,
        data: dict = None
    ) -> bool:
        """Sends notification to all active customer users."""
        return await NotificationService.send_notification_to_role(
            db=db,
            role="customer",
            title=title,
            body=body,
            notification_type=notification_type,
            reference_id=reference_id,
            data=data
        )

    @staticmethod
    async def send_scheduled_notification(
        db,
        user_id,
        title: str,
        body: str,
        notification_type: str,
        reference_id: str = None,
        eta_seconds: int = 0
    ):
        """Schedules a notification to be sent in the future."""
        try:
            from app.tasks.notification_tasks import send_scheduled_notification_task
            send_scheduled_notification_task.apply_async(
                kwargs={
                    "user_id": str(user_id),
                    "title": title,
                    "body": body,
                    "notification_type": notification_type,
                    "reference_id": str(reference_id) if reference_id else None
                },
                countdown=eta_seconds
            )
            logger.info(f"Scheduled notification task enqueued to run in {eta_seconds} seconds.")
        except Exception as e:
            logger.error(f"Error enqueuing scheduled notification: {e}. Falling back to immediate send.")
            await NotificationService.send_notification_to_user(
                db=db,
                user_id=user_id,
                title=title,
                body=body,
                notification_type=notification_type,
                reference_id=reference_id
            )
