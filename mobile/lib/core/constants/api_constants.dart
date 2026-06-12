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
  static const String categories = '/products/categories';

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

  // Users
  static const String users = '/users';
  static const String userProfile = '/users/profile';
  static const String userAddresses = '/users/addresses';

  // Admin
  static const String adminSettings = '/admin/settings';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminDeliveryPartners = '/admin/delivery-partners';

  // Reports
  static const String reports = '/reports';
  static const String reportsExportPdf = '/reports/export/pdf';
  static const String reportsExportExcel = '/reports/export/excel';

  // Notifications
  static const String notifications = '/notifications';
}
