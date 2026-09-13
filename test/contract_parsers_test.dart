import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/features/quotes/domain/client_quote.dart';
import 'package:app_yonke/features/quotes/domain/quote_message.dart';
import 'package:app_yonke/features/requests/domain/client_request.dart';
import 'package:app_yonke/features/yonke_coverage/data/yonke_coverage_repository.dart';
import 'package:app_yonke/features/yonke_profile/domain/yonke_profile.dart';
import 'package:app_yonke/features/yonke_quotes/domain/yonke_quote.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_requests_repository.dart';
import 'package:app_yonke/features/yonke_requests/domain/yonke_request_summary.dart';
import 'package:app_yonke/features/yonkes/data/yonkes_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parsers frente a los esquemas de docs/openapi_v1.json.
void main() {
  test('solicitudes acepta la paginación real data dentro de data', () {
    final requests = clientRequestSummariesFromResponse({
      'success': true,
      'data': {
        'data': [
          {
            'guidId': 'request-nested',
            'piezaBuscada': 'Espejo derecho',
            'totalCotizaciones': 1,
          },
        ],
        'meta': {'page': 1, 'itemCount': 1},
      },
    });

    expect(requests, hasLength(1));
    expect(requests.single.id, 'request-nested');
    expect(requests.single.quoteCount, 1);
  });

  test('ciudades acepta solicitudHeader del API real', () {
    final cities = requestCityNamesFromResponse({
      'data': {
        'solicitudHeader': {
          'ciudadesSaveBySolicitud': [
            {'ciudadId': 3, 'ciudad': 'Agua Prieta'},
            {'ciudadId': 2, 'ciudad': 'Hermosillo'},
          ],
        },
      },
    });

    expect(cities, ['Agua Prieta', 'Hermosillo']);
  });

  test('mis-cotizaciones acepta la proyección plana del API real', () {
    final quotes = clientQuotesFromDashboard({
      'data': [
        {
          'guidId': 'quote-flat',
          'solicitudYonkeGuidId': 'assignment-flat',
          'folio': 'SOL-00014/2026',
          'precio': 1500,
          'disponible': true,
          'esNueva': true,
          'tieneGarantia': false,
          'diasGarantia': 0,
          'envioDisponible': false,
          'activo': false,
        },
      ],
    });

    expect(quotes, hasLength(1));
    expect(quotes.single.id, 'quote-flat');
    expect(quotes.single.requestFolio, 'SOL-00014/2026');
    expect(quotes.single.price, 1500);
  });

  group('Solicitud_Busqueda_DTO', () {
    test('lee estatus y total de cotizaciones con sus nombres reales', () {
      final summary = clientRequestSummaryFromJson({
        'guidId': 'request-api',
        'piezaBuscada': 'Alternador',
        'marca': 'Nissan',
        'modelo': 'Sentra',
        'año': 2018,
        'estatusSolicitud': 'En proceso',
        'totalCotizaciones': 3,
        'folio': 'RF-100',
        'cerrada': false,
      });

      expect(summary, isNotNull);
      expect(summary!.title, 'Alternador\nNissan Sentra 2018');
      expect(summary.status, 'En proceso');
      expect(summary.quoteCount, 3);
      expect(summary.folio, 'RF-100');
      expect(summary.isInProgress, isTrue);
    });

    test('acepta la entidad Solicitudes con marcas y modelos anidados', () {
      final summary = clientRequestSummaryFromJson({
        'guidId': 'request-entity',
        'piezaBuscada': 'Radiador',
        'marcas': {'id': 1, 'marca': 'Toyota'},
        'modelos': {'id': 3, 'modelo': 'Corolla'},
        'año': 2016,
        'solicitudEstatus': {'estatus': 'Cerrada'},
        'cerrada': true,
        'solicitudYonkes': [
          {
            'solicitudCotizaciones': [
              {'guidId': 'q1'},
              {'guidId': 'q2'},
            ],
          },
        ],
      });

      expect(summary!.vehicle, 'Toyota Corolla 2016');
      expect(summary.status, 'Cerrada');
      expect(summary.quoteCount, 2);
      expect(summary.isInProgress, isFalse);
    });

    test('mi-solicitud-reciente acepta objeto o lista y vacío', () {
      expect(
        clientRequestSummaryFromResponse({
          'data': {'guidId': 'r1', 'piezaBuscada': 'Faro'},
        })?.id,
        'r1',
      );
      expect(
        clientRequestSummaryFromResponse({
          'data': [
            {'guidId': 'r2', 'piezaBuscada': 'Faro'},
          ],
        })?.id,
        'r2',
      );
      expect(clientRequestSummaryFromResponse({'data': null}), isNull);
      expect(clientRequestSummaryFromResponse({'data': []}), isNull);
    });

    test('el detalle toma urlImagen y las ciudades de la solicitud', () {
      final detail = clientRequestDetailFromResponses(
        requestResponse: {
          'data': {
            'guidId': 'request-api',
            'piezaBuscada': 'Alternador',
            'marca': 'Nissan',
            'modelo': 'Sentra',
            'año': 2018,
            'motor': '2.0 L',
            'transmicion': 'Automática',
            'descripcion': 'Original',
            'estatusSolicitud': 'En proceso',
            'totalCotizaciones': 1,
          },
        },
        imagesResponse: {
          'data': [
            {'guidId': 'i1', 'urlImagen': 'https://cdn.example.com/a.jpg'},
            {'guidId': 'i2', 'urlImagen': 'http://insecure.example.com/b.jpg'},
          ],
        },
        citiesResponse: {
          'data': [
            {
              'ciudadId': 1,
              'ciudades': {
                'id': 1,
                'ciudad': 'Nogales',
                'entidades': {'entidad': 'Sonora'},
              },
            },
          ],
        },
      );

      expect(detail, isNotNull);
      expect(detail!.imageUrls, ['https://cdn.example.com/a.jpg']);
      expect(detail.city, 'Nogales, Sonora');
      expect(detail.engine, '2.0 L');
      expect(detail.transmission, 'Automática');
      expect(detail.summary.quoteCount, 1);
    });
  });

  group('Bandeja del yonke (SolicitudYonkes)', () {
    test('interpreta registros SolicitudYonkes con la solicitud anidada', () {
      final items = yonkeAssignedRequestsFromResponse({
        'data': [
          {
            'guidId': 'assignment-1',
            'solicitudGuidId': 'request-1',
            'yonkeGuidId': 'yonke-1',
            'fechaEnvio': '2026-08-31T09:20:00Z',
            'fechaVista': null,
            'solicitudYonkesEstatus': {'estatusSolicitud': 'Enviada'},
            'solicitudCotizaciones': <Map<String, dynamic>>[],
            'solicitudes': {
              'guidId': 'request-1',
              'piezaBuscada': 'Alternador',
              'año': 2018,
              'folio': 'RF-001',
              'marcas': {'marca': 'Nissan'},
              'modelos': {'modelo': 'Sentra'},
              'solicitudesImagenes': [
                {'urlImagen': 'https://cdn.example.com/1.jpg'},
                {'urlImagen': 'https://cdn.example.com/2.jpg'},
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
          },
          {
            'guidId': 'assignment-2',
            'solicitudGuidId': 'request-2',
            'fechaEnvio': '2026-08-30T09:20:00Z',
            'fechaVista': '2026-08-30T10:00:00Z',
            'solicitudCotizaciones': [
              {'guidId': 'quote-2'},
            ],
            'solicitudes': {'piezaBuscada': 'Faro', 'año': 2016},
          },
        ],
      });

      expect(items, hasLength(2));
      final first = items!.first;
      expect(first.requestYonkeId, 'assignment-1');
      expect(first.requestId, 'request-1');
      expect(first.status, YonkeRequestStatus.newRequest);
      expect(first.vehicle, 'Nissan · Sentra · 2018');
      expect(first.city, 'Nogales, Sonora');
      expect(first.photoCount, 2);
      expect(items[1].status, YonkeRequestStatus.quoted);
      expect(items[1].hasQuote, isTrue);
    });

    test('acepta una proyección plana con solicitudYonkeGuidId', () {
      final items = yonkeAssignedRequestsFromResponse({
        'data': [
          {
            'solicitudYonkeGuidId': 'assignment-3',
            'guidId': 'request-3',
            'piezaBuscada': 'Radiador',
            'marca': 'Ford',
            'modelo': 'Ranger',
            'año': 2020,
            'estatusSolicitud': 'Vista',
            'fechaCreacion': '2026-08-29T14:10:00Z',
          },
        ],
      });

      expect(items!.single.requestYonkeId, 'assignment-3');
      expect(items.single.requestId, 'request-3');
      expect(items.single.status, YonkeRequestStatus.viewed);
    });

    test('acepta una proyección plana con solo guidId como en la API real', () {
      final items = yonkeAssignedRequestsFromResponse({
        'data': [
          {
            'guidId': 'request-x',
            'piezaBuscada': 'Faro',
            'marca': 'Nissan',
            'modelo': 'Altima',
            'folio': 'SOL-00003/2026',
          },
        ],
      });

      expect(items, hasLength(1));
      expect(items!.single.requestId, 'request-x');
      expect(items.single.requestYonkeId, 'request-x');
      expect(items.single.part, 'Faro');
    });

    test(
      'devuelve null cuando la forma no contiene identificadores válidos',
      () {
        expect(
          yonkeAssignedRequestsFromResponse({
            'data': [
              {'invalidKey': 'none'},
            ],
          }),
          isNull,
        );
        expect(yonkeAssignedRequestsFromResponse({'data': null}), isNull);
        expect(yonkeAssignedRequestsFromResponse({'data': []}), isEmpty);
      },
    );
  });

  group('SolicitudCotizacionMensajes', () {
    const records = {
      'data': [
        {
          'guidId': 'm-2',
          'usuarioId': 'yonke-user-7',
          'tipoRemitenteId': 2,
          'mensaje': 'Sí, con garantía.',
          'leido': false,
          'fechaCreacion': '2026-08-31T12:14:00Z',
        },
        {
          'guidId': 'm-1',
          'usuarioId': 'user-42',
          'tipoRemitenteId': 1,
          'mensaje': 'Hola, ¿incluye garantía?',
          'leido': true,
          'fechaCreacion': '2026-08-31T12:10:00Z',
        },
      ],
    };

    test('ordena por fecha y distingue remitente por usuarioId', () {
      final messages = quoteMessagesFromResponse(records);
      expect(messages.map((m) => m.id), ['m-1', 'm-2']);
      expect(
        messages.first.isFromClient(
          viewerUserId: 'user-42',
          viewerIsClient: true,
        ),
        isTrue,
      );
      expect(
        messages.last.isFromClient(
          viewerUserId: 'user-42',
          viewerIsClient: true,
        ),
        isFalse,
      );
      // Visto por el yonke: el mensaje ajeno es del cliente.
      expect(
        messages.first.isFromClient(
          viewerUserId: 'yonke-user-7',
          viewerIsClient: false,
        ),
        isTrue,
      );
    });

    test('sin usuario conocido usa tipoRemitenteId', () {
      final messages = quoteMessagesFromResponse(records);
      expect(
        messages.first.isFromClient(viewerUserId: null, viewerIsClient: true),
        isTrue,
      );
      expect(
        messages.last.isFromClient(viewerUserId: null, viewerIsClient: true),
        isFalse,
      );
    });
  });

  group('Yonkes, coberturas y cotizaciones del yonke', () {
    test('perfil desde Yonkes/{guidId} con la ciudad anidada', () {
      final profile = yonkeProfileFromResponse({
        'data': {
          'guidId': 'yonke-1',
          'nombre': 'Yonke Norte',
          'responsable': 'Rafael',
          'telefono': '6311234567',
          'correo': 'norte@ejemplo.com',
          'direccion': 'Av. Obregón 100',
          'cp': 84000,
          'ciudadId': 1,
          'logoUrl': 'https://cdn.example.com/logo.png',
          'ciudades': {
            'ciudad': 'Nogales',
            'entidades': {'entidad': 'Sonora'},
          },
        },
      });

      expect(profile!.name, 'Yonke Norte');
      expect(profile.city, 'Nogales, Sonora');
      expect(
        profile.fullAddress,
        'Av. Obregón 100 · C.P. 84000 · Nogales, Sonora',
      );
      expect(profile.logoUrl, 'https://cdn.example.com/logo.png');
    });

    test('la cobertura ignora registros inactivos y lee entidades.entidad', () {
      expect(
        coverageCityIdsFromResponse({
          'data': {
            'yunkeHeader': {
              'id': 3,
              'nombre': 'Yonke Test',
              'yunkeCoberturas': [
                {'ciudadId': 1, 'activo': true},
                {'ciudadId': 2, 'activo': false},
                {'ciudadId': 3, 'activo': true},
              ],
            },
          },
        }),
        {1, 3},
      );
      expect(
        coverageCityIdsFromResponse({
          'data': [
            {'ciudadId': 1, 'activo': true},
            {'ciudadId': 2, 'activo': false},
            {'ciudadId': 3},
          ],
        }),
        {1, 3},
      );
      final cities = coverageCitiesFromRecords([
        {
          'id': 1,
          'ciudad': 'Nogales',
          'entidades': {'entidad': 'Sonora'},
        },
        {'id': 2, 'ciudad': 'Mexicali'},
      ], stateName: 'Baja California');
      expect(cities.map((c) => c.state), ['Sonora', 'Baja California']);
    });

    test('la cotización del yonke lee marcas.marca y modelos.modelo', () {
      final quote = yonkeQuoteFromJson({
        'guidId': 'quote-api',
        'solicitudYonkeGuidId': 'assignment-api',
        'precio': 1850.0,
        'disponible': true,
        'activo': true,
        'fechaCreacion': '2026-08-31T11:25:00Z',
        'solicitudYonkes': {
          'solicitudGuidId': 'request-api',
          'solicitudes': {
            'piezaBuscada': 'Alternador',
            'año': 2018,
            'marcas': {'marca': 'Nissan'},
            'modelos': {'modelo': 'Sentra'},
          },
        },
      });

      expect(quote!.vehicle, 'Nissan · Sentra · 2018');
    });

    test('ActualizarLogo envía GuidId y el archivo como LogoUrl', () async {
      final client = _RecordingClient();
      await YonkesApi(client).updateLogo(
        yonkeId: 'yonke-1',
        logo: ApiFile(
          fieldName: 'ignored',
          fileName: 'logo.png',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      );

      expect(client.path, '/api/Yonkes/ActualizarLogo');
      expect(client.method, 'PUT');
      expect(client.fields, {'GuidId': 'yonke-1'});
      expect(client.files.single.fieldName, 'LogoUrl');
      expect(client.files.single.fileName, 'logo.png');
    });
  });
}

class _RecordingClient implements ApiClient {
  String? path;
  String? method;
  Map<String, dynamic>? fields;
  List<ApiFile> files = const [];

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) async {
    this.path = path;
    this.method = method;
    this.fields = fields;
    this.files = files;
    return null;
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) =>
      throw UnimplementedError();

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => throw UnimplementedError();

  @override
  Future<dynamic> put(
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
}
