// Datos de ejemplo para la auditoría responsive.
//
// Sustituye solo el cliente HTTP, la sesión guardada y el tiempo real. Todo
// lo demás (router, tema, pantallas, repositorios y parsers) es el código de
// producción, así que las capturas muestran la app tal como se ve con datos.
// Nada aquí sale a internet.

import 'dart:convert';

import 'package:app_yonke/app/app.dart';
import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/realtime/realtime_service.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/messages/presentation/client_conversation_page.dart';
import 'package:app_yonke/features/orders/domain/client_order_creation.dart';
import 'package:app_yonke/features/orders/presentation/client_order_pages.dart';
import 'package:app_yonke/features/quotes/domain/client_quote.dart';
import 'package:app_yonke/features/ratings/presentation/client_rating_page.dart';
import 'package:app_yonke/features/requests/domain/request_draft.dart';
import 'package:app_yonke/features/yonke_messages/domain/quote_client.dart';
import 'package:app_yonke/features/yonke_messages/presentation/yonke_messages_page.dart';
import 'package:app_yonke/features/yonke_quotes/domain/yonke_quote.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_request_detail_repository.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_requests_repository.dart';
import 'package:app_yonke/features/yonke_requests/presentation/yonke_quote_page.dart';
import 'package:app_yonke/features/yonkes/domain/client_yonke.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AuditRole { publico, cliente, yonke }

class AuditScreen {
  const AuditScreen({
    required this.id,
    required this.title,
    required this.role,
    required this.route,
    this.extra,
    this.storage = const {},
  });

  final String id;
  final String title;
  final AuditRole role;
  final String route;
  final Object? Function()? extra;

  /// Valores extra del almacenamiento seguro para esta pantalla.
  final Map<String, String> storage;
}

// --- Identidades -------------------------------------------------------------

const _clientUserId = 'cliente-001';
const _yonkeUserId = 'usuario-yonke-001';
const _yonkeId = 'yonke-001';

String _jwt(Map<String, Object?> claims) {
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'none', 'typ': 'JWT'})}.${part(claims)}.firma';
}

final _clientToken = _jwt({
  'sub': _clientUserId,
  'name': 'María Fernanda López',
  'email': 'mafer.lopez@correo.mx',
  'phone_number': '+526621234567',
  'role': 'Cliente',
  'exp': 4102444800,
});

final _yonkeToken = _jwt({
  'sub': _yonkeUserId,
  'name': 'Autopartes Usadas del Norte',
  'email': 'ventas@usadasdelnorte.mx',
  'role': 'Yonke',
  'yonkeGuidId': _yonkeId,
  'exp': 4102444800,
});

class AuditTokenStore implements TokenStore {
  AuditTokenStore(this.role);

  final AuditRole role;

  @override
  Future<String?> readAccessToken() async => switch (role) {
    AuditRole.publico => null,
    AuditRole.cliente => _clientToken,
    AuditRole.yonke => _yonkeToken,
  };

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<DateTime?> readExpiresAt() async =>
      role == AuditRole.publico ? null : DateTime.utc(2100);

  @override
  Future<String?> readYonkeGuidId() async =>
      role == AuditRole.yonke ? _yonkeId : null;

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

/// Tiempo real sin conexión: sin token nunca intenta abrir SignalR.
class _NoSessionTokenStore extends AuditTokenStore {
  _NoSessionTokenStore() : super(AuditRole.publico);
}

/// Perfil del cliente y bandeja local del yonke, guardados como los guarda la
/// app en el almacenamiento seguro. Se llama antes de cada captura.
void auditPrepareGlobals([Map<String, String> extra = const {}]) {
  FlutterSecureStorage.setMockInitialValues({
    ...extra,
    'client.profile.$_clientUserId': jsonEncode({
      'id': _clientUserId,
      'name': 'María Fernanda López',
      'email': 'mafer.lopez@correo.mx',
      'phone': '+52 662 123 4567',
      'city': 'Hermosillo, Sonora',
      'stateId': 26,
      'stateName': 'Sonora',
      'cityId': 2,
      'cityName': 'Hermosillo',
    }),
    'client.addresses.$_clientUserId': jsonEncode([
      {
        'label': 'Casa',
        'street': 'Blvd. Kino 1234, Col. Pitic',
        'city': 'Hermosillo, Sonora',
        'postalCode': '83150',
      },
      {
        'label': 'Taller',
        'street': 'Calle de los Mecánicos 45, Col. Industrial',
        'city': 'Hermosillo, Sonora',
        'postalCode': '83299',
      },
    ]),
    'yonke.quotes.$_yonkeId': jsonEncode(['cot-001', 'cot-004', 'cot-005']),
  });
}

/// La app completa con la sesión del rol y los datos de ejemplo.
Widget auditApp(AuditRole role, AuditApiClient api) => ProviderScope(
  overrides: [
    tokenStoreProvider.overrideWithValue(AuditTokenStore(role)),
    apiClientProvider.overrideWithValue(api),
    realtimeServiceProvider.overrideWithValue(
      RealtimeService(_NoSessionTokenStore()),
    ),
  ],
  child: const YonkeApp(),
);

// --- Respuestas simuladas ----------------------------------------------------

Map<String, dynamic> _ok(Object? data) => {
  'success': true,
  'message': 'OK',
  'data': data,
  'statusCode': 200,
  'errors': null,
};

const _states = [
  {'id': 26, 'entidad': 'Sonora', 'activo': true},
  {'id': 14, 'entidad': 'Jalisco', 'activo': true},
  {'id': 19, 'entidad': 'Nuevo León', 'activo': true},
  {'id': 2, 'entidad': 'Baja California', 'activo': true},
];

const _cities = <int, List<Map<String, Object>>>{
  26: [
    {'id': 1, 'ciudad': 'Nogales', 'entidadId': 26},
    {'id': 2, 'ciudad': 'Hermosillo', 'entidadId': 26},
    {'id': 3, 'ciudad': 'Ciudad Obregón', 'entidadId': 26},
    {'id': 4, 'ciudad': 'San Luis Río Colorado', 'entidadId': 26},
    {'id': 6, 'ciudad': 'Heroica Caborca', 'entidadId': 26},
  ],
  14: [
    {'id': 10, 'ciudad': 'Guadalajara', 'entidadId': 14},
    {'id': 11, 'ciudad': 'Zapopan', 'entidadId': 14},
    {'id': 12, 'ciudad': 'San Pedro Tlaquepaque', 'entidadId': 14},
  ],
  19: [
    {'id': 20, 'ciudad': 'Monterrey', 'entidadId': 19},
    {'id': 21, 'ciudad': 'San Nicolás de los Garza', 'entidadId': 19},
  ],
  2: [
    {'id': 5, 'ciudad': 'Mexicali', 'entidadId': 2},
    {'id': 7, 'ciudad': 'Tijuana', 'entidadId': 2},
  ],
};

List<Map<String, Object>> _citiesWithState(int stateId) {
  final state = _states.firstWhere((s) => s['id'] == stateId);
  return [
    for (final city in _cities[stateId] ?? const <Map<String, Object>>[])
      {
        ...city,
        'entidades': {'id': stateId, 'entidad': state['entidad']!},
      },
  ];
}

const _brands = [
  {'id': 1, 'marca': 'Nissan', 'activo': true},
  {'id': 2, 'marca': 'Toyota', 'activo': true},
  {'id': 3, 'marca': 'Chevrolet', 'activo': true},
  {'id': 4, 'marca': 'Honda', 'activo': true},
  {'id': 5, 'marca': 'Volkswagen', 'activo': true},
];

const _models = <int, List<Map<String, Object>>>{
  1: [
    {'id': 7, 'modelo': 'Sentra', 'marcaId': 1},
    {'id': 8, 'modelo': 'Versa', 'marcaId': 1},
    {'id': 9, 'modelo': 'Frontier NP300', 'marcaId': 1},
  ],
  2: [
    {'id': 12, 'modelo': 'Corolla', 'marcaId': 2},
    {'id': 13, 'modelo': 'Hilux', 'marcaId': 2},
  ],
  3: [
    {'id': 15, 'modelo': 'Silverado 1500', 'marcaId': 3},
    {'id': 16, 'modelo': 'Aveo', 'marcaId': 3},
  ],
  4: [
    {'id': 18, 'modelo': 'Civic', 'marcaId': 4},
    {'id': 19, 'modelo': 'CR-V', 'marcaId': 4},
  ],
  5: [
    {'id': 21, 'modelo': 'Jetta', 'marcaId': 5},
  ],
};

class _Request {
  const _Request(
    this.id,
    this.folio,
    this.part,
    this.brand,
    this.model,
    this.year,
    this.status,
    this.quotes, {
    this.description,
    this.cityId = 2,
    this.city = 'Hermosillo',
    this.state = 'Sonora',
    this.closed = false,
  });

  final String id;
  final String folio;
  final String part;
  final String brand;
  final String model;
  final int year;
  final String status;
  final int quotes;
  final String? description;
  final int cityId;
  final String city;
  final String state;
  final bool closed;

  Map<String, Object?> get json => {
    'guidId': id,
    'folio': folio,
    'piezaBuscada': part,
    'marcaId': _brands.firstWhere((b) => b['marca'] == brand)['id'],
    'marca': brand,
    'modelo': model,
    'año': year,
    'motor': '1.8 L 4 cilindros',
    'transmicion': 'Automática',
    'numeroParte': null,
    'descripcion': description,
    'estatusSolicitud': status,
    'totalCotizaciones': quotes,
    'cerrada': closed,
    'fechaCreacion': '2026-09-28T16:20:00Z',
  };
}

const _requests = [
  _Request(
    'sol-001',
    'SOL-00041/2026',
    'Faro delantero izquierdo',
    'Nissan',
    'Sentra',
    2019,
    'Cotizada',
    3,
    description: 'Con base y conector completos, sin micas rotas.',
  ),
  _Request(
    'sol-002',
    'SOL-00040/2026',
    'Módulo de control electrónico de transmisión automática CVT',
    'Nissan',
    'Versa',
    2018,
    'En proceso',
    1,
    description:
        'La transmisión se queda en modo de emergencia. Busco el módulo '
        'original con número de parte compatible.',
  ),
  _Request(
    'sol-003',
    'SOL-00038/2026',
    'Alternador',
    'Chevrolet',
    'Silverado 1500',
    2017,
    'En proceso',
    0,
  ),
  _Request(
    'sol-004',
    'SOL-00031/2026',
    'Espejo lateral derecho eléctrico',
    'Honda',
    'Civic',
    2021,
    'Cerrada',
    2,
    closed: true,
  ),
  _Request(
    'sol-005',
    'SOL-00027/2026',
    'Bomba de gasolina',
    'Toyota',
    'Corolla',
    2016,
    'En proceso',
    1,
    cityId: 10,
    city: 'Guadalajara',
    state: 'Jalisco',
  ),
];

_Request _request(String id) =>
    _requests.firstWhere((r) => r.id == id, orElse: () => _requests.first);

class _Yonke {
  const _Yonke(
    this.id,
    this.name,
    this.owner,
    this.phone,
    this.city,
    this.cityId,
    this.state,
    this.rating,
    this.ratings,
  );

  final String id;
  final String name;
  final String owner;
  final String phone;
  final String city;
  final int cityId;
  final String state;
  final double rating;
  final int ratings;

  Map<String, Object?> get json => {
    'guidId': id,
    'nombre': name,
    'responsable': owner,
    'telefono': phone,
    'correo': 'contacto@${id.replaceAll('-', '')}.mx',
    'direccion': 'Carretera a Bahía de Kino km 7.5, Parque Industrial',
    'cp': 83220,
    'ciudadId': cityId,
    'autorizado': true,
    'activo': true,
    'promedioCalificacion': rating,
    'totalCalificaciones': ratings,
    'ciudades': {
      'id': cityId,
      'ciudad': city,
      'entidades': {'entidad': state},
    },
  };
}

const _yonkes = [
  _Yonke(
    _yonkeId,
    'Autopartes Usadas del Norte',
    'Rafael Gámez',
    '6621234567',
    'Hermosillo',
    2,
    'Sonora',
    4.7,
    38,
  ),
  _Yonke(
    'yonke-002',
    'Yonke El Güero',
    'José Luis Ramírez',
    '6311098765',
    'Nogales',
    1,
    'Sonora',
    4.2,
    15,
  ),
  _Yonke(
    'yonke-003',
    'Deshuesadero y Refaccionaria Hermanos Villarreal de Ciudad Obregón',
    'Martín Villarreal',
    '6441122334',
    'Ciudad Obregón',
    3,
    'Sonora',
    3.9,
    7,
  ),
  _Yonke(
    'yonke-004',
    'Recicladora Automotriz Tapatía',
    'Guadalupe Hernández',
    '3312345678',
    'Guadalajara',
    10,
    'Jalisco',
    4.9,
    102,
  ),
  _Yonke(
    'yonke-005',
    'Partes Seminuevas Monterrey',
    'Óscar Treviño',
    '8187654321',
    'Monterrey',
    20,
    'Nuevo León',
    0,
    0,
  ),
];

_Yonke _yonke(String id) =>
    _yonkes.firstWhere((y) => y.id == id, orElse: () => _yonkes.first);

class _Quote {
  const _Quote(
    this.id,
    this.requestId,
    this.yonkeId,
    this.price, {
    this.isNew = false,
    this.warrantyDays = 30,
    this.shipping = 150,
    this.days = 2,
    this.status = 'Enviada',
    this.comments = 'Pieza original desmontada de unidad chocada de atrás. '
        'Probada antes de enviar.',
  });

  final String id;
  final String requestId;
  final String yonkeId;
  final double price;
  final bool isNew;
  final int warrantyDays;
  final double? shipping;
  final int days;
  final String status;
  final String comments;

  String get requestYonkeId => 'sy-${requestId.substring(4)}-${yonkeId.substring(6)}';

  Map<String, Object?> get json {
    final request = _request(requestId);
    final yonke = _yonke(yonkeId);
    return {
      'guidId': id,
      'solicitudYonkeGuidId': requestYonkeId,
      'solicitudGuidId': requestId,
      'folio': request.folio,
      'fechaCreacion': '2026-09-29T15:40:00Z',
      'precio': price,
      'disponible': true,
      'esNueva': isNew,
      'tieneGarantia': warrantyDays > 0,
      'diasGarantia': warrantyDays,
      'envioDisponible': shipping != null,
      'costoEnvio': shipping ?? 0,
      'tiempoEntregaDias': days,
      'comentarios': comments,
      'activo': true,
      'solicitudCotizacionEstatus': {'descripcion': status},
      'solicitudCotizacionesImagenes': const <Map<String, Object>>[],
      'solicitudYonkes': {
        'guidId': requestYonkeId,
        'solicitudGuidId': requestId,
        'yonkeGuidId': yonkeId,
        'yonkes': {'nombre': yonke.name, 'telefono': yonke.phone},
        'solicitudes': {
          'guidId': requestId,
          'folio': request.folio,
          'piezaBuscada': request.part,
          'año': request.year,
          'marcas': {'marca': request.brand},
          'modelos': {'modelo': request.model},
          'descripcion': request.description,
        },
      },
    };
  }
}

const _quotes = [
  _Quote('cot-001', 'sol-001', _yonkeId, 1850),
  _Quote(
    'cot-002',
    'sol-001',
    'yonke-003',
    1490,
    warrantyDays: 0,
    shipping: null,
    days: 4,
    comments: 'Tiene un pequeño rayón en la mica, funciona al 100%.',
  ),
  _Quote(
    'cot-003',
    'sol-001',
    'yonke-004',
    3250,
    isNew: true,
    warrantyDays: 90,
    shipping: 0,
    days: 1,
  ),
  _Quote('cot-004', 'sol-002', _yonkeId, 12800, warrantyDays: 60, days: 5),
  _Quote('cot-005', 'sol-005', _yonkeId, 2100, status: 'Aceptada'),
];

_Quote _quote(String id) =>
    _quotes.firstWhere((q) => q.id == id, orElse: () => _quotes.first);

List<Map<String, Object?>> _messages(String quoteId) {
  final mine = _clientUserId;
  final yonke = _yonkeUserId;
  Map<String, Object?> m(
    int n,
    String user,
    int type,
    String text,
    String time,
  ) => {
    'guidId': '$quoteId-m$n',
    'usuarioId': user,
    'tipoRemitenteId': type,
    'mensaje': text,
    'leido': true,
    'fechaCreacion': '2026-09-29T$time:00Z',
  };
  return [
    m(1, mine, 1, 'Hola, ¿el faro incluye la base y el conector?', '16:02'),
    m(2, yonke, 2, 'Sí, viene completo con base, conector y focos.', '16:05'),
    m(
      3,
      mine,
      1,
      'Perfecto. ¿Me lo pueden enviar a Hermosillo mañana? Necesito la '
          'unidad lista para el viernes porque es de trabajo.',
      '16:07',
    ),
    m(4, yonke, 2, 'Claro, sale hoy por paquetería y llega mañana.', '16:10'),
    m(5, mine, 1, 'Excelente, muchas gracias.', '16:11'),
  ];
}

List<Map<String, Object?>> _ratings(String yonkeId) => [
  {
    'calificacion': 5,
    'comentario': 'Muy atentos, la pieza llegó igual que en las fotos.',
    'activa': true,
    'fechaCreacion': '2026-09-20T12:00:00Z',
  },
  {
    'calificacion': 4,
    'comentario':
        'Buen precio. El envío tardó un día más de lo prometido pero me '
        'avisaron a tiempo y todo llegó bien empacado.',
    'activa': true,
    'fechaCreacion': '2026-09-11T12:00:00Z',
  },
  {
    'calificacion': 5,
    'comentario': 'Recomendados.',
    'activa': true,
    'fechaCreacion': '2026-08-30T12:00:00Z',
  },
];

Map<String, Object?> _assignment(_Request request, int index) => {
  'guidId': 'sy-${request.id.substring(4)}-001',
  'solicitudYonkeGuidId': 'sy-${request.id.substring(4)}-001',
  'solicitudGuidId': request.id,
  'yonkeGuidId': _yonkeId,
  'folio': request.folio,
  'piezaBuscada': request.part,
  'marca': request.brand,
  'modelo': request.model,
  'año': request.year,
  'fechaEnvio': '2026-09-${29 - index}T1${index}:15:00Z',
  'estatus': index == 0
      ? 'Enviada'
      : index == 3
      ? 'Cotizada'
      : 'Vista',
  'vista': index != 0,
  'cotizaciones': index == 3 ? 1 : 0,
  'imagenes': const <Map<String, Object>>[],
  'ciudades': [
    {'ciudad': request.city, 'entidad': request.state},
  ],
  'solicitudes': {
    'guidId': request.id,
    'piezaBuscada': request.part,
    'año': request.year,
    'folio': request.folio,
    'marcas': {'marca': request.brand},
    'modelos': {'modelo': request.model},
    'solicitudesCiudades': [
      {
        'ciudades': {
          'ciudad': request.city,
          'entidades': {'entidad': request.state},
        },
      },
    ],
  },
};

/// Cliente HTTP simulado. Responde por método y ruta; lo que no reconoce lo
/// anota en [missing] y responde 404 como el API real.
class AuditApiClient implements ApiClient {
  AuditApiClient(this.role);

  final AuditRole role;
  final List<String> missing = [];
  final List<String> calls = [];

  Object? _respond(String method, String path, Map<String, dynamic>? query) {
    final segments = Uri.parse(path).pathSegments;
    String seg(int i) => i < segments.length ? segments[i] : '';
    final area = seg(1);

    if (method != 'GET') {
      // Acciones al abrir pantallas: marcar como vista o leído, registrar el
      // dispositivo. Se aceptan sin cambiar nada.
      return _ok(true);
    }

    switch (area) {
      case 'Utilerias':
        if (seg(2) == 'entidades') return _ok(_states);
        if (seg(2) == 'entidad' && seg(4) == 'ciudades') {
          return _ok(_citiesWithState(int.tryParse(seg(3)) ?? 26));
        }
        if (seg(2) == 'marcas') return _ok(_brands);
        if (seg(2) == 'modelos') {
          final brand = int.tryParse('${query?['marcaId'] ?? ''}');
          return _ok(
            brand == null
                ? [for (final list in _models.values) ...list]
                : _models[brand] ?? const [],
          );
        }
        if (seg(2) == 'ciudad') {
          final id = int.tryParse(seg(3));
          for (final entry in _cities.keys) {
            for (final city in _citiesWithState(entry)) {
              if (city['id'] == id) return _ok(city);
            }
          }
        }
      case 'DashboardSuscriptores':
        switch (seg(2)) {
          case 'mis-solicitudes':
            return _ok({
              'data': [for (final r in _requests) r.json],
              'meta': {'page': 1, 'pageCount': 1, 'itemCount': 5},
            });
          case 'mi-solicitud-reciente':
            return _ok(_requests.first.json);
          case 'mis-cotizaciones':
            final own = role == AuditRole.yonke
                ? _quotes.where((q) => q.yonkeId == _yonkeId)
                : _quotes;
            return _ok([for (final q in own) q.json]);
          case 'resumen':
            return _ok({
              'totalSolicitudes': 5,
              'totalCotizaciones': 7,
              'solicitudesAbiertas': 3,
            });
        }
      case 'Solicitudes':
        if (seg(2) == 'AllPaged') {
          return _ok({
            'data': [for (final r in _requests) r.json],
            'meta': {'page': 1, 'pageCount': 1},
          });
        }
        return _ok(_request(seg(2)).json);
      case 'SolicitudesImagenes':
        return _ok(const <Map<String, Object>>[]);
      case 'SolicitudCiudades':
        if (seg(3) == 'ciudades') {
          final request = _request(seg(2));
          return _ok([
            {
              'ciudadId': request.cityId,
              'ciudades': {
                'id': request.cityId,
                'ciudad': request.city,
                'entidades': {'entidad': request.state},
              },
            },
          ]);
        }
        if (seg(2) == 'existe') return _ok(true);
      case 'SolicitudYonkes':
        switch (seg(2)) {
          case 'MisSolicitudes':
            return _ok([
              for (var i = 0; i < _requests.length; i++)
                _assignment(_requests[i], i),
            ]);
          case 'TotalSolicitudesNuevas':
            return _ok(3);
          case 'MasReciente':
            return _ok(_assignment(_requests.first, 0));
        }
      case 'CotizacionYonke':
        if (seg(2) == 'MisCotizaciones') return _ok(12);
        return _ok(_quote(seg(2)).json);
      case 'SolicitudCotizacionMensajes':
        if (seg(3) == 'no-leidos') return _ok(1);
        return _ok(_messages(seg(2)));
      case 'Orden':
        if (seg(2) == 'cotizacion') {
          if (seg(3) == 'cot-005') {
            return _ok({
              'guidId': 'ord-001',
              'cotizacionGuidId': 'cot-005',
              'fechaCreacion': '2026-09-29T18:00:00Z',
              'ordenEstatus': {'descripcion': 'En camino'},
              'puedeCancelar': false,
              'activo': true,
            });
          }
          throw const ApiException(message: 'Sin orden', statusCode: 404);
        }
        return _ok({
          'guidId': seg(2),
          'cotizacionGuidId': 'cot-005',
          'fechaCreacion': '2026-09-29T18:00:00Z',
          'ordenEstatus': {'descripcion': 'En camino'},
          'puedeCancelar': false,
          'activo': true,
        });
      case 'Yonkes':
        if (seg(2) == 'byPage') {
          return _ok({
            'data': [for (final y in _yonkes) y.json],
            'meta': {'page': 1, 'pageCount': 1, 'itemCount': _yonkes.length},
          });
        }
        return _ok(_yonke(seg(2)).json);
      case 'YonkesCalificaciones':
        return _ok(_ratings(seg(2)));
      case 'YonkesCoberturas':
        return _ok([
          {'ciudadId': 1, 'activo': true},
          {'ciudadId': 2, 'activo': true},
          {'ciudadId': 3, 'activo': true},
          {'ciudadId': 4, 'activo': false},
        ]);
    }
    return null;
  }

  Future<dynamic> _handle(
    String method,
    String path,
    Map<String, dynamic>? query,
  ) async {
    final key = '$method $path';
    calls.add(key);
    final result = _respond(method, path, query);
    if (result == null) {
      missing.add(key);
      throw ApiException(
        message: 'Sin respuesta simulada para $key',
        statusCode: 404,
      );
    }
    return result;
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _handle('GET', path, queryParameters);

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _handle('POST', path, queryParameters);

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _handle('PUT', path, queryParameters);

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _handle('DELETE', path, queryParameters);

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) => _handle(method, path, queryParameters);
}

// --- Argumentos de las rutas -------------------------------------------------

ClientQuote _clientQuote(String id) => clientQuoteFromJson(_quote(id).json)!;

YonkeQuote _yonkeQuote(String id) => yonkeQuoteFromJson(_quote(id).json)!;

RequestDraft _draft() => RequestDraft()
  ..part = 'Faro delantero izquierdo'
  ..brandId = 1
  ..brandName = 'Nissan'
  ..modelId = 7
  ..modelName = 'Sentra'
  ..year = 2019
  ..description = 'Con base y conector completos, sin micas rotas.'
  ..cityId = 2
  ..cityName = 'Hermosillo, Sonora';

Object? _yonkeRequestDetailArgs() {
  final summary = yonkeRequestSummaryFromJson(_assignment(_requests[1], 1));
  final detail = yonkeRequestDetailFromResponses(
    requestResponse: _ok(_requests[1].json),
    imagesResponse: _ok(const <Map<String, Object>>[]),
    requestYonkeId: summary?.requestYonkeId ?? 'sy-002-001',
    summary: summary,
  )!;
  return YonkeQuotePageArgs(detail: detail);
}

/// Todas las rutas del router, en el orden en que un usuario las recorre.
List<AuditScreen> auditScreens() => [
  const AuditScreen(
    id: 'inicio',
    title: 'Pantalla de bienvenida',
    role: AuditRole.publico,
    route: '/',
  ),
  const AuditScreen(
    id: 'cliente-login-aviso',
    title: 'Login del cliente: aviso legal',
    role: AuditRole.publico,
    route: '/cliente/login',
  ),
  const AuditScreen(
    id: 'cliente-login',
    title: 'Login del cliente (SMS)',
    role: AuditRole.publico,
    route: '/cliente/login',
    storage: {'client_legal_consent_version': '2026-08-26'},
  ),
  const AuditScreen(
    id: 'yonke-login',
    title: 'Login del yonke',
    role: AuditRole.publico,
    route: '/yonke/login',
  ),
  const AuditScreen(
    id: 'yonke-registro',
    title: 'Registro de yonke',
    role: AuditRole.publico,
    route: '/yonke/registro',
  ),
  const AuditScreen(
    id: 'cliente-inicio',
    title: 'Inicio del cliente',
    role: AuditRole.cliente,
    route: '/cliente',
  ),
  const AuditScreen(
    id: 'cliente-registro',
    title: 'Completar perfil (cliente nuevo)',
    role: AuditRole.cliente,
    route: '/cliente/registro',
  ),
  const AuditScreen(
    id: 'cliente-buscar',
    title: 'Buscar autopartes',
    role: AuditRole.cliente,
    route: '/cliente/buscar',
  ),
  const AuditScreen(
    id: 'cliente-nueva-solicitud',
    title: 'Nueva solicitud: pieza',
    role: AuditRole.cliente,
    route: '/cliente/solicitudes/nueva',
  ),
  AuditScreen(
    id: 'cliente-solicitud-fotos',
    title: 'Nueva solicitud: fotografías',
    role: AuditRole.cliente,
    route: '/cliente/solicitudes/fotografias',
    extra: _draft,
  ),
  AuditScreen(
    id: 'cliente-solicitud-ciudad',
    title: 'Nueva solicitud: ciudad',
    role: AuditRole.cliente,
    route: '/cliente/solicitudes/ciudad',
    extra: _draft,
  ),
  AuditScreen(
    id: 'cliente-solicitud-revision',
    title: 'Nueva solicitud: revisión',
    role: AuditRole.cliente,
    route: '/cliente/solicitudes/revision',
    extra: _draft,
  ),
  const AuditScreen(
    id: 'cliente-mis-solicitudes',
    title: 'Mis solicitudes',
    role: AuditRole.cliente,
    route: '/cliente/solicitudes',
  ),
  const AuditScreen(
    id: 'cliente-detalle-solicitud',
    title: 'Detalle de solicitud',
    role: AuditRole.cliente,
    route: '/cliente/solicitudes/detalle/sol-001',
  ),
  AuditScreen(
    id: 'cliente-cotizaciones-solicitud',
    title: 'Cotizaciones de una solicitud',
    role: AuditRole.cliente,
    route: '/cliente/solicitudes/detalle/sol-001/cotizaciones',
    extra: () => {'title': 'Faro delantero izquierdo', 'folio': 'SOL-00041/2026'},
  ),
  const AuditScreen(
    id: 'cliente-cotizaciones',
    title: 'Cotizaciones recibidas',
    role: AuditRole.cliente,
    route: '/cliente/cotizaciones',
  ),
  AuditScreen(
    id: 'cliente-detalle-cotizacion',
    title: 'Detalle de cotización',
    role: AuditRole.cliente,
    route: '/cliente/cotizaciones/cot-001',
    extra: () => _clientQuote('cot-001'),
  ),
  AuditScreen(
    id: 'cliente-chat',
    title: 'Chat con el yonke',
    role: AuditRole.cliente,
    route: '/cliente/cotizaciones/cot-001/mensajes',
    extra: () => ClientConversationArgs(quote: _clientQuote('cot-001')),
  ),
  AuditScreen(
    id: 'cliente-confirmar-orden',
    title: 'Confirmar orden',
    role: AuditRole.cliente,
    route: '/cliente/cotizaciones/cot-001/orden',
    extra: () => ClientOrderConfirmationArgs(quote: _clientQuote('cot-001')),
  ),
  AuditScreen(
    id: 'cliente-orden-exito',
    title: 'Orden creada',
    role: AuditRole.cliente,
    route: '/cliente/ordenes/exito',
    extra: () => ClientOrderSuccessArgs(
      quote: _clientQuote('cot-005'),
      result: const ClientOrderCreationResult(
        orderId: 'ord-001',
        responseContractPending: false,
      ),
    ),
  ),
  AuditScreen(
    id: 'cliente-seguimiento-orden',
    title: 'Seguimiento de orden',
    role: AuditRole.cliente,
    route: '/cliente/cotizaciones/cot-005/orden/seguimiento',
    extra: () =>
        ClientOrderTrackingArgs(quote: _clientQuote('cot-005'), orderId: 'ord-001'),
  ),
  AuditScreen(
    id: 'cliente-calificar',
    title: 'Calificar al yonke',
    role: AuditRole.cliente,
    route: '/cliente/cotizaciones/cot-005/calificacion',
    extra: () => ClientRatingArgs(quote: _clientQuote('cot-005')),
  ),
  const AuditScreen(
    id: 'cliente-mensajes',
    title: 'Mensajes del cliente',
    role: AuditRole.cliente,
    route: '/cliente/mensajes',
  ),
  const AuditScreen(
    id: 'cliente-notificaciones',
    title: 'Notificaciones del cliente',
    role: AuditRole.cliente,
    route: '/cliente/notificaciones',
  ),
  const AuditScreen(
    id: 'cliente-yonkes',
    title: 'Directorio de yonkes',
    role: AuditRole.cliente,
    route: '/cliente/yonkes',
  ),
  AuditScreen(
    id: 'cliente-perfil-yonke',
    title: 'Perfil de un yonke',
    role: AuditRole.cliente,
    route: '/cliente/yonkes/yonke-003',
    extra: () => clientYonkeFromJson(_yonke('yonke-003').json)!,
  ),
  const AuditScreen(
    id: 'cliente-perfil',
    title: 'Perfil del cliente',
    role: AuditRole.cliente,
    route: '/cliente/perfil',
  ),
  const AuditScreen(
    id: 'yonke-inicio',
    title: 'Inicio del yonke',
    role: AuditRole.yonke,
    route: '/yonke',
  ),
  const AuditScreen(
    id: 'yonke-solicitudes',
    title: 'Bandeja de solicitudes',
    role: AuditRole.yonke,
    route: '/yonke/solicitudes',
  ),
  AuditScreen(
    id: 'yonke-detalle-solicitud',
    title: 'Detalle de solicitud (yonke)',
    role: AuditRole.yonke,
    route: '/yonke/solicitudes/sy-002-001',
    extra: () => yonkeRequestSummaryFromJson(_assignment(_requests[1], 1)),
  ),
  AuditScreen(
    id: 'yonke-cotizar',
    title: 'Enviar cotización',
    role: AuditRole.yonke,
    route: '/yonke/solicitudes/sy-002-001/cotizar',
    extra: _yonkeRequestDetailArgs,
  ),
  const AuditScreen(
    id: 'yonke-cotizaciones',
    title: 'Mis cotizaciones (yonke)',
    role: AuditRole.yonke,
    route: '/yonke/cotizaciones',
  ),
  AuditScreen(
    id: 'yonke-detalle-cotizacion',
    title: 'Detalle de cotización (yonke)',
    role: AuditRole.yonke,
    route: '/yonke/cotizaciones/cot-004',
    extra: () => _yonkeQuote('cot-004'),
  ),
  const AuditScreen(
    id: 'yonke-mensajes',
    title: 'Mensajes del yonke',
    role: AuditRole.yonke,
    route: '/yonke/mensajes',
  ),
  AuditScreen(
    id: 'yonke-chat',
    title: 'Chat con el cliente',
    role: AuditRole.yonke,
    route: '/yonke/mensajes/cot-001',
    extra: () => YonkeConversationArgs(
      quote: _yonkeQuote('cot-001'),
      client: const QuoteClient(
        name: 'María Fernanda López',
        phone: '+52 662 123 4567',
      ),
    ),
  ),
  const AuditScreen(
    id: 'yonke-notificaciones',
    title: 'Notificaciones del yonke',
    role: AuditRole.yonke,
    route: '/yonke/notificaciones',
  ),
  const AuditScreen(
    id: 'yonke-perfil',
    title: 'Perfil del yonke',
    role: AuditRole.yonke,
    route: '/yonke/perfil',
  ),
  const AuditScreen(
    id: 'yonke-cobertura',
    title: 'Zona de cobertura',
    role: AuditRole.yonke,
    route: '/yonke/cobertura',
  ),
];
