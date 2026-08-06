import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';
import 'auth_service.dart';
import '../router/app_router.dart';

// Background message handler. Must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  
  // Local Notifications Plugin for Foreground Alerts
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('FCM is bypassed on Web platform');
      return;
    }
    if (_initialized) return;

    try {
      // 1. Initialize Firebase Messaging Background Handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Request Notification Permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('User granted notification permission: ${settings.authorizationStatus}');

      // 3. Initialize Local Notifications for Foreground message display
      await _initLocalNotifications();

      // 4. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received a foreground message: ${message.notification?.title}');
        _showLocalNotification(message);
      });

      // 5. Handle Click/Resume when app is in Background but still running
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from notification click (background): ${message.messageId}');
        _handleNotificationClick(message);
      });

      // 6. Handle Click when app is opened from Terminated state
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App opened from notification click (terminated): ${initialMessage.messageId}');
        // Wait briefly for router/navigation setup to complete
        Future.delayed(const Duration(seconds: 1), () {
          _handleNotificationClick(initialMessage);
        });
      }

      _initialized = true;
      
      // Auto register token if user is already logged in
      await syncTokenToBackend();
    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payloadStr = response.payload;
        if (payloadStr != null && payloadStr.isNotEmpty) {
          // Parse payload query string
          final uri = Uri.parse('http://dummy.com?$payloadStr');
          final data = uri.queryParameters;
          _handleRouting(data);
        }
      },
    );

    // Create high importance Android Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      // Build payload query string
      final queryParams = <String, String>{};
      message.data.forEach((k, v) {
        queryParams[k] = v.toString();
      });
      final payload = Uri(queryParameters: queryParams).query;

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    }
  }

  Future<void> syncTokenToBackend() async {
    if (kIsWeb) return;
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (!isLoggedIn) return;

      String? token = await _messaging.getToken();
      if (token == null) return;
      debugPrint('FCM Token: $token');

      // Send to backend
      final deviceType = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      await _apiClient.post('/notifications/fcm-token', data: {
        'fcm_token': token,
        'device_type': deviceType,
      });
      debugPrint('FCM token synchronized with backend successfully.');
    } catch (e) {
      debugPrint('Error syncing FCM token to backend: $e');
    }
  }

  void _handleNotificationClick(RemoteMessage message) {
    _handleRouting(message.data);
  }

  void _handleRouting(Map<String, dynamic> data) {
    try {
      final actionType = data['action_type']?.toString();
      final referenceId = data['reference_id']?.toString();

      debugPrint('Routing notification: actionType=$actionType, referenceId=$referenceId');

      if (actionType == null) {
        appRouter.go('/notifications');
        return;
      }

      switch (actionType) {
        case 'delivery':
          if (referenceId != null && referenceId.isNotEmpty) {
            _authService.getUserRole().then((role) {
              if (role == 'delivery_partner') {
                appRouter.go('/delivery/order/$referenceId');
              } else {
                appRouter.go('/tracking/$referenceId');
              }
            });
          } else {
            _authService.getUserRole().then((role) {
              if (role == 'delivery_partner') {
                appRouter.go('/delivery');
              } else {
                appRouter.go('/notifications');
              }
            });
          }
          break;

        case 'subscription':
          if (referenceId != null && referenceId.isNotEmpty) {
            appRouter.go('/delivery-calendar/$referenceId');
          } else {
            appRouter.go('/profile/subscription');
          }
          break;

        case 'payment':
          appRouter.go('/payments');
          break;

        case 'promo':
          if (referenceId != null && referenceId.isNotEmpty) {
            appRouter.go('/product/$referenceId');
          } else {
            appRouter.go('/home');
          }
          break;

        case 'fruit_order':
          if (referenceId != null && referenceId.isNotEmpty) {
            appRouter.go('/fruits/orders/$referenceId');
          } else {
            appRouter.go('/fruits/orders');
          }
          break;

        case 'morning_reminder':
          _authService.getUserRole().then((role) {
            if (role == 'delivery_partner') {
              appRouter.go('/delivery/route');
            } else {
              appRouter.go('/home');
            }
          });
          break;

        default:
          appRouter.go('/notifications');
          break;
      }
    } catch (e) {
      debugPrint('Error handling routing for notification click: $e');
    }
  }
}
