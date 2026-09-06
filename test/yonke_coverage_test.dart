import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/yonke_coverage/presentation/yonke_coverage_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cobertura del yonke sobre la API simulada: el guid del yonke sale del
/// almacenamiento de sesión, las ciudades de `Utilerias` y la cobertura
/// vigente de `YonkesCoberturas/guid/{id}` (solo las activas).
void main() {
  testWidgets('carga la cobertura real, permite cambiarla y la guarda', (
    tester,
  ) async {
    final api = _FakeApiClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          tokenStoreProvider.overrideWithValue(
            _MemoryTokenStore(accessToken: 'token', yonkeGuidId: 'yonke-1'),
          ),
        ],
        child: const MaterialApp(home: YonkeCoveragePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.paths, contains('GET /api/YonkesCoberturas/guid/yonke-1'));
    expect(find.text('Nogales'), findsOneWidget);
    expect(find.text('Hermosillo'), findsOneWidget);
    // La ciudad 3 tiene cobertura inactiva: no debe aparecer seleccionada.
    final aguaPrieta = tester.widget<CheckboxListTile>(
      find.byKey(const Key('yonke-coverage-city-3')),
    );
    expect(aguaPrieta.value, isFalse);

    await tester.tap(find.byKey(const Key('yonke-coverage-city-3')));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yonke-save-coverage')));
    await tester.pumpAndSettle();

    expect(api.lastCoverageBody, {
      'yonkeGuidId': 'yonke-1',
      'ciudadesIds': [1, 3],
    });
    expect(find.text('Cobertura guardada.'), findsOneWidget);
  });

  testWidgets('sin guid del yonke no consulta ni guarda cobertura', (
    tester,
  ) async {
    final api = _FakeApiClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          tokenStoreProvider.overrideWithValue(
            _MemoryTokenStore(accessToken: 'token'),
          ),
        ],
        child: const MaterialApp(home: YonkeCoveragePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cobertura pendiente de conexión'), findsOneWidget);
    expect(api.paths, isEmpty);
  });
}

Map<String, dynamic> _ok(Object? data) => {
  'success': true,
  'message': 'OK',
  'data': data,
  'statusCode': 200,
  'errors': null,
};

class _FakeApiClient implements ApiClient {
  final paths = <String>[];
  Object? lastCoverageBody;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    paths.add('GET $path');
    return switch (path) {
      '/api/Utilerias/entidades' => _ok([
        {'id': 26, 'entidad': 'Sonora'},
      ]),
      '/api/Utilerias/entidad/26/ciudades' => _ok([
        {'id': 1, 'ciudad': 'Nogales', 'entidadId': 26},
        {'id': 2, 'ciudad': 'Hermosillo', 'entidadId': 26},
        {'id': 3, 'ciudad': 'Agua Prieta', 'entidadId': 26},
      ]),
      '/api/YonkesCoberturas/guid/yonke-1' => _ok([
        {'ciudadId': 1, 'activo': true},
        {'ciudadId': 3, 'activo': false},
      ]),
      _ => throw ApiException(message: 'Sin ruta $path', statusCode: 404),
    };
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    paths.add('PUT $path');
    if (path == '/api/YonkesCoberturas') {
      lastCoverageBody = data;
      return _ok('ok');
    }
    throw ApiException(message: 'Sin ruta $path', statusCode: 404);
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => throw UnimplementedError();

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => throw UnimplementedError();

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) => throw UnimplementedError();
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore({this.accessToken, this.yonkeGuidId});

  String? accessToken;
  String? yonkeGuidId;

  @override
  Future<void> clear() async {
    accessToken = null;
    yonkeGuidId = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<DateTime?> readExpiresAt() async => null;

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
    this.yonkeGuidId = yonkeGuidId;
  }
}
