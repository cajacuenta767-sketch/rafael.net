import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../storage/token_store.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_file.dart';

/// Mercado local compartido por Cliente y Yonke cuando se usan los accesos de
/// prueba. Las mismas solicitudes y cotizaciones viajan por los repositorios
/// normales, por lo que ambas experiencias permanecen enlazadas.
class DevelopmentApiClient implements ApiClient {
  DevelopmentApiClient(this._remote, this._tokens);

  final ApiClient _remote;
  final TokenStore _tokens;
  static final _DevelopmentMarketplace _sharedMarketplace =
      _DevelopmentMarketplace();
  final _DevelopmentMarketplace _marketplace = _sharedMarketplace;

  Future<String?> get _role async {
    if (!kDebugMode) return null;
    return switch (await _tokens.readAccessToken()) {
      'development-client-session' => 'client',
      'development-yonke-session' => 'yonke',
      _ => null,
    };
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final role = await _role;
    if (role == null) {
      return _remote.get(path, queryParameters: queryParameters);
    }
    return _marketplace.get(path, role: role, query: queryParameters);
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final role = await _role;
    if (role == null) {
      return _remote.post(path, data: data, queryParameters: queryParameters);
    }
    return _marketplace.post(
      path,
      role: role,
      data: data,
      query: queryParameters,
    );
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final role = await _role;
    if (role == null) {
      return _remote.put(path, data: data, queryParameters: queryParameters);
    }
    return _marketplace.put(path, role: role, data: data);
  }

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final role = await _role;
    if (role == null) {
      return _remote.delete(path, data: data, queryParameters: queryParameters);
    }
    return _marketplace.delete(path);
  }

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) async {
    final role = await _role;
    if (role == null) {
      return _remote.multipart(
        path,
        method: method,
        fields: fields,
        files: files,
        queryParameters: queryParameters,
      );
    }
    return _marketplace.multipart(
      path,
      fields: fields ?? const {},
      files: files,
      query: queryParameters,
    );
  }
}

class _DevelopmentMarketplace {
  _DevelopmentMarketplace() {
    _requests.addAll([
      _request(
        'demo-request-1',
        'Alternador',
        'Nissan',
        'Sentra',
        2018,
        'SOL-001/2026',
        1,
      ),
      _request(
        'demo-request-2',
        'Compresor A/C',
        'Chevrolet',
        'Aveo',
        2016,
        'SOL-002/2026',
        0,
      ),
      _request(
        'demo-request-3',
        'Transmisión automática',
        'Honda',
        'Civic',
        2015,
        'SOL-003/2026',
        1,
      ),
      _request(
        'demo-request-4',
        'Motor de arranque',
        'Toyota',
        'Corolla',
        2015,
        'SOL-004/2026',
        1,
      ),
    ]);
    _quotes.addAll([
      _quote('demo-quote-1', _requests[0], 1850, 'Enviada'),
      _quote('demo-quote-2', _requests[2], 3800, 'Aceptada'),
      _quote('demo-quote-3', _requests[3], 2400, 'Vista'),
    ]);
    _orders.add(_order('demo-order-1', 'demo-quote-2', status: 'Confirmada'));
    _messages['demo-quote-1'] = [
      _message(
        'demo-message-1',
        'demo-quote-1',
        'Hola, ¿aún tienes disponible el alternador?',
        true,
      ),
      _message(
        'demo-message-2',
        'demo-quote-1',
        'Sí, está probado e incluye 30 días de garantía.',
        false,
      ),
    ];
  }

  final List<Map<String, dynamic>> _requests = [];
  final List<Map<String, dynamic>> _quotes = [];
  final List<Map<String, dynamic>> _orders = [];
  final Map<String, List<Map<String, dynamic>>> _messages = {};
  final Map<String, dynamic> _profile = {
    'guidId': 'demo-yonke',
    'nombre': 'Yonke El Profe',
    'responsable': 'Noé Gámez',
    'telefono': '+52 631 123 4567',
    'correo': 'yonke@refanet.demo',
    'direccion': 'Av. Tecnológico 120',
    'cp': 84000,
    'ciudadId': 1,
    'ciudades': {
      'ciudad': 'Nogales',
      'entidades': {'entidad': 'Sonora'},
    },
  };
  int _sequence = 20;

  dynamic get(
    String path, {
    required String role,
    Map<String, dynamic>? query,
  }) {
    if (path == ApiEndpoints.dashboardRequests) {
      final search = '${query?['Search'] ?? ''}'.trim().toLowerCase();
      final source = _requests.where((item) {
        if (search.isEmpty) return true;
        return '${item['piezaBuscada']} ${item['marca']} ${item['modelo']} ${item['folio']}'
            .toLowerCase()
            .contains(search);
      }).toList();
      return {
        'data': role == 'yonke'
            ? source.map(_assignmentFor).toList(growable: false)
            : source,
      };
    }
    if (path == ApiEndpoints.dashboardQuotes) return {'data': _quotes};
    if (path == ApiEndpoints.dashboardRecentRequest) {
      return {'data': _requests.isEmpty ? null : _requests.last};
    }
    if (path == ApiEndpoints.dashboardSummary) {
      return {
        'data': {
          'totalSolicitudes': _requests.length,
          'totalCotizaciones': _quotes.length,
        },
      };
    }
    if (path == ApiEndpoints.states) {
      return {
        'data': [
          {'id': 26, 'entidad': 'Sonora'},
        ],
      };
    }
    if (path == ApiEndpoints.citiesByState(26)) {
      return {
        'data': [
          {'id': 1, 'ciudad': 'Nogales'},
          {'id': 2, 'ciudad': 'Hermosillo'},
          {'id': 3, 'ciudad': 'Agua Prieta'},
        ],
      };
    }
    if (path == ApiEndpoints.brands) {
      return {
        'data': [
          {'id': 1, 'marca': 'Nissan'},
          {'id': 2, 'marca': 'Chevrolet'},
          {'id': 3, 'marca': 'Honda'},
          {'id': 4, 'marca': 'Toyota'},
        ],
      };
    }
    if (path == ApiEndpoints.models) {
      return {
        'data': [
          {'id': 1, 'modelo': 'Sentra', 'marcaId': 1},
          {'id': 2, 'modelo': 'Aveo', 'marcaId': 2},
          {'id': 3, 'modelo': 'Civic', 'marcaId': 3},
          {'id': 4, 'modelo': 'Corolla', 'marcaId': 4},
        ],
      };
    }
    if (path == ApiEndpoints.yonke('demo-yonke')) {
      return {'data': Map<String, dynamic>.from(_profile)};
    }
    if (path == ApiEndpoints.yonkeCoverage('demo-yonke')) {
      return {
        'data': [
          {'ciudadId': 1, 'activo': true},
          {'ciudadId': 2, 'activo': true},
        ],
      };
    }
    if (path.startsWith('/api/SolicitudesImagenes/solicitud/')) {
      final id = path.split('/').last;
      final request = _requests.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['guidId'] == id,
        orElse: () => null,
      );
      return {'data': request == null ? const [] : _imageRecords(request)};
    }
    if (path.startsWith('/api/SolicitudCiudades/') &&
        path.endsWith('/ciudades')) {
      return {
        'data': [
          {
            'id': 1,
            'ciudad': 'Nogales',
            'entidades': {'entidad': 'Sonora'},
          },
        ],
      };
    }
    if (path.startsWith('/api/Solicitudes/')) {
      final id = path.split('/').last;
      return {'data': _requests.firstWhere((item) => item['guidId'] == id)};
    }
    if (path.startsWith('/api/CotizacionYonke/')) {
      final id = path.split('/').last;
      return {'data': _quotes.firstWhere((item) => item['guidId'] == id)};
    }
    if (path.startsWith('/api/Orden/cotizacion/')) {
      final quoteId = path.split('/').last;
      final order = _orders.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['cotizacionGuidId'] == quoteId,
        orElse: () => null,
      );
      return {'data': order};
    }
    if (path.startsWith('/api/Orden/')) {
      final orderId = path.split('/').last;
      final order = _orders.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['guidId'] == orderId,
        orElse: () => null,
      );
      return {'data': order};
    }
    if (path.startsWith('/api/SolicitudCotizacionMensajes/')) {
      final segments = path.split('/');
      final quoteId = segments.length > 3 ? segments[3] : '';
      if (path.endsWith('/no-leidos')) {
        final count = (_messages[quoteId] ?? const [])
            .where(
              (message) =>
                  message['leido'] != true &&
                  _messageIsFromOtherRole(message, role),
            )
            .length;
        return {
          'data': {'cantidad': count},
        };
      }
      return {'data': _messages[quoteId] ?? const []};
    }
    return {'data': []};
  }

  dynamic post(
    String path, {
    required String role,
    Object? data,
    Map<String, dynamic>? query,
  }) {
    if (path == ApiEndpoints.orders && data is Map) {
      final quoteId = '${data['cotizacionGuidId'] ?? ''}';
      final quote = _quotes.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['guidId'] == quoteId,
        orElse: () => null,
      );
      if (quote == null || quote['activo'] != true) {
        return {'success': false, 'message': 'Cotización no disponible'};
      }
      final existing = _orders.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['cotizacionGuidId'] == quoteId,
        orElse: () => null,
      );
      if (existing != null) return {'success': true, 'data': existing};

      final requestId = '${quote['solicitudGuidId'] ?? ''}';
      for (final candidate in _quotes) {
        if (candidate['solicitudGuidId'] != requestId) continue;
        final selected = candidate['guidId'] == quoteId;
        candidate['activo'] = selected;
        candidate['solicitudCotizacionEstatus'] = {
          'descripcion': selected ? 'Aceptada' : 'Rechazada',
        };
      }
      final request = _requests.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['guidId'] == requestId,
        orElse: () => null,
      );
      if (request != null) request['cerrada'] = true;

      final order = _order(
        'demo-order-${++_sequence}',
        quoteId,
        status: 'Confirmada',
      );
      _orders.insert(0, order);
      return {'success': true, 'data': order};
    }
    if (path.startsWith('/api/Orden/') && path.endsWith('/cancelar')) {
      final segments = path.split('/');
      final orderId = segments.length > 3 ? segments[3] : '';
      final order = _orders.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['guidId'] == orderId,
        orElse: () => null,
      );
      if (order == null) return {'success': false};
      order['estatus'] = 'Cancelada';
      order['cancelada'] = true;
      order['puedeCancelar'] = false;
      return {'success': true, 'data': order};
    }
    if (path == ApiEndpoints.requests && data is Map) {
      final id = 'demo-request-${++_sequence}';
      final brandId = data['marcaId'] as int? ?? 1;
      final modelId = data['modeloId'] as int? ?? 1;
      final request =
          _request(
              id,
              '${data['piezaBuscada'] ?? 'Autoparte'}',
              _brandName(brandId),
              _modelName(modelId),
              data['año'] as int? ?? 2020,
              'SOL-${_sequence.toString().padLeft(3, '0')}/2026',
              0,
            )
            ..['imagenUrl'] = null
            ..['solicitudesImagenes'] = <dynamic>[]
            ..addAll({
              'descripcion': data['descripcion'],
              'motor': data['motor'],
              'transmicion': data['transmicion'],
              'numeroParte': data['numeroParte'],
            });
      _requests.insert(0, request);
      return {
        'success': true,
        'data': {'guidId': id},
      };
    }
    if (path == ApiEndpoints.quoteMessages && data is Map) {
      final quoteId = '${data['solicitudCotizacionGuidId']}';
      (_messages[quoteId] ??= []).add(
        _message(
          'demo-message-${++_sequence}',
          quoteId,
          '${data['mensaje']}',
          role == 'client',
        ),
      );
      return {'success': true};
    }
    return {'success': true, 'data': {}};
  }

  dynamic put(String path, {required String role, Object? data}) {
    if (path.startsWith('/api/SolicitudCotizacionMensajes/') &&
        path.endsWith('/leer')) {
      final segments = path.split('/');
      final quoteId = segments.length > 3 ? segments[3] : '';
      final now = DateTime.now().toIso8601String();
      for (final message in _messages[quoteId] ?? const []) {
        if (_messageIsFromOtherRole(message, role)) {
          message['leido'] = true;
          message['fechaLectura'] = now;
        }
      }
      return {
        'success': true,
        'data': {'leidos': true},
      };
    }
    if (path.contains('/vista')) {
      final assignmentId = path.split('/')[3];
      final request = _requestForAssignment(assignmentId);
      if (request != null) request['demoViewed'] = true;
    }
    if (path.startsWith('/api/CotizacionYonke/') && data is Map) {
      final quoteId = path.split('/').last;
      final quote = _quotes.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['guidId'] == quoteId,
        orElse: () => null,
      );
      if (quote != null) {
        for (final entry in data.entries) {
          quote[entry.key.toString()] = entry.value;
        }
      }
    }
    if (path.startsWith('/api/Yonkes/updateInfo/byGuidId/') && data is Map) {
      for (final entry in data.entries) {
        _profile[entry.key.toString()] = entry.value;
      }
    }
    return {'success': true, 'data': data};
  }

  dynamic delete(String path) {
    if (path.startsWith('/api/Solicitudes/')) {
      final id = path.split('/').last;
      _requests.removeWhere((item) => item['guidId'] == id);
      _quotes.removeWhere(
        (item) =>
            item['solicitudGuidId'] == id ||
            (item['solicitudYonkes'] is Map &&
                item['solicitudYonkes']['solicitudGuidId'] == id),
      );
    }
    return {'success': true};
  }

  dynamic multipart(
    String path, {
    required Map<String, dynamic> fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? query,
  }) {
    if (path == ApiEndpoints.updateYonkeLogo) {
      _profile['logoUrl'] = 'asset://assets/images/refanet_yonke_icon.png';
      return {'success': true, 'data': _profile};
    }
    if (path.startsWith('/api/SolicitudesImagenes/')) {
      final requestId = path.split('/').last;
      final request = _requests.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['guidId'] == requestId,
        orElse: () => null,
      );
      if (request != null && files.isNotEmpty) {
        final images = files
            .map(
              (file) => {
                'urlImagen': _dataImage(file),
                'nombreArchivo': file.fileName,
              },
            )
            .toList(growable: false);
        request['solicitudesImagenes'] = images;
        request['imagenUrl'] = images.first['urlImagen'];
      }
      return {'success': true, 'data': _imageRecords(request)};
    }
    if (path == ApiEndpoints.quotes) {
      final assignmentId = '${query?['solicitudYonkeGuidId'] ?? ''}';
      final request = _requestForAssignment(assignmentId);
      if (request == null) return {'success': false};
      final quote =
          _quote(
            'demo-quote-${++_sequence}',
            request,
            (fields['Precio'] as num?)?.toDouble() ?? 0,
            'Enviada',
          )..addAll({
            'disponible': fields['Disponible'] ?? true,
            'esNueva': fields['EsNueva'] ?? false,
            'numeroParte': fields['NumeroParte'],
            'comentarios': fields['Comentarios'],
            'tiempoEntregaDias': fields['TiempoEntregaDias'],
            'diasGarantia': fields['DiasGarantia'] ?? 0,
            'envioDisponible': fields['EnvioDisponible'] ?? false,
            'costoEnvio': fields['CostoEnvio'],
            'tieneGarantia': fields['TieneGarantia'] ?? false,
          });
      _quotes.insert(0, quote);
      request['totalCotizaciones'] = (request['totalCotizaciones'] as int) + 1;
      return {'success': true, 'data': quote};
    }
    return {'success': true};
  }

  Map<String, dynamic> _assignmentFor(Map<String, dynamic> request) => {
    'guidId': 'assignment-${request['guidId']}',
    'solicitudGuidId': request['guidId'],
    'fechaEnvio': request['fechaCreacion'],
    'fechaVista': request['demoViewed'] == true
        ? DateTime.now().toIso8601String()
        : null,
    'solicitudYonkesEstatus': {
      'estatusSolicitud': request['demoViewed'] == true ? 'Vista' : 'Nueva',
    },
    'solicitudes': {
      ...request,
      'marcas': {'marca': request['marca']},
      'modelos': {'modelo': request['modelo']},
      'solicitudesImagenes': _imageRecords(request),
      'solicitudesCiudades': const [
        {
          'ciudades': {
            'ciudad': 'Nogales',
            'entidades': {'entidad': 'Sonora'},
          },
        },
      ],
    },
    'solicitudCotizaciones': _quotes
        .where(
          (quote) =>
              quote['solicitudYonkes']['solicitudGuidId'] == request['guidId'],
        )
        .toList(),
  };

  Map<String, dynamic>? _requestForAssignment(String assignmentId) {
    final requestId = assignmentId.replaceFirst('assignment-', '');
    return _requests.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['guidId'] == requestId,
      orElse: () => null,
    );
  }

  Map<String, dynamic> _request(
    String id,
    String part,
    String brand,
    String model,
    int year,
    String folio,
    int quoteCount,
  ) => {
    'guidId': id,
    'piezaBuscada': part,
    'marca': brand,
    'modelo': model,
    'año': year,
    'folio': folio,
    'estatusSolicitud': 'En proceso',
    'totalCotizaciones': quoteCount,
    'cerrada': false,
    'fechaCreacion': DateTime.now()
        .subtract(Duration(hours: _requests.length + 1))
        .toIso8601String(),
    'descripcion': 'Se busca pieza completa, funcional y en buen estado.',
    'imagenUrl': _imageFor(part),
    'solicitudesImagenes': [
      {'urlImagen': _imageFor(part)},
    ],
  };

  Map<String, dynamic> _quote(
    String id,
    Map<String, dynamic> request,
    double price,
    String status,
  ) => {
    'guidId': id,
    'solicitudYonkeGuidId': 'assignment-${request['guidId']}',
    'solicitudGuidId': request['guidId'],
    'piezaBuscada': request['piezaBuscada'],
    'marca': request['marca'],
    'modelo': request['modelo'],
    'anio': request['año'],
    'folio': request['folio'],
    'yonkeNombre': 'Yonke El Profe',
    'precio': price,
    'disponible': true,
    'esNueva': false,
    'tieneGarantia': true,
    'diasGarantia': 30,
    'envioDisponible': true,
    'costoEnvio': 150,
    'activo': true,
    'fechaCreacion': DateTime.now()
        .subtract(Duration(minutes: _quotes.length * 25))
        .toIso8601String(),
    'comentarios': 'Pieza probada y lista para envío.',
    'solicitudCotizacionEstatus': {'descripcion': status},
    'solicitudCotizacionesImagenes': _imageRecords(request),
    'solicitudYonkes': {
      'guidId': 'assignment-${request['guidId']}',
      'solicitudGuidId': request['guidId'],
      'yonkeGuidId': 'demo-yonke',
      'yonkes': {'nombre': 'Yonke El Profe', 'telefono': '+52 631 123 4567'},
      'solicitudes': {
        ...request,
        'marcas': {'marca': request['marca']},
        'modelos': {'modelo': request['modelo']},
      },
    },
  };

  Map<String, dynamic> _message(
    String id,
    String quoteId,
    String text,
    bool fromClient,
  ) => {
    'guidId': id,
    'solicitudCotizacionGuidId': quoteId,
    'mensaje': text,
    'tipoRemitenteId': fromClient ? 1 : 2,
    'usuarioId': fromClient ? 'demo-client' : 'demo-yonke-user',
    'leido': false,
    'fechaCreacion': DateTime.now().toIso8601String(),
  };

  Map<String, dynamic> _order(
    String id,
    String quoteId, {
    required String status,
  }) => {
    'guidId': id,
    'cotizacionGuidId': quoteId,
    'estatus': status,
    'cancelada': false,
    'puedeCancelar': true,
    'fechaCreacion': DateTime.now().toIso8601String(),
  };

  String _brandName(int id) =>
      const {1: 'Nissan', 2: 'Chevrolet', 3: 'Honda', 4: 'Toyota'}[id] ??
      'Nissan';
  String _modelName(int id) =>
      const {1: 'Sentra', 2: 'Aveo', 3: 'Civic', 4: 'Corolla'}[id] ?? 'Sentra';

  String _imageFor(String part) {
    final value = part.toLowerCase();
    if (value.contains('compresor')) {
      return 'asset://assets/images/demo_ac_compressor.png';
    }
    if (value.contains('transm')) {
      return 'asset://assets/images/demo_transmission.png';
    }
    if (value.contains('arranque')) {
      return 'asset://assets/images/demo_starter.png';
    }
    return 'asset://assets/images/demo_alternator.png';
  }

  List<Map<String, dynamic>> _imageRecords(Map<String, dynamic>? request) {
    if (request == null) return const [];
    final records = request['solicitudesImagenes'];
    if (records is List) {
      return records
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => '${item['urlImagen'] ?? ''}'.isNotEmpty)
          .toList(growable: false);
    }
    final image = request['imagenUrl']?.toString();
    return image == null || image.isEmpty
        ? const []
        : [
            {'urlImagen': image},
          ];
  }

  String _dataImage(ApiFile file) {
    final extension = file.fileName.split('.').last.toLowerCase();
    final subtype = switch (extension) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpeg',
    };
    return 'data:image/$subtype;base64,${base64Encode(file.bytes)}';
  }

  bool _messageIsFromOtherRole(Map<String, dynamic> message, String role) {
    final senderIsClient = message['tipoRemitenteId'] == 1;
    return role == 'client' ? !senderIsClient : senderIsClient;
  }
}
