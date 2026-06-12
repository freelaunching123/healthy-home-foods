import 'package:dio/dio.dart';

void main() {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:8000/api/v1',
  ));
  
  // Create a request to see what URL gets built
  final req = RequestOptions(path: '/api/v1/users/delivery-partners');
  final resolvedUri = dio.options.baseUrl != null 
    ? Uri.parse(dio.options.baseUrl!).resolve(req.path)
    : Uri.parse(req.path);
    
  print('Resolved URI from Dart standard: $resolvedUri');
  
  // With Dio interceptor:
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      print('Resolved URI from Dio: ${options.uri}');
      handler.reject(DioException(requestOptions: options, message: 'Stop'));
    }
  ));
  
  dio.post('/api/v1/users/delivery-partners').catchError((e) {
    print('Done.');
  });
}
