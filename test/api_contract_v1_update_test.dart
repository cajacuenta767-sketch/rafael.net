import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/storage/session_sync_store.dart';
import 'package:app_yonke/features/dashboard/data/dashboard_api.dart';
import 'package:app_yonke/features/payments/data/payments_api.dart';
import 'package:app_yonke/features/requests/data/requests_api.dart';
import 'package:app_yonke/features/yonke_home/presentation/yonke_home_page.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_requests_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rutas agregadas al contrato V1: `SolicitudYonkes/MisSolicitudes`,
/// `CotizacionYonke/MisCotizaciones/Total` y el checkout de Stripe.
void main() {
  setUp(SessionSyncStore.instance.clear);

  Map<String, dynamic> assignment(String id, String part, String date) => {
    'guidId': 'assignment-$id',
    'solicitudGuidId': 'request-$id',
    'fechaEnvio': date,
    'solicitudes': {'guidId': 'request-$id', 'piezaBuscada': part},
  };

  ApiYonkeRequestsRepository repositoryFor(_RoutedClient client) =>
      ApiYonkeRequestsRepository(DashboardApi(client), RequestsApi(client));

  group('bandeja del yonke', () {
    test('usa MisSolicitudes y pagina en la app', () async {
      final client = _RoutedClient({
        '/api/SolicitudYonkes/MisSolicitudes': {
          'data': [
            assignment('1', 'Alternador', '2026-09-01T10:00:00Z'),
            assignment('2', 'Marcha', '2026-09-03T10:00:00Z'),
            assignment('3', 'Radiador', '2026-09-02T10:00:00Z'),
          ],
        },
      });

      final first = await repositoryFor(client)
          .getAssignedRequests(page: 1, pageSize: 2);
      final second = await repositoryFor(client)
          .getAssignedRequests(page: 2, pageSize: 2);

      expect(first.items.map((item) => item.part), ['Marcha', 'Radiador']);
      expect(first.hasMore, isTrue);
      expect(second.items.map((item) => item.part), ['Alternador']);
      expect(second.hasMore, isFalse);
      expect(
        client.calls,
        isNot(contains('/api/DashboardSuscriptores/mis-solicitudes')),
      );
    });

    test('filtra la búsqueda localmente', () async {
      final client = _RoutedClient({
        '/api/SolicitudYonkes/MisSolicitudes': [
          assignment('1', 'Alternador', '2026-09-01T10:00:00Z'),
          assignment('2', 'Marcha', '2026-09-03T10:00:00Z'),
        ],
      });

      final result = await repositoryFor(client)
          .getAssignedRequests(page: 1, pageSize: 20, search: 'alter');

      expect(result.items.single.requestYonkeId, 'assignment-1');
    });

    test('recurre al dashboard si MisSolicitudes falla', () async {
      final client = _RoutedClient({
        '/api/SolicitudYonkes/MisSolicitudes': const ApiException(
          message: 'No encontrado',
          statusCode: 404,
        ),
        '/api/DashboardSuscriptores/mis-solicitudes': {
          'data': [assignment('9', 'Faro', '2026-09-01T10:00:00Z')],
        },
      });

      final result = await repositoryFor(client)
          .getAssignedRequests(page: 1, pageSize: 20);

      expect(result.items.single.requestYonkeId, 'assignment-9');
    });

    test('un error de ambas rutas no se muestra como bandeja vacía', () async {
      const unauthorized = ApiException(
        message: 'No autorizado',
        statusCode: 401,
      );
      final client = _RoutedClient({
        '/api/SolicitudYonkes/MisSolicitudes': unauthorized,
        '/api/DashboardSuscriptores/mis-solicitudes': unauthorized,
      });

      await expectLater(
        repositoryFor(client).getAssignedRequests(page: 1, pageSize: 20),
        throwsA(isA<ApiException>()),
      );
    });
  });

  test('total de cotizaciones lee Int32ApiResponseGlobal', () {
    expect(quoteTotalFromResponse({'success': true, 'data': 7}), 7);
    expect(quoteTotalFromResponse({'data': '12'}), 12);
    expect(quoteTotalFromResponse({'data': null}), isNull);
  });

  group('checkout de Stripe', () {
    test('acepta la URL como data o dentro de un objeto', () {
      expect(
        checkoutUrlFromResponse({'data': 'https://checkout.stripe.com/c/1'}),
        Uri.parse('https://checkout.stripe.com/c/1'),
      );
      expect(
        checkoutUrlFromResponse({
          'data': {'url': 'https://checkout.stripe.com/c/2'},
        })?.host,
        'checkout.stripe.com',
      );
      expect(
        checkoutUrlFromResponse({'checkoutUrl': 'https://pay.example.com/x'}),
        Uri.parse('https://pay.example.com/x'),
      );
    });

    test('rechaza respuestas sin URL https', () {
      expect(checkoutUrlFromResponse(null), isNull);
      expect(checkoutUrlFromResponse({'data': 'cs_test_123'}), isNull);
      expect(
        checkoutUrlFromResponse({'data': 'http://checkout.stripe.com/c/1'}),
        isNull,
      );
    });
  });
}

class _RoutedClient implements ApiClient {
  _RoutedClient(this.routes);

  final Map<String, Object?> routes;
  final calls = <String>[];

  Future<dynamic> _respond(String path) async {
    calls.add(path);
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
  }) => _respond(path);

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _respond(path);

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _respond(path);

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) => _respond(path);
}
