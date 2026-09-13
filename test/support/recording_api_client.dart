import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/storage/token_store.dart';

typedef RecordedCall = ({
  String method,
  String path,
  Object? data,
  Map<String, dynamic>? query,
  Map<String, dynamic>? fields,
  List<ApiFile> files,
});

typedef RouteHandler = Object? Function(RecordedCall call);

/// Cliente HTTP simulado que registra cada llamada y responde según
/// `'MÉTODO ruta'`. Si el manejador devuelve una [ApiException], la lanza,
/// igual que haría `DioApiClient` ante un error HTTP.
class RecordingApiClient implements ApiClient {
  RecordingApiClient(this.routes);

  final Map<String, RouteHandler> routes;
  final calls = <RecordedCall>[];

  Iterable<RecordedCall> callsTo(String path) =>
      calls.where((call) => call.path == path);

  List<String> get trace =>
      calls.map((call) => '${call.method} ${call.path}').toList();

  /// Sobre `ApiResponseGlobal` documentado en el OpenAPI.
  static Map<String, dynamic> ok(Object? data, {String message = 'OK'}) => {
    'success': true,
    'message': message,
    'data': data,
    'statusCode': 200,
    'errors': null,
  };

  Future<dynamic> _handle(RecordedCall call) async {
    calls.add(call);
    final handler = routes['${call.method} ${call.path}'];
    if (handler == null) {
      throw ApiException(
        message: 'Sin respuesta simulada para ${call.method} ${call.path}',
        statusCode: 404,
      );
    }
    final result = handler(call);
    if (result is ApiException) throw result;
    return result;
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _handle((
        method: 'GET',
        path: path,
        data: null,
        query: queryParameters,
        fields: null,
        files: const [],
      ));

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _handle((
    method: 'POST',
    path: path,
    data: data,
    query: queryParameters,
    fields: null,
    files: const [],
  ));

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _handle((
    method: 'PUT',
    path: path,
    data: data,
    query: queryParameters,
    fields: null,
    files: const [],
  ));

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _handle((
    method: 'DELETE',
    path: path,
    data: data,
    query: queryParameters,
    fields: null,
    files: const [],
  ));

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) => _handle((
    method: method,
    path: path,
    data: null,
    query: queryParameters,
    fields: fields,
    files: files,
  ));
}

/// Almacén de sesión en memoria para pruebas.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore({this.accessToken, this.expiresAt, this.yonkeGuidId});

  String? accessToken;
  DateTime? expiresAt;
  String? yonkeGuidId;
  int clears = 0;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<DateTime?> readExpiresAt() async => expiresAt;

  @override
  Future<String?> readYonkeGuidId() async => yonkeGuidId;

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async {
    this.accessToken = accessToken;
    this.expiresAt = expiresAt;
    this.yonkeGuidId = yonkeGuidId;
  }

  @override
  Future<void> clear() async {
    clears++;
    accessToken = null;
    expiresAt = null;
    yonkeGuidId = null;
  }
}
