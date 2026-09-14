import 'dart:typed_data';

import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/features/dashboard/data/dashboard_api.dart';
import 'package:app_yonke/features/quotes/data/quotes_api.dart';
import 'package:app_yonke/features/requests/data/requests_api.dart';
import 'package:app_yonke/features/yonke_quotes/data/yonke_quotes_repository.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_request_detail_repository.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_requests_repository.dart';
import 'package:app_yonke/features/yonke_requests/domain/yonke_request_detail.dart';
import 'package:app_yonke/features/yonke_requests/domain/yonke_request_summary.dart';
import 'package:app_yonke/features/yonke_requests/presentation/yonke_quote_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/recording_api_client.dart';

/// Registro `SolicitudYonkes` tal como lo entrega
/// `GET /api/DashboardSuscriptores/mis-solicitudes` con el token del yonke.
Map<String, dynamic> _assignment({
  required String id,
  required String requestId,
  String? viewedAt,
}) => {
  'guidId': id,
  'solicitudGuidId': requestId,
  'yonkeGuidId': 'yonke-1',
  'fechaEnvio': '2026-09-10T15:00:00Z',
  'fechaVista': viewedAt,
  'solicitudYonkesEstatus': {'estatusSolicitud': 'Nueva'},
  'solicitudes': {
    'guidId': requestId,
    'piezaBuscada': 'Alternador',
    'año': 2018,
    'folio': 'SOL-0042/2026',
    'fechaCreacion': '2026-09-10T14:55:00Z',
    'marcas': {'marca': 'Nissan'},
    'modelos': {'modelo': 'Sentra'},
    'solicitudesImagenes': [
      {'urlImagen': 'https://cdn.example.com/foto.jpg'},
    ],
    'solicitudesCiudades': [
      {
        'ciudades': {
          'ciudad': 'Nogales',
          'entidades': {'entidad': 'Sonora'},
        },
      },
    ],
  },
  'solicitudCotizaciones': const <Map<String, dynamic>>[],
};

void main() {
  group('Bandeja del yonke (DashboardSuscriptores/mis-solicitudes)', () {
    test('muestra las solicitudes asignadas por el servidor', () async {
      final api = RecordingApiClient({
        'GET /api/DashboardSuscriptores/mis-solicitudes': (call) {
          expect(call.query, {
            'Page': 1,
            'CantidadRegistrosPorPagina': 20,
            'Search': null,
          });
          return RecordingApiClient.ok([
            _assignment(id: 'asig-1', requestId: 'req-1'),
            _assignment(
              id: 'asig-2',
              requestId: 'req-2',
              viewedAt: '2026-09-10T16:00:00Z',
            ),
          ]);
        },
      });
      final repository = ApiYonkeRequestsRepository(
        DashboardApi(api),
        RequestsApi(api),
      );

      final page = await repository.getAssignedRequests(page: 1, pageSize: 20);

      expect(page.items, hasLength(2));
      final first = page.items.firstWhere((item) => item.requestId == 'req-1');
      expect(first.requestYonkeId, 'asig-1');
      expect(first.part, 'Alternador');
      expect(first.brand, 'Nissan');
      expect(first.model, 'Sentra');
      expect(first.city, 'Nogales, Sonora');
      expect(first.status, YonkeRequestStatus.newRequest);
      expect(first.imageUrl, 'https://cdn.example.com/foto.jpg');
      expect(
        page.items.firstWhere((item) => item.requestId == 'req-2').status,
        YonkeRequestStatus.viewed,
      );
    });

    test('propaga el error del servidor en lugar de mostrar datos locales', () {
      final api = RecordingApiClient({
        'GET /api/DashboardSuscriptores/mis-solicitudes': (_) =>
            const ApiException(message: 'Sesión vencida', statusCode: 401),
      });
      final repository = ApiYonkeRequestsRepository(
        DashboardApi(api),
        RequestsApi(api),
      );

      expect(
        repository.getAssignedRequests(page: 1, pageSize: 20),
        throwsA(isA<ApiException>()),
      );
    });

    test('reporta contrato pendiente ante una forma desconocida', () {
      final api = RecordingApiClient({
        'GET /api/DashboardSuscriptores/mis-solicitudes': (_) =>
            RecordingApiClient.ok([
              {'algo': 'sin solicitud'},
            ]),
      });
      final repository = ApiYonkeRequestsRepository(
        DashboardApi(api),
        RequestsApi(api),
      );

      expect(
        repository.getAssignedRequests(page: 1, pageSize: 20),
        throwsA(isA<AssignedRequestsEndpointPendingException>()),
      );
    });

    test('construye el detalle con la fila de la bandeja cuando el servidor '
        'responde 404 al consultar la solicitud con token de yonke', () async {
      final api = RecordingApiClient({
        'GET /api/Solicitudes/d846c250': (_) => const ApiException(
          message: 'No se encontró la solicitud',
          statusCode: 404,
        ),
        'GET /api/SolicitudesImagenes/d846c250/imagenes': (_) =>
            const ApiException(message: 'sin fotos', statusCode: 404),
      });
      final repository = ApiYonkeRequestDetailRepository(
        RequestsApi(api),
        QuotesApi(api),
      );
      final summary = yonkeRequestSummaryFromJson({
        'id': 7,
        'guidId': 'd846c250',
        'estatusSolicitud': 'Pendiente',
        'marca': 'Nissan',
        'modelo': 'Altima',
        'año': 2019,
        'motor': 'Estándar',
        'transmicion': 'Estándar',
        'piezaBuscada': 'Prueba Swagger 2',
        'numeroParte': 'S/N',
        'descripcion': 'Prueba desde Swagger',
        'folio': 'SOL-00007/2026',
        'fechaCreacion': '2026-09-13T22:49:41.447',
        'cerrada': false,
      })!;

      final detail = await repository.getDetail(
        requestId: summary.requestId,
        requestYonkeId: summary.requestYonkeId,
        summary: summary,
      );

      expect(detail.part, 'Prueba Swagger 2');
      expect(detail.folio, 'SOL-00007/2026');
      expect(detail.brand, 'Nissan');
      expect(detail.year, 2019);
      expect(detail.description, 'Prueba desde Swagger');
      expect(detail.partNumber, 'S/N');
      expect(detail.requestYonkeId, 'd846c250');
      expect(detail.closed, isFalse);
    });

    test('marca la solicitud como vista en el servidor', () async {
      final api = RecordingApiClient({
        'PUT /api/SolicitudYonkes/asig-1/vista': (_) =>
            RecordingApiClient.ok('ok'),
      });
      final repository = ApiYonkeRequestsRepository(
        DashboardApi(api),
        RequestsApi(api),
      );

      await repository.markAsViewed('asig-1');

      expect(api.trace, ['PUT /api/SolicitudYonkes/asig-1/vista']);
    });
  });

  group('Cotización del yonke (CotizacionYonke)', () {
    test(
      'envía la cotización como multipart con el guid de asignación',
      () async {
        final api = RecordingApiClient({
          'POST /api/CotizacionYonke': (_) =>
              RecordingApiClient.ok({'guidId': 'quote-1'}),
        });
        final repository = ApiYonkeRequestDetailRepository(
          RequestsApi(api),
          QuotesApi(api),
        );

        await repository.submitQuote(
          'asig-1',
          YonkeQuoteSubmission(
            price: 1850,
            isNew: false,
            brandId: 4,
            partNumber: 'ABC-1',
            comments: 'Probada',
            deliveryDays: 2,
            hasWarranty: true,
            warrantyDays: 30,
            shippingAvailable: true,
            shippingCost: 120,
            images: [
              YonkeQuoteImage(
                fileName: 'pieza.jpg',
                bytes: Uint8List.fromList([1, 2]),
              ),
            ],
          ),
        );

        final call = api.callsTo('/api/CotizacionYonke').single;
        expect(call.method, 'POST');
        expect(call.query, {'solicitudYonkeGuidId': 'asig-1'});
        expect(call.fields, {
          'Precio': 1850.0,
          'Disponible': true,
          'EsNueva': false,
          'MarcaId': 4,
          'NumeroParte': 'ABC-1',
          'Comentarios': 'Probada',
          'TiempoEntregaDias': 2,
          'DiasGarantia': 30,
          'EnvioDisponible': true,
          'CostoEnvio': 120.0,
          'TieneGarantia': true,
        });
        expect(call.files.single.fieldName, 'Imagenes');
      },
    );

    test('lanza el mensaje del servidor cuando rechaza la cotización', () {
      final api = RecordingApiClient({
        'POST /api/CotizacionYonke': (_) => {
          'success': false,
          'message': 'La solicitud ya fue cerrada por el cliente',
          'data': null,
          'statusCode': 409,
        },
      });
      final repository = ApiYonkeRequestDetailRepository(
        RequestsApi(api),
        QuotesApi(api),
      );

      expect(
        repository.submitQuote(
          'asig-1',
          const YonkeQuoteSubmission(
            price: 100,
            isNew: false,
            hasWarranty: false,
            warrantyDays: 0,
            shippingAvailable: false,
          ),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'La solicitud ya fue cerrada por el cliente',
          ),
        ),
      );
    });

    test('«no disponible» registra una cotización sin precio', () async {
      final api = RecordingApiClient({
        'POST /api/CotizacionYonke': (_) => RecordingApiClient.ok('ok'),
      });
      final repository = ApiYonkeRequestDetailRepository(
        RequestsApi(api),
        QuotesApi(api),
      );

      await repository.markUnavailable('asig-1', brandId: 4);

      final call = api.callsTo('/api/CotizacionYonke').single;
      expect(call.query, {'solicitudYonkeGuidId': 'asig-1'});
      expect(call.fields!['Disponible'], isFalse);
      expect(call.fields!['Precio'], 0);
      expect(call.fields!['MarcaId'], 4);
    });

    test('las cotizaciones enviadas salen solo del servidor', () async {
      final api = RecordingApiClient({
        'GET /api/DashboardSuscriptores/mis-cotizaciones': (_) =>
            const ApiException(message: 'Sin conexión'),
      });
      final repository = ApiYonkeQuotesRepository(
        DashboardApi(api),
        QuotesApi(api),
      );

      expect(
        repository.getMyQuotes(page: 1, pageSize: 20),
        throwsA(isA<ApiException>()),
      );
    });
  });

  testWidgets('la pantalla de cotizar muestra el error del servidor y no '
      'finge éxito', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: YonkeQuotePage(
            requestYonkeId: 'asig-1',
            detail: _detail,
            repository: const _FailingDetailRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quote-price-field')), '1500');
    await tester.ensureVisible(find.byKey(const Key('submit-quote-button')));
    await tester.tap(find.byKey(const Key('submit-quote-button')));
    await tester.pumpAndSettle();

    expect(find.text('No se envió la cotización'), findsOneWidget);
    expect(find.textContaining('Cotización duplicada'), findsOneWidget);
    expect(find.text('Cotización enviada'), findsNothing);
    await tester.tap(find.byKey(const Key('quote-error-button')));
    await tester.pumpAndSettle();
    // El formulario sigue disponible para reintentar.
    expect(find.byKey(const Key('submit-quote-button')), findsOneWidget);
  });
}

const _detail = YonkeRequestDetail(
  requestId: 'req-1',
  requestYonkeId: 'asig-1',
  part: 'Alternador',
  status: YonkeRequestStatus.viewed,
  imageUrls: [],
  brandId: 4,
  brand: 'Nissan',
  model: 'Sentra',
  year: 2018,
);

class _FailingDetailRepository implements YonkeRequestDetailRepository {
  const _FailingDetailRepository();

  @override
  Future<YonkeRequestDetail> getDetail({
    required String requestId,
    required String requestYonkeId,
    YonkeRequestSummary? summary,
  }) async => _detail;

  @override
  Future<void> markUnavailable(String requestYonkeId, {int? brandId}) =>
      throw const ApiException(message: 'Cotización duplicada');

  @override
  Future<void> submitQuote(
    String requestYonkeId,
    YonkeQuoteSubmission submission, {
    YonkeRequestDetail? detail,
  }) => throw const ApiException(message: 'Cotización duplicada');
}
