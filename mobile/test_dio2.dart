import 'package:dio/dio.dart';

void main() {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
  
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      print('Dio generated: ${options.uri}');
      handler.reject(DioException(requestOptions: options, message: 'Stop'));
    }
  ));
  
  dio.post('users/delivery-partners').catchError((e) {
    print('Done.');
  });
}
