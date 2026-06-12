import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  try {
    final response = await dio.post('http://127.0.0.1:8000/api/v1/users/delivery-partners', data: {});
    print('Success: ${response.statusCode}');
  } on DioException catch (e) {
    print('DioException: ${e.response?.statusCode}');
    print('Response Data: ${e.response?.data}');
  } catch (e) {
    print('Generic Exception: $e');
  }
}
