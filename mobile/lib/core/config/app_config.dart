class AppConfig {
  AppConfig._();

  /// Centralized API base URL of the AWS EC2 server
  static const String baseUrl = 'http://16.171.146.69:1234';

  /// API version path suffix
  static const String apiBaseUrl = '$baseUrl/api/v1';
}
