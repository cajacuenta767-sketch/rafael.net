import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/features/requests/data/requests_api.dart';
import 'package:app_yonke/features/yonke_home/presentation/yonke_home_page.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_requests_repository.dart';
import 'package:app_yonke/features/yonke_requests/domain/yonke_request_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rutas agregadas al contrato V1: `SolicitudYonkes/MisSolicitudes`
/// y `CotizacionYonke/MisCotizaciones/Total`.
void main() {
  Map<String, dynamic> assignment(String id, String part, String date) => {
    'guidId': 'assignment-$id',
    'solicitudGuidId': 'request-$id',
    'fechaEnvio': date,
    'solicitudes': {'guidId': 'request-$id', 'piezaBuscada': part},
  };

  ApiYonkeRequestsRepository repositoryFor(_RoutedClient client) =>
      ApiYonkeRequestsRepository(RequestsApi(client));

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

    test('no recurre al dashboard del cliente: propaga el error', () async {
      const forbidden = ApiException(message: 'Prohibido', statusCode: 403);
      final client = _RoutedClient({
        '/api/SolicitudYonkes/MisSolicitudes': forbidden,
      });

      await expectLater(
        repositoryFor(client).getAssignedRequests(page: 1, pageSize: 20),
        throwsA(isA<ApiException>()),
      );
      expect(client.calls, ['/api/SolicitudYonkes/MisSolicitudes']);
    });

    test('una respuesta con otra forma es contrato pendiente', () async {
      final client = _RoutedClient({
        '/api/SolicitudYonkes/MisSolicitudes': {
          'data': [
            {'otro': 'campo'},
          ],
        },
      });

      await expectLater(
        repositoryFor(client).getAssignedRequests(page: 1, pageSize: 20),
        throwsA(isA<AssignedRequestsEndpointPendingException>()),
      );
    });
  });

  test('MisSolicitudes lee SolicitudYonke_List_DTO del Swagger publicado', () {
    final items = yonkeAssignedRequestsFromResponse({
      'success': true,
      'data': [
        {
          'solicitudYonkeGuidId': 'asignacion-1',
          'solicitudGuidId': 'solicitud-1',
          'folio': 'SOL-202609-0001',
          'piezaBuscada': 'Alternador',
          'numeroParte': 'S/N',
          'fechaSolicitud': '2026-09-25T10:00:00Z',
          'fechaEnvio': '2026-09-25T10:05:00Z',
          'estatusId': 2,
          'estatus': 'Vista',
          'vista': true,
          'fechaVista': '2026-09-25T11:00:00Z',
          'cotizaciones': 1,
          'imagenes': [
            {'guidId': 'img-1', 'url': 'https://blob.example.com/1.jpg'},
          ],
          'ciudades': [
            {'ciudadId': 12, 'ciudad': 'Hermosillo'},
          ],
        },
      ],
    })!;

    final item = items.single;
    expect(item.requestYonkeId, 'asignacion-1');
    expect(item.requestId, 'solicitud-1');
    expect(item.folio, 'SOL-202609-0001');
    expect(item.hasQuote, isTrue);
    expect(item.status, YonkeRequestStatus.quoted);
    expect(item.photoCount, 1);
    expect(item.imageUrl, 'https://blob.example.com/1.jpg');
    expect(item.city, 'Hermosillo');
  });

  test('MisSolicitudes sin cotizar y vista queda como vista', () {
    final item = yonkeAssignedRequestsFromResponse({
      'data': [
        {
          'solicitudYonkeGuidId': 'a',
          'solicitudGuidId': 's',
          'piezaBuscada': 'Marcha',
          'fechaEnvio': '2026-09-25T10:05:00Z',
          'estatus': 'Enviada',
          'vista': true,
          'cotizaciones': 0,
        },
      ],
    })!.single;

    expect(item.hasQuote, isFalse);
    expect(item.status, YonkeRequestStatus.viewed);
  });

  test('total de cotizaciones lee Int32ApiResponseGlobal', () {
    expect(quoteTotalFromResponse({'success': true, 'data': 7}), 7);
    expect(quoteTotalFromResponse({'data': '12'}), 12);
    expect(quoteTotalFromResponse({'data': null}), isNull);
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
