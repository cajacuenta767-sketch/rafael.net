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
              sendTimeout: AppConfig.sendTimeout,
              // Un endpoint con [Authorize] sin esquema JWT responde 302 hacia
              // /Account/Login; seguirlo ocultaría que la sesión no se aceptó.
              followRedirects: false,
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
          // Solo se cierra la sesión cuando está confirmado que el token ya no
          // sirve; un 401 o un 302 de un endpoint mal configurado no basta.
          if (error.requestOptions.extra[_sessionProbeFlag] != true &&
              error.response?.statusCode == 401 &&
              error.requestOptions.headers.containsKey('Authorization') &&
              await _sessionIsInvalid(error.response!)) {
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
  Future<bool>? _sessionProbe;

  static const _sessionProbeFlag = 'refanet.sessionProbe';

  /// Varios endpoints del API responden 401 o 302 aunque el token sea válido
  /// (usan `[Authorize]` sin el esquema JWT). Por eso un 401 solo cierra la
  /// sesión si el token venció, si JwtBearer lo declara inválido o si un
  /// endpoint que sí acepta el JWT también lo rechaza.
  Future<bool> _sessionIsInvalid(Response<dynamic> response) async {
    final expiresAt = await _tokenStore.readExpiresAt();
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc())) {
      return true;
    }
    final challenge = response.headers.value('www-authenticate') ?? '';
    if (challenge.toLowerCase().contains('invalid_token')) return true;
    return _sessionProbe ??= _probeSession().whenComplete(
      () => _sessionProbe = null,
    );
  }

  /// `GET /api/Yonkes/byPage` exige el esquema JWT y acepta a los roles
  /// Cliente y Asociado: si también responde 401, el token ya no sirve. Un
  /// fallo de red conserva la sesión.
  Future<bool> _probeSession() async {
    try {
      final response = await _dio.get<dynamic>(
        ApiEndpoints.pagedYonkes,
        queryParameters: const {'Page': 1, 'CantidadRegistrosPorPagina': 1},
        options: Options(
          extra: const {_sessionProbeFlag: true},
          validateStatus: (_) => true,
        ),
      );
      return response.statusCode == 401;
    } catch (_) {
      return false;
    }
  }

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
      _throwIfEnvelopeFailed(response.data, response.statusCode);
      return response.data;
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  /// El API a veces responde 200 con `success: false` en `ApiResponseGlobal`;
  /// eso es un error de negocio y no debe interpretarse como datos vacíos.
  static void _throwIfEnvelopeFailed(Object? body, int? httpStatus) {
    if (body is! Map || body['success'] != false) return;
    final message = _firstText(body, const ['message', 'mensaje']);
    final code = body['statusCode'];
    throw ApiException(
      message: message ?? 'La operación no se pudo completar.',
      statusCode: code is num && code >= 400 ? code.toInt() : httpStatus,
      details: body,
    );
  }

  static String? _firstText(Map<dynamic, dynamic> body, List<String> keys) {
    for (final key in keys) {
      final value = body[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  /// `[Authorize]` sin esquema JWT responde 302 hacia `/Account/Login`.
  static bool _isLoginRedirect(Response<dynamic>? response) {
    if (response?.statusCode != 302) return false;
    final location = response!.headers.value('location') ?? '';
    return location.toLowerCase().contains('/account/login');
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
      // 1. Mensaje directo (`message` en ApiResponseGlobal, `mensaje` en
      // Orden, Yonkes/updateInfo y ActualizarLogo).
      serverMessage = _firstText(responseData, const ['message', 'mensaje']);

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
    } else if (responseData is String &&
        responseData.trim().isNotEmpty &&
        !responseData.trimLeft().startsWith('<')) {
      serverMessage = responseData.trim();
    }

    final code = error.response?.statusCode;
    serverMessage = _friendlyServerMessage(serverMessage);
    if (_isLoginRedirect(error.response)) {
      serverMessage =
          'El servidor no aceptó la sesión para esta acción. '
          'Inténtalo más tarde.';
    }

    if (serverMessage == null || serverMessage.isEmpty) {
      if (_isTimeout(error)) {
        serverMessage =
            'El servidor tardó demasiado en responder. Inténtalo de nuevo.';
      } else if (code == 400) {
        serverMessage =
            'Los datos enviados no son válidos. Revisa la información.';
      } else if (code == 401) {
        serverMessage = 'No autorizado. Revisa tus credenciales.';
      } else if (code == 403) {
        serverMessage = 'No tienes permiso para realizar esta acción.';
      } else if (code == 404) {
        serverMessage = 'El recurso solicitado no fue encontrado.';
      } else if (code != null && code >= 500) {
        serverMessage = 'El servidor no está disponible en este momento. Inténtalo más tarde.';
      } else {
        serverMessage =
            'No fue posible conectar con el servidor. Revisa tu conexión.';
      }
    }

    return ApiException(
      message: serverMessage,
      statusCode: code,
      details: responseData,
    );
  }

  static bool _isTimeout(DioException error) => const {
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  }.contains(error.type);

  /// El API envuelve algunos errores de negocio en un 500 con
  /// "Error interno: …". Se conserva el detalle útil y se quita el prefijo.
  static String? _friendlyServerMessage(String? message) {
    if (message == null) return null;
    final lower = message.toLowerCase();
    if (lower.contains('solicitudes') &&
        (lower.contains('por día') ||
            lower.contains('por dia') ||
            lower.contains('diari') ||
            lower.contains('límite') ||
            lower.contains('limite'))) {
      return 'Alcanzaste el límite de solicitudes por día. '
          'Inténtalo de nuevo mañana.';
    }
    final internal = RegExp(r'^error interno:\s*', caseSensitive: false);
    return message.replaceFirst(internal, '').trim();
  }
}
