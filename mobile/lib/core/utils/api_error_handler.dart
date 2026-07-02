import 'package:dio/dio.dart';

class ApiErrorHandler {
  static String getMessage(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Unable to connect to the server. If testing on a physical phone, ensure it is on the same Wi-Fi network and update the server IP in api_constants.dart, or run: adb reverse tcp:8000 tcp:8000';
      }
      
      if (error.response?.data != null) {
        final data = error.response!.data;
        if (data is Map<String, dynamic> && data.containsKey('detail')) {
          final detail = data['detail'];
          if (detail is String) {
            return detail;
          }
          if (detail is List && detail.isNotEmpty) {
            final firstError = detail.first;
            if (firstError is Map && firstError.containsKey('msg')) {
              return firstError['msg'] as String;
            }
          }
        }
      }
      
      if (error.type == DioExceptionType.badResponse) {
        return 'Server error. Please try again later.';
      }
    }
    
    return 'An unexpected error occurred. Please try again.';
  }
}
