import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../session/session_events.dart';
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
        onError: (error, handler) async {
          // Un 401 con token enviado significa que la sesión ya no es válida.
          if (error.response?.statusCode == 401 &&
              error.requestOptions.headers.containsKey('Authorization')) {
            await _tokenStore.clear();
            SessionEvents.notifyExpired();
          }
          handler.next(error);
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
      final safeFileName = _safeFileName(file.fileName);
      formData.files.add(
        MapEntry(
          file.fieldName,
          MultipartFile.fromBytes(
            file.bytes,
            filename: safeFileName,
            contentType: _mediaTypeForFileName(safeFileName),
          ),
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

  static DioMediaType _mediaTypeForFileName(String fileName) {
    final clean = fileName.trim().toLowerCase();
    final ext = clean.contains('.') ? clean.split('.').last : 'jpg';
    return switch (ext) {
      'png' => DioMediaType('image', 'png'),
      'webp' => DioMediaType('image', 'webp'),
      'gif' => DioMediaType('image', 'gif'),
      _ => DioMediaType('image', 'jpeg'),
    };
  }

  static String _safeFileName(String fileName) {
    final clean = fileName.trim();
    if (clean.isEmpty) return 'foto.jpg';
    if (!clean.contains('.')) return '$clean.jpg';
    return clean;
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
      // 1. Mensaje directo
      if (responseData['message'] is String &&
          (responseData['message'] as String).trim().isNotEmpty) {
        serverMessage = (responseData['message'] as String).trim();
      }

      // 2. Errores de validación de ASP.NET Core: "errors": {"Campo": ["Error 1"]}
      if (serverMessage == null && responseData['errors'] is Map) {
        final errorsMap = responseData['errors'] as Map;
        final errorList = <String>[];
        for (final entry in errorsMap.entries) {
          final field = entry.key?.toString() ?? '';
          if (entry.value is List) {
            for (final msg in entry.value as List) {
              if (msg != null && msg.toString().trim().isNotEmpty) {
                errorList.add('$field: ${msg.toString().trim()}');
              }
            }
          } else if (entry.value != null &&
              entry.value.toString().trim().isNotEmpty) {
            errorList.add('$field: ${entry.value.toString().trim()}');
          }
        }
        if (errorList.isNotEmpty) {
          serverMessage = errorList.join('\n');
        }
      }

      // 3. Formato de lista de errores: "error": [{"detail": "..."}]
      if (serverMessage == null && responseData['error'] is List) {
        final list = responseData['error'] as List;
        final details = <String>[];
        for (final item in list) {
          if (item is Map && item['detail'] is String) {
            details.add(item['detail'].toString().trim());
          }
        }
        if (details.isNotEmpty) {
          serverMessage = details.join('\n');
        }
      }

      // 4. Fallback a ProblemDetails title
      if (serverMessage == null && responseData['title'] is String) {
        serverMessage = (responseData['title'] as String).trim();
      }
    } else if (responseData is String && responseData.trim().isNotEmpty) {
      serverMessage = responseData.trim();
    }

    if (serverMessage == null || serverMessage.isEmpty) {
      final code = error.response?.statusCode;
      if (code == 400) {
        serverMessage =
            'Los datos enviados no son válidos. Revisa la información.';
      } else if (code == 401) {
        serverMessage = 'No autorizado. Revisa tus credenciales.';
      } else if (code == 403) {
        serverMessage = 'No tienes permiso para realizar esta acción.';
      } else if (code == 404) {
        serverMessage = 'El recurso solicitado no fue encontrado.';
      } else if (code != null && code >= 500) {
        serverMessage =
            'El servidor no está disponible en este momento. Inténtalo más tarde.';
      } else {
        serverMessage =
            'No fue posible conectar con el servidor. Revisa tu conexión.';
      }
    }

    return ApiException(
      message: serverMessage,
      statusCode: error.response?.statusCode,
      details: responseData,
    );
  }
}
