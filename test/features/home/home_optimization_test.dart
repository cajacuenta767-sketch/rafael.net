import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/home/presentation/role_home_page.dart';
import 'package:app_yonke/features/requests/domain/client_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Optimización de Modelos y Parsing de ImagenUrl', () {
    test('clientRequestSummaryFromJson parsea imagenUrl directa del backend', () {
      final json = {
        'guidId': 'req-123',
        'piezaBuscada': 'Alternador',
        'marca': 'Toyota',
        'modelo': 'Corolla',
        'año': 2020,
        'folio': 'SOL-100',
        'imagenUrl': 'https://storage.refanet.com/fotos/alternador.jpg',
      };

      final summary = clientRequestSummaryFromJson(json);

      expect(summary, isNotNull);
      expect(summary!.id, 'req-123');
      expect(summary.part, 'Alternador');
      expect(
        summary.imageUrl,
        'https://storage.refanet.com/fotos/alternador.jpg',
      );
    });

    test('clientRequestSummaryFromJson parsea imageUrl (camelCase)', () {
      final json = {
        'guidId': 'req-124',
        'piezaBuscada': 'Cofre',
        'imageUrl': 'https://storage.refanet.com/fotos/cofre.jpg',
      };

      final summary = clientRequestSummaryFromJson(json);

      expect(summary, isNotNull);
      expect(summary!.imageUrl, 'https://storage.refanet.com/fotos/cofre.jpg');
    });

    test('clientRequestSummaryFromJson usa solicitudesImagenes como fallback', () {
      final json = {
        'guidId': 'req-125',
        'piezaBuscada': 'Faro',
        'solicitudesImagenes': [
          {'urlImagen': 'https://storage.refanet.com/fotos/faro.jpg'},
        ],
      };

      final summary = clientRequestSummaryFromJson(json);

      expect(summary, isNotNull);
      expect(summary!.imageUrl, 'https://storage.refanet.com/fotos/faro.jpg');
    });
  });

  group('Optimización de Pantalla de Inicio y Contadores', () {
    testWidgets('RoleHomePage.client renderiza contadores desde getSummary y solicitudes con imagenUrl', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeApi = _OptimizedFakeApi();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStoreProvider.overrideWithValue(_MockTokenStore('test-token')),
            apiClientProvider.overrideWithValue(fakeApi),
          ],
          child: const MaterialApp(home: RoleHomePage.client()),
        ),
      );

      // Primer frame: renderiza sin crash
      await tester.pump();

      // Dejar que resuelvan los futures de carga rápida
      await tester.pumpAndSettle();

      // Verificar que se llamaron los endpoints optimizados
      expect(fakeApi.calledEndpoints, contains('/api/DashboardSuscriptores/resumen'));
      expect(fakeApi.calledEndpoints, contains('/api/DashboardSuscriptores/mis-solicitudes'));

      // Verificar que contadores muestran los valores devueltos por el resumen
      expect(find.text('Mis solicitudes'), findsOneWidget);
      expect(find.text('Cotizaciones'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // totalSolicitudes
      expect(find.text('2'), findsOneWidget); // totalCotizaciones

      // Verificar que la solicitud reciente aparece
      expect(find.text('Transmisión Automática'), findsOneWidget);
    });
  });
}

class _MockTokenStore implements TokenStore {
  _MockTokenStore(this.accessToken);
  String? accessToken;

  @override
  Future<String?> readAccessToken() async => accessToken;
  @override
  Future<String?> readRefreshToken() async => null;
  @override
  Future<DateTime?> readExpiresAt() async => null;
  @override
  Future<String?> readYonkeGuidId() async => null;
  @override
  Future<void> clear() async => accessToken = null;
  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async => this.accessToken = accessToken;
}

class _OptimizedFakeApi implements ApiClient {
  final List<String> calledEndpoints = [];

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    calledEndpoints.add(path);

    if (path == '/api/DashboardSuscriptores/resumen') {
      return {
        'success': true,
        'message': 'Resumen obtenido correctamente.',
        'data': {'totalSolicitudes': 5, 'totalCotizaciones': 2},
      };
    }

    if (path == '/api/DashboardSuscriptores/mis-solicitudes') {
      return {
        'success': true,
        'data': {
          'data': [
            {
              'guidId': 'req-opt-1',
              'piezaBuscada': 'Transmisión Automática',
              'marca': 'Honda',
              'modelo': 'Civic',
              'año': 2018,
              'folio': 'SOL-20261001',
              'fechaCreacion': '2026-10-01T12:00:00Z',
              'totalCotizaciones': 3,
              'imagenUrl': 'https://storage.refanet.com/fotos/transmision.jpg',
            },
          ],
          'meta': {'page': 1, 'take': 3, 'itemCount': 5, 'pageCount': 2},
        },
      };
    }

    return {'success': true, 'data': <Object>[]};
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => {'success': true};

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => {'success': true};

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => {'success': true};

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) async => {'success': true};
}
