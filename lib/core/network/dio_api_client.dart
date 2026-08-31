import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'api_endpoints.dart';
import 'api_file.dart';

class DioApiClient implements ApiClient {
  DioApiClient(this._tokenStore, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
              headers: const {'Accept': 'application/json'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStore.readAccessToken();
          if (token != null &&
              token.isNotEmpty &&
              !_isAuthenticationPath(options.path)) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    if (AppConfig.enableNetworkLogs) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          requestHeader: false,
          responseHeader: false,
        ),
      );
    }
  }

  final TokenStore _tokenStore;
  final Dio _dio;

  bool _isAuthenticationPath(String path) => const {
    ApiEndpoints.clientGoogleLogin,
    ApiEndpoints.clientAppleLogin,
    ApiEndpoints.requestOtp,
    ApiEndpoints.verifyOtp,
    ApiEndpoints.yonkeLogin,
  }.contains(path);

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _request(path, method: 'GET', queryParameters: queryParameters);

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _request(
    path,
    method: 'POST',
    data: data,
    queryParameters: queryParameters,
  );

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _request(
    path,
    method: 'PUT',
    data: data,
    queryParameters: queryParameters,
  );

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _request(
    path,
    method: 'DELETE',
    data: data,
    queryParameters: queryParameters,
  );

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) async {
    final formData = FormData.fromMap(fields ?? const {});
    for (final file in files) {
      formData.files.add(
        MapEntry(
          file.fieldName,
          MultipartFile.fromBytes(file.bytes, filename: file.fileName),
        ),
      );
    }

    return _request(
      path,
      method: method,
      data: formData,
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> _request(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: _withoutNulls(queryParameters),
        options: Options(method: method),
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  Map<String, dynamic>? _withoutNulls(Map<String, dynamic>? values) {
    if (values == null) return null;
    return Map.fromEntries(
      values.entries.where((entry) => entry.value != null),
    );
  }

  ApiException _mapException(DioException error) {
    final responseData = error.response?.data;
    String? serverMessage;
    if (responseData is Map<String, dynamic>) {
      serverMessage = responseData['message'] as String?;
    }

    return ApiException(
      message:
          serverMessage ??
          error.message ??
          'No fue posible conectar con el servidor.',
      statusCode: error.response?.statusCode,
      details: responseData,
    );
  }
}
