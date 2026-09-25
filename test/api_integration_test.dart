import 'dart:convert';
import 'dart:typed_data';

import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_endpoints.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/network/dio_api_client.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/dashboard/data/dashboard_api.dart';
import 'package:app_yonke/features/quotes/domain/client_quote.dart';
import 'package:app_yonke/features/requests/data/request_submission_repository.dart';
import 'package:app_yonke/features/requests/data/requests_api.dart';
import 'package:app_yonke/features/requests/domain/request_draft.dart';
import 'package:app_yonke/features/requests/domain/request_submission.dart';
import 'package:app_yonke/features/quotes/data/quotes_api.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_request_detail_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comportamiento de la app frente a las respuestas reales del API publicado.
void main() {
  group('DioApiClient', () {
    DioApiClient clientReturning(
      int status,
      Object body, {
      Map<String, List<String>> headers = const {},
    }) => DioApiClient(
      _MemoryTokenStore(),
      dio: Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = _FixedAdapter(status, body, headers),
    );

    test('200 con success:false es un error de negocio', () async {
      final client = clientReturning(200, {
        'success': false,
        'message': 'No se pudo registrar el dispositivo.',
      });

      await expectLater(
        client.post(ApiEndpoints.registerClientDevice),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'No se pudo registrar el dispositivo.',
          ),
        ),
      );
    });

    test('200 sin sobre se devuelve tal cual', () async {
      final client = clientReturning(200, {'token': 'jwt'});
      expect(await client.post(ApiEndpoints.yonkeLogin), {'token': 'jwt'});
    });

    test('lee `mensaje` de Orden y Yonkes', () async {
      final client = clientReturning(404, {'mensaje': 'Orden no encontrada'});

      await expectLater(
        client.get(ApiEndpoints.order('x')),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Orden no encontrada',
          ),
        ),
      );
    });

    test('el 302 hacia /Account/Login es un error de la acción', () async {
      final client = clientReturning(
        302,
        '',
        headers: {
          'location': ['https://api.test/Account/Login?ReturnUrl=%2Fapi'],
        },
      );

      await expectLater(
        client.get(ApiEndpoints.request('x')),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'code', 302)
              .having((e) => e.message, 'message', contains('no aceptó')),
        ),
      );
    });

    test('el límite diario devuelto como 500 tiene un mensaje claro', () async {
      final client = clientReturning(500, {
        'message':
            'Error interno: Has alcanzado el límite de 3 solicitudes de '
            'cotización por día.',
      });

      await expectLater(
        client.post(ApiEndpoints.requests),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('límite de solicitudes por día'),
          ),
        ),
      );
    });

    test('quita el prefijo "Error interno:"', () async {
      final client = clientReturning(500, {
        'message': 'Error interno: La marca no existe',
      });

      await expectLater(
        client.get(ApiEndpoints.brands),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'La marca no existe',
          ),
        ),
      );
    });
  });

  group('envío de solicitud', () {
    RequestDraft draft() => RequestDraft()
      ..part = 'Alternador'
      ..brandId = 3
      ..modelId = 8
      ..year = 2015
      ..cityId = 12;

    test('usa el GuidId real de mi-solicitud-reciente', () async {
      final client = _RoutedClient({
        ApiEndpoints.requests: {'success': true, 'data': 'guid-falso'},
        ApiEndpoints.dashboardRecentRequest: {
          'data': {
            'guidId': 'guid-real',
            'piezaBuscada': 'Alternador',
            'marcaId': 3,
            'modeloId': 8,
            'año': 2015,
          },
        },
        ApiEndpoints.sendRequestToYonkes('guid-real'): {'success': true},
      });

      final result = await ApiRequestSubmissionRepository(
        RequestsApi(client),
        DashboardApi(client),
      ).submit(draft());

      expect(result.requestId, 'guid-real');
      expect(
        client.bodies[ApiEndpoints.requests],
        isNot(contains('usuarioId')),
      );
    });

    test('si la reciente es otra solicitud conserva el id devuelto', () async {
      final client = _RoutedClient({
        ApiEndpoints.requests: {'data': 'guid-devuelto'},
        ApiEndpoints.dashboardRecentRequest: {
          'data': {
            'guidId': 'otra',
            'piezaBuscada': 'Marcha',
            'marcaId': 3,
            'modeloId': 8,
            'año': 2015,
          },
        },
        ApiEndpoints.sendRequestToYonkes('guid-devuelto'): {'success': true},
      });

      final result = await ApiRequestSubmissionRepository(
        RequestsApi(client),
        DashboardApi(client),
      ).submit(draft());

      expect(result.requestId, 'guid-devuelto');
    });

    test('un error al crear se informa sin simular éxito', () async {
      final client = _RoutedClient({
        ApiEndpoints.requests: const ApiException(
          message: 'Alcanzaste el límite de solicitudes por día.',
          statusCode: 500,
        ),
      });

      await expectLater(
        ApiRequestSubmissionRepository(RequestsApi(client)).submit(draft()),
        throwsA(
          isA<RequestSubmissionException>()
              .having((e) => e.stage, 'stage', RequestSubmissionStage.create)
              .having((e) => e.message, 'message', contains('límite')),
        ),
      );
      expect(client.calls, [ApiEndpoints.requests]);
    });

    test('un error al enviar a yonkes ya no se oculta', () async {
      final client = _RoutedClient({
        ApiEndpoints.requests: {'data': 'guid'},
        ApiEndpoints.sendRequestToYonkes('guid'): const ApiException(
          message: 'No hay yonkes con cobertura en la ciudad.',
          statusCode: 400,
        ),
      });

      await expectLater(
        ApiRequestSubmissionRepository(RequestsApi(client)).submit(draft()),
        throwsA(
          isA<RequestSubmissionException>()
              .having((e) => e.stage, 'stage', RequestSubmissionStage.dispatch)
              .having((e) => e.requestId, 'requestId', 'guid'),
        ),
      );
    });
  });

  group('detalle de solicitud sin GET Solicitudes/{guid}', () {
    const redirect = ApiException(
      message: 'El servidor no aceptó la sesión para esta acción.',
      statusCode: 302,
    );

    test('el cliente lo toma de mis-solicitudes', () async {
      final client = _RoutedClient({
        ApiEndpoints.request('s1'): redirect,
        ApiEndpoints.dashboardRequests: {
          'data': {
            'data': [
              {'guidId': 'otra', 'piezaBuscada': 'Marcha'},
              {'guidId': 'S1', 'piezaBuscada': 'Alternador', 'folio': 'F-1'},
            ],
          },
        },
      });

      final response = await clientRequestResponse(
        RequestsApi(client),
        DashboardApi(client),
        's1',
      );

      expect((response as Map)['data']['piezaBuscada'], 'Alternador');
    });

    test('si tampoco está en mis-solicitudes se informa el error', () async {
      final client = _RoutedClient({
        ApiEndpoints.request('s1'): redirect,
        ApiEndpoints.dashboardRequests: {'data': <Object>[]},
      });

      await expectLater(
        clientRequestResponse(RequestsApi(client), DashboardApi(client), 's1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 302)),
      );
    });

    test('el yonke lo arma con la bandeja y las fotos', () async {
      final client = _RoutedClient({
        ApiEndpoints.request('s1'): redirect,
        ApiEndpoints.requestImages('s1'): {
          'data': [
            {'guidId': 'i1', 'urlImagen': 'https://blob.example.com/1.jpg'},
          ],
        },
        ApiEndpoints.yonkeAssignedRequests: {
          'data': [
            {
              'solicitudYonkeGuidId': 'a1',
              'solicitudGuidId': 's1',
              'folio': 'SOL-1',
              'piezaBuscada': 'Alternador',
              'fechaEnvio': '2026-09-25T10:00:00Z',
              'estatus': 'Enviada',
              'ciudades': [
                {'ciudadId': 12, 'ciudad': 'Hermosillo'},
              ],
            },
          ],
        },
      });

      final detail = await ApiYonkeRequestDetailRepository(
        RequestsApi(client),
        QuotesApi(client),
      ).getDetail(requestId: 's1', requestYonkeId: 'a1');

      expect(detail.part, 'Alternador');
      expect(detail.folio, 'SOL-1');
      expect(detail.city, 'Hermosillo');
      expect(detail.imageUrls, ['https://blob.example.com/1.jpg']);
    });
  });

  group('cotizaciones del cliente', () {
    test('mis-cotizaciones se asume activa y no inventa yonkeId', () {
      final quotes = clientQuotesFromDashboard({
        'data': [
          {
            'guidId': 'q1',
            'solicitudYonkeGuidId': 'asignacion',
            'folio': 'SOL-1',
            'precio': 850,
            'activo': false,
          },
        ],
      });

      expect(quotes.single.active, isTrue);
      expect(quotes.single.yonkeId, isEmpty);
    });

    test('el detalle lee `año` y respeta `activo`', () {
      final quote = clientQuoteFromResponse({
        'data': {
          'guidId': 'q1',
          'solicitudGuidId': 's1',
          'año': 2018,
          'activo': false,
        },
      });

      expect(quote!.year, 2018);
      expect(quote.active, isFalse);
    });
  });
}

class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.status, this.body, this.headers);

  final int status;
  final Object body;
  final Map<String, List<String>> headers;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body is String ? body as String : jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...headers,
    },
  );

  @override
  void close({bool force = false}) {}
}

class _RoutedClient implements ApiClient {
  _RoutedClient(this.routes);

  final Map<String, Object?> routes;
  final calls = <String>[];
  final bodies = <String, Object?>{};

  Future<dynamic> _respond(String path, [Object? data]) async {
    calls.add(path);
    bodies[path] = data is Map ? data.keys.toList() : data;
    if (!routes.containsKey(path)) throw StateError('Ruta inesperada: $path');
    final value = routes[path];
    if (value is Exception) throw value;
    return value;
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _respond(path);

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _respond(path, data);

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _respond(path, data);

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _respond(path, data);

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) => _respond(path, fields);
}

class _MemoryTokenStore implements TokenStore {
  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<DateTime?> readExpiresAt() async => null;

  @override
  Future<String?> readYonkeGuidId() async => null;

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async {}

  @override
  Future<void> clear() async {}
}
