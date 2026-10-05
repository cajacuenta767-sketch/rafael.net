import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_endpoints.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/features/quotes/data/quotes_api.dart';
import 'package:app_yonke/features/yonke_quotes/domain/yonke_quote.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('solicita cotizaciones propias con paginación y búsqueda', () async {
    final client = _RecordingClient();
    await QuotesApi(client)
        .getYonkeQuotes(page: 3, pageSize: 25, search: 'faro');

    expect(client.path, ApiEndpoints.yonkeQuotes);
    expect(client.query, {
      'Page': 3,
      'CantidadRegistrosPorPagina': 25,
      'Search': 'faro',
    });
  });

  test('interpreta metadatos SQL para permitir siguiente página', () {
    final result = yonkeQuotesPageFromResponse({
      'data': {
        'data': <dynamic>[],
        'meta': {'page': 2, 'take': 20, 'itemCount': 45, 'pageCount': 3},
      },
    });

    expect(result?.page, 2);
    expect(result?.hasMore, isTrue);
  });
}

class _RecordingClient implements ApiClient {
  String? path;
  Map<String, dynamic>? query;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    this.path = path;
    query = queryParameters;
    return {
      'data': {
        'data': <dynamic>[],
        'meta': {'page': 3, 'pageCount': 3},
      },
    };
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => null;
  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => null;
  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => null;
  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) async => null;
}
