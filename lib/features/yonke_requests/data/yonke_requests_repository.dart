import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/token_store.dart';
import '../../auth/domain/session_payload.dart';
import '../../requests/data/requests_api.dart';
import '../domain/yonke_request_summary.dart';

abstract interface class YonkeRequestsRepository {
  Future<YonkeRequestsPageResult> getAssignedRequests({
    required int page,
    required int pageSize,
    String? search,
    YonkeRequestFilters filters = const YonkeRequestFilters(),
  });

  Future<void> markAsViewed(String requestYonkeId);

  Future<YonkeRequestSummary?> getMostRecentRequest();
}

/// La respuesta de la bandeja no tiene la forma `SolicitudYonkes` que el
/// yonke necesita para actuar (guid de la asignación). No se inventa nada.
class AssignedRequestsEndpointPendingException implements Exception {
  const AssignedRequestsEndpointPendingException();
}

/// Bandeja del yonke sobre `GET /api/SolicitudYonkes/MisSolicitudes`. Los
/// endpoints de `DashboardSuscriptores` son solo del rol Cliente, así que no
/// sirven de respaldo para el yonke (responderían 403).
///
/// El OpenAPI no declara el cuerpo de esas respuestas. Se aceptan registros
/// `SolicitudYonkes` (con `solicitudes` anidada) o una proyección plana con
/// `solicitudYonkeGuidId`; cualquier otra forma se reporta como contrato
/// pendiente en lugar de mostrar datos incompletos. Los filtros de estado,
/// ciudad y fecha se aplican en la app porque el endpoint solo recibe
/// `Page`, `Search` y `CantidadRegistrosPorPagina`.
class ApiYonkeRequestsRepository implements YonkeRequestsRepository {
  const ApiYonkeRequestsRepository(
    this._requestsApi, [
    this._storage = const FlutterSecureStorage(),
    this._tokens,
  ]);

  final RequestsApi _requestsApi;
  final FlutterSecureStorage? _storage;
  final TokenStore? _tokens;

  Future<String> _resolveHistoryKey() async {
    final storage = _storage ?? const FlutterSecureStorage();
    String? email = await storage.read(key: 'yonke.active_email');
    if (email == null || email.trim().isEmpty) {
      final token = await _tokens?.readAccessToken() ??
          await storage.read(key: 'auth.access_token');
      if (token != null && token.isNotEmpty) {
        final claims = SessionResponseParser.decodeJwtClaims(token);
        email = claims?['email']?.toString() ??
            claims?['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress']
                ?.toString();
      }
    }
    if (email != null && email.trim().isNotEmpty) {
      return 'yonke.requests.email.${email.trim().toLowerCase()}';
    }
    return 'yonke.requests.history';
  }

  Future<List<YonkeRequestSummary>> _loadCached() async {
    final storage = _storage ?? const FlutterSecureStorage();
    try {
      final key = await _resolveHistoryKey();
      var raw = await storage.read(key: key);
      if ((raw == null || raw.isEmpty) && key != 'yonke.requests.history') {
        raw = await storage.read(key: 'yonke.requests.history');
      }
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) =>
              YonkeRequestSummary.fromStoredJson(Map<String, dynamic>.from(m)))
          .where((item) => item.requestYonkeId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveCached(List<YonkeRequestSummary> items) async {
    final storage = _storage ?? const FlutterSecureStorage();
    try {
      final key = await _resolveHistoryKey();
      await storage.write(
        key: key,
        value: jsonEncode(items.map((i) => i.toJson()).toList()),
      );
    } catch (_) {}
  }

  @override
  Future<YonkeRequestsPageResult> getAssignedRequests({
    required int page,
    required int pageSize,
    String? search,
    YonkeRequestFilters filters = const YonkeRequestFilters(),
  }) async {
    final safePage = page < 1 ? 1 : page;
    final cleanSearch = search == null || search.trim().isEmpty
        ? null
        : search.trim();

    final cached = await _loadCached();
    List<YonkeRequestSummary>? assigned;

    try {
      final response = await _requestsApi.getAssignedToYonke();
      assigned = yonkeAssignedRequestsFromResponse(response);
    } catch (_) {
      // Si la API falla, usamos el historial previamente guardado
      if (cached.isEmpty) rethrow;
    }

    if (assigned == null && cached.isEmpty) {
      throw const AssignedRequestsEndpointPendingException();
    }

    // Fusión de solicitudes: conservamos todas las solicitudes antiguas
    final map = <String, YonkeRequestSummary>{};
    for (final item in cached) {
      map[item.requestYonkeId] = item;
    }
    if (assigned != null) {
      for (final item in assigned) {
        final prev = map[item.requestYonkeId];
        if (prev != null && (item.imageUrl == null || item.imageUrl!.isEmpty)) {
          map[item.requestYonkeId] = item.copyWith(
            description: item.description ?? prev.description,
            engine: item.engine ?? prev.engine,
            transmission: item.transmission ?? prev.transmission,
            clientId: item.clientId ?? prev.clientId,
          );
        } else {
          map[item.requestYonkeId] = item;
        }
      }
    }

    final allItems = map.values.toList();
    if (allItems.isNotEmpty) {
      await _saveCached(allItems);
    }

    // MisSolicitudes entrega la bandeja completa: la búsqueda, los filtros y
    // la paginación se resuelven aquí.
    final items =
        allItems
            .where(
              (item) =>
                  (cleanSearch == null || _matchesSearch(item, cleanSearch)) &&
                  _matches(item, filters),
            )
            .toList()
          ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    final start = (safePage - 1) * pageSize;
    return YonkeRequestsPageResult(
      items: items.skip(start).take(pageSize).toList(growable: false),
      page: safePage,
      hasMore: items.length > start + pageSize,
    );
  }

  @override
  Future<void> markAsViewed(String requestYonkeId) async {
    try {
      await _requestsApi.markAsViewedByYonke(requestYonkeId);
    } finally {
      final cached = await _loadCached();
      if (cached.isNotEmpty) {
        final updated = cached.map((r) {
          if (r.requestYonkeId == requestYonkeId &&
              r.status == YonkeRequestStatus.newRequest) {
            return r.copyWith(status: YonkeRequestStatus.viewed);
          }
          return r;
        }).toList();
        await _saveCached(updated);
      }
    }
  }

  @override
  Future<YonkeRequestSummary?> getMostRecentRequest() async {
    try {
      final response = await _requestsApi.getYonkeMostRecentRequest();
      final data = response is Map ? response['data'] : response;
      if (data == null || data is! Map) return null;
      return yonkeRequestSummaryFromJson(data);
    } catch (_) {
      return null;
    }
  }
}

bool _matchesSearch(YonkeRequestSummary item, String search) {
  final query = search.toLowerCase();
  return [
    item.folio,
    item.part,
    item.brand,
    item.model,
    item.city,
  ].any((value) => value != null && value.toLowerCase().contains(query));
}

bool _matches(YonkeRequestSummary item, YonkeRequestFilters filters) {
  final date = item.receivedAt;
  return (filters.status == null || item.status == filters.status) &&
      (filters.city == null || item.city == filters.city) &&
      (filters.from == null || !date.isBefore(_startOfDay(filters.from!))) &&
      (filters.to == null || !date.isAfter(_endOfDay(filters.to!)));
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _endOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

/// Interpreta la lista de solicitudes asignadas. Devuelve `null` cuando la
/// respuesta no es una lista o cuando trae registros sin la forma esperada.
/// Extrae la lista de registros de una respuesta de API.
List<dynamic>? _extractYonkeAssignedRecords(dynamic response) {
  if (response is List) return response;
  if (response is! Map) return null;
  final data = response['data'] ?? response;
  if (data is List) return data;
  if (data is Map) {
    if (data['data'] is List) return data['data'] as List;
    if (data['items'] is List) return data['items'] as List;
    if (data['registros'] is List) return data['registros'] as List;
    if (data['solicitudes'] is List) return data['solicitudes'] as List;
  }
  if (response['items'] is List) return response['items'] as List;
  if (response['registros'] is List) return response['registros'] as List;
  return null;
}

/// Interpreta la lista de solicitudes asignadas. Devuelve `null` cuando la
/// respuesta no es una lista o cuando trae registros sin la forma esperada.
List<YonkeRequestSummary>? yonkeAssignedRequestsFromResponse(dynamic response) {
  final records = _extractYonkeAssignedRecords(response);
  if (records == null) return null;
  final items = records
      .whereType<Map>()
      .map(yonkeRequestSummaryFromJson)
      .whereType<YonkeRequestSummary>()
      .toList(growable: false);
  if (items.isEmpty && records.isNotEmpty) return null;
  return items;
}

/// Un registro `SolicitudYonkes` (`guidId`, `solicitudGuidId`, `solicitudes`,
/// `solicitudYonkesEstatus`, `fechaEnvio`, `fechaVista`, `fechaRespuesta`,
/// `solicitudCotizaciones`) o una proyección plana con
/// `solicitudYonkeGuidId` junto a los campos de la solicitud.
YonkeRequestSummary? yonkeRequestSummaryFromJson(Map<dynamic, dynamic> json) {
  final nested = json['solicitudes'];
  final request = nested is Map ? nested : json;
  final String? requestYonkeId;
  final String? requestId;
  if (nested is Map) {
    requestYonkeId =
        _text(json['guidId']) ?? _text(json['solicitudYonkeGuidId']);
    requestId = _text(json['solicitudGuidId']) ?? _text(nested['guidId']);
  } else {
    requestYonkeId =
        _text(json['solicitudYonkeGuidId']) ??
        _text(json['guidId']) ??
        (json['id']?.toString());
    requestId =
        _text(json['solicitudGuidId']) ??
        _text(json['guidId']) ??
        (json['id']?.toString());
  }
  if (requestYonkeId == null || requestId == null) return null;

  final part = _text(request['piezaBuscada']);
  if (part == null) return null;

  final brands = request['marcas'];
  final models = request['modelos'];
  final images =
      request['solicitudesImagenes'] ??
      request['solicitudImagenes'] ??
      request['imagenes'];
  final quotes = json['solicitudCotizaciones'];
  final assignmentStatus = json['solicitudYonkesEstatus'];
  final statusText =
      (assignmentStatus is Map
          ? _text(assignmentStatus['estatusSolicitud'])
          : null) ??
      _text(json['estatusSolicitud']) ??
      _text(json['estatus']);
  // `SolicitudYonke_List_DTO` (MisSolicitudes) trae `cotizaciones` como
  // número; los registros `SolicitudYonkes` la traen como lista.
  final hasQuote =
      (quotes is List && quotes.isNotEmpty) ||
      (json['cotizaciones'] is num && (json['cotizaciones'] as num) > 0);
  final closed = request['cerrada'] == true;
  final receivedAt =
      _date(json['fechaEnvio']) ??
      _date(request['fechaCreacion']) ??
      _date(json['fechaCreacion']) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  final rawStatusId = json['estatusId'] ?? json['EstatusId'];
  final statusId = rawStatusId is num ? rawStatusId.toInt() : int.tryParse('$rawStatusId');

  return YonkeRequestSummary(
    requestId: requestId,
    requestYonkeId: requestYonkeId,
    part: part,
    status: _status(
      statusText,
      statusId: statusId,
      closed: closed,
      hasQuote: hasQuote,
      viewed: json['vista'] == true || _date(json['fechaVista']) != null,
    ),
    receivedAt: receivedAt,
    brand:
        _text(request['marca']) ??
        (brands is Map ? _text(brands['marca']) : null),
    model:
        _text(request['modelo']) ??
        (models is Map ? _text(models['modelo']) : null),
    year:
        (request['año'] as num?)?.toInt() ??
        (request['anio'] as num?)?.toInt() ??
        (request['ano'] as num?)?.toInt() ??
        (request['year'] as num?)?.toInt() ??
        (request['a\u00f1o'] as num?)?.toInt(),
    city:
        _cityName(request['solicitudesCiudades']) ??
        _cityName(json['ciudades']),
    folio: _text(request['folio']),
    photoCount: images is List ? images.length : 0,
    hasQuote: hasQuote,
    imageUrl:
        _firstSafeImage(images) ??
        (request['urlImagen'] != null
            ? _firstSafeImage([
                {'urlImagen': request['urlImagen']},
              ])
            : null),
    description: _text(request['descripcion']) ?? _text(json['descripcion']),
    engine: _text(request['motor']) ?? _text(json['motor']),
    transmission: _text(request['transmicion']) ?? _text(json['transmicion']),
    clientId: _text(request['usuarioId']) ?? _text(json['clienteGuidId']),
  );
}

String? _firstSafeImage(dynamic images) {
  if (images is! List) return null;
  for (final image in images.whereType<Map>()) {
    final value = _text(image['urlImagen']) ?? _text(image['url']);
    if (value == null) continue;
    if (value.startsWith('asset://assets/')) return value;
    if (value.startsWith('data:image/') && value.contains(';base64,')) {
      return value;
    }
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String? _cityName(dynamic cities) {
  if (cities is! List) return null;
  final names = cities.whereType<Map>().map((record) {
    final city = record['ciudades'];
    final source = city is Map ? city : record;
    final name = _text(source['ciudad']);
    if (name == null) return null;
    final state = source['entidades'];
    final stateName = state is Map ? _text(state['entidad']) : null;
    return stateName == null ? name : '$name, $stateName';
  }).whereType<String>();
  return names.isEmpty ? null : names.join(' · ');
}

YonkeRequestStatus _status(
  String? text, {
  int? statusId,
  required bool closed,
  required bool hasQuote,
  required bool viewed,
}) {
  if (statusId == 7) return YonkeRequestStatus.accepted;
  if (statusId == 4) return YonkeRequestStatus.unavailable;
  if (statusId == 5 || statusId == 6) return YonkeRequestStatus.closed;

  final normalized = text?.toLowerCase() ?? '';
  if (closed || normalized.contains('cerr') || normalized.contains('cancel')) {
    return YonkeRequestStatus.closed;
  }
  if (normalized.contains('acept')) return YonkeRequestStatus.accepted;
  if (normalized.contains('no disp')) return YonkeRequestStatus.unavailable;
  if (normalized.contains('cotiz') || hasQuote) {
    return YonkeRequestStatus.quoted;
  }
  if (statusId == 2 || normalized.contains('vista') || viewed) return YonkeRequestStatus.viewed;
  if (statusId == 1 ||
      normalized.contains('nueva') ||
      normalized.contains('envi') ||
      normalized.contains('pend') ||
      normalized.isEmpty) {
    return YonkeRequestStatus.newRequest;
  }
  return YonkeRequestStatus.unknown;
}

DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
