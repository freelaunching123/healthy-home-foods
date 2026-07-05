import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import '../constants/api_constants.dart';
import 'fcm_service.dart';

class AuthService {
  final ApiClient _api = ApiClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Register new customer
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String mobileNumber,
    required String password,
  }) async {
    final response = await _api.post(ApiConstants.register, data: {
      'full_name': fullName,
      'mobile_number': mobileNumber,
      'password': password,
    });
    return response.data;
  }



  // Login with phone + password
  Future<Map<String, dynamic>> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    final response = await _api.post(ApiConstants.loginAdmin, data: {
      'mobile_number': phone,
      'password': password,
    });
    await _saveTokens(response.data);
    
    // Sync FCM Token
    try {
      final fcmService = FcmService();
      await fcmService.syncTokenToBackend();
    } catch (_) {}

    return response.data;
  }

  // Logout
  Future<void> logout() async {
    try {
      await _api.post(ApiConstants.logout);
    } catch (_) {}
    await _storage.deleteAll();
  }

  // Logout from all devices
  Future<void> logoutAllDevices() async {
    try {
      await _api.post('/users/logout-all');
    } catch (_) {}
    await _storage.deleteAll();
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }

  // Get current user role
  Future<String?> getUserRole() async {
    return await _storage.read(key: 'user_role');
  }

  // Get current user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: 'user_id');
  }

  // Get access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  // Save tokens to secure storage
  Future<void> _saveTokens(Map<String, dynamic> data) async {
    if (data['access_token'] != null) {
      await _storage.write(key: 'access_token', value: data['access_token']);
    }
    if (data['refresh_token'] != null) {
      await _storage.write(key: 'refresh_token', value: data['refresh_token']);
    }
    if (data['user_id'] != null) {
      await _storage.write(key: 'user_id', value: data['user_id']);
    }
    if (data['role'] != null) {
      await _storage.write(key: 'user_role', value: data['role']);
    }
  }
}
