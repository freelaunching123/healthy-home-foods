import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiClient._() {
    String baseUrl = ApiConstants.baseUrl;
    if (!kIsWeb && Platform.isIOS) {
      baseUrl = ApiConstants.baseUrlIOS;
    } else if (kIsWeb) {
      baseUrl = ApiConstants.baseUrlWeb;
    }

    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Request interceptor: inject JWT
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (kDebugMode) {
          debugPrint('→ ${options.method} ${options.uri}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try token refresh
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry original request
            final retryOptions = error.requestOptions;
            final newToken = await _storage.read(key: 'access_token');
            retryOptions.headers['Authorization'] = 'Bearer $newToken';
            try {
              final response = await dio.fetch(retryOptions);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
        handler.next(error);
      },
    ));
  }

  factory ApiClient() {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${dio.options.baseUrl}${ApiConstants.refreshToken}',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        await _storage.write(key: 'access_token', value: response.data['access_token']);
        await _storage.write(key: 'refresh_token', value: response.data['refresh_token']);
        return true;
      }
    } catch (_) {}
    // Clear tokens on failure
    await _storage.deleteAll();
    return false;
  }

  // Convenience methods
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      dio.get('${dio.options.baseUrl}$path', queryParameters: queryParameters);

  Future<Response> post(String path, {dynamic data}) =>
      dio.post('${dio.options.baseUrl}$path', data: data);

  Future<Response> put(String path, {dynamic data}) =>
      dio.put('${dio.options.baseUrl}$path', data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      dio.patch('${dio.options.baseUrl}$path', data: data);

  Future<Response> delete(String path) =>
      dio.delete('${dio.options.baseUrl}$path');

  Future<Response> uploadFile(String path, String filePath, {String fieldName = 'file'}) {
    final formData = FormData.fromMap({
      fieldName: MultipartFile.fromFileSync(filePath),
    });
    return dio.post('${dio.options.baseUrl}$path', data: formData);
  }
}
