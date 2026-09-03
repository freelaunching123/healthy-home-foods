class AppConfig {
  AppConfig._();

  /// Centralized API base URL of the AWS EC2 server
  static const String baseUrl = 'http://98.93.196.212:1234';

  /// API version path suffix
  static const String apiBaseUrl = '$baseUrl/api/v1';
}
