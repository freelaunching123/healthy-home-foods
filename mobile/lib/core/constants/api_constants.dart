/// API endpoint constants for Healthy Home Foods backend
class ApiConstants {
  ApiConstants._();

  // Base URL — change for production
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1'; // Android localhost (uses adb reverse)
  static const String baseUrlIOS = 'http://localhost:8000/api/v1';
  static const String baseUrlWeb = 'http://127.0.0.1:8000/api/v1';

  // Auth
  static const String register = '/auth/register';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String loginPassword = '/auth/login-password';
  static const String loginAdmin = '/auth/login';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';

  // Products
  static const String products = '/products';
  static const String categories = '/categories';

  // Subscriptions
  static const String subscriptions = '/subscriptions';
  static const String subscriptionPlans = '/subscriptions/plans';

  // Payments
  static const String paymentInitiate = '/payments/initiate';
  static const String paymentVerify = '/payments/verify';
  static const String paymentHistory = '/payments/history';

  // Deliveries
  static const String deliveriesPending = '/deliveries/pending';
  static const String deliveriesAssign = '/deliveries/assign';
  static const String deliveriesAssigned = '/deliveries/assigned';
  static const String gpsUpdate = '/deliveries/gps/update';
  static const String gpsTrack = '/deliveries/gps/track';

  // Delivery Partner App
  static const String partnerDashboard = '/delivery-partner/dashboard';
  static const String partnerActiveDeliveries = '/delivery-partner/active';
  static const String partnerRoute = '/delivery-partner/route';
  static const String partnerHistory = '/delivery-partner/history';
  static const String partnerProfile = '/delivery-partner/profile';
  static const String partnerChangePassword = '/delivery-partner/change-password';
  
  static String partnerUpdateStatus(String assignmentId) => '/delivery-partner/assignments/$assignmentId/status';

  // Users
  static const String users = '/users';
  static const String userProfile = '/users/profile';
  static const String userAddresses = '/users/me/addresses';
  static const String changePassword = '/users/change-password';
  static const String logoutAll = '/users/logout-all';
  static const String subscriptionCurrent = '/subscriptions/current';
  static const String deliveryHistory = '/deliveries/history';

  // Admin
  static const String adminSettings = '/admin/settings';
  static const String adminDashboard = '/reports/dashboard';
  static const String adminOverview = '/reports/admin-overview';
  static const String adminDeliveryPartners = '/admin/delivery-partners';
  static const String adminDeliveries = '/admin/deliveries';
  static const String adminDeliveriesAnalytics = '/admin/deliveries/analytics';
  static const String adminDeliveriesExport = '/admin/deliveries/export';

  // Reports
  static const String reports = '/reports';
  static const String reportsExportPdf = '/reports/export/pdf';
  static const String reportsExportExcel = '/reports/export/excel';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all';

  // Payment Summary
  static const String paymentSummary = '/payments/summary';

  // Fruits (Customer)
  static const String fruits = '/fruits';
  static const String fruitDetail = '/fruits/detail';
  static const String fruitCart = '/fruits/cart';
  static const String fruitCartAdd = '/fruits/cart/add';
  static const String fruitOrdersCheckout = '/fruits/orders/checkout';
  static const String fruitOrdersHistory = '/fruits/orders/history';
  static const String fruitOrders = '/fruits/orders';
  static const String fruitDeliverySlots = '/fruits/delivery-slots';

  // Fruits (Admin)
  static const String adminFruits = '/fruits/admin/fruits';
  static const String adminFruitOrders = '/fruits/admin/orders';

  // Reviews
  static String productReviews(String id) => '/products/$id/reviews';
  static String fruitReviews(String id) => '/fruits/$id/reviews';
  
  // Subscription
  static String cancelSubscription(String id) => '/subscriptions/$id/cancel';
}
