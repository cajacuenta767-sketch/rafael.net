import 'api_file.dart';

abstract interface class ApiClient {
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters});

  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  });

  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  });

  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  });

  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  });
}
