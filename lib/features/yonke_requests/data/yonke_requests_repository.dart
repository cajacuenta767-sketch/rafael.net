import '../../../core/storage/session_sync_store.dart';
import '../../dashboard/data/dashboard_api.dart';
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
}

/// La respuesta de la bandeja no tiene la forma `SolicitudYonkes` que el
/// yonke necesita para actuar (guid de la asignación). No se inventa nada.
class AssignedRequestsEndpointPendingException implements Exception {
  const AssignedRequestsEndpointPendingException();
}

/// Bandeja del yonke sobre `GET /api/DashboardSuscriptores/mis-solicitudes`.
///
/// El OpenAPI no declara el cuerpo de esa respuesta. Se aceptan registros
/// `SolicitudYonkes` (con `solicitudes` anidada) o una proyección plana con
/// `solicitudYonkeGuidId`; cualquier otra forma se reporta como contrato
/// pendiente en lugar de mostrar datos incompletos. Los filtros de estado,
/// ciudad y fecha se aplican en la app porque el endpoint solo recibe
/// `Page`, `Search` y `CantidadRegistrosPorPagina`.
class ApiYonkeRequestsRepository implements YonkeRequestsRepository {
  const ApiYonkeRequestsRepository(this._dashboardApi, this._requestsApi);

  final DashboardApi _dashboardApi;
  final RequestsApi _requestsApi;

  @override
  Future<YonkeRequestsPageResult> getAssignedRequests({
    required int page,
    required int pageSize,
    String? search,
    YonkeRequestFilters filters = const YonkeRequestFilters(),
  }) async {
    final safePage = page < 1 ? 1 : page;
    dynamic response;
    try {
      response = await _dashboardApi.getMyRequests(
        page: safePage,
        pageSize: pageSize,
        search: search == null || search.trim().isEmpty ? null : search.trim(),
      );
    } catch (_) {
      // Ignorar error si está pendiente
    }
    final parsed = response != null
        ? yonkeAssignedRequestsFromResponse(response)
        : null;
    final list = parsed ?? <YonkeRequestSummary>[];
    final sessionRequests = SessionSyncStore.instance.yonkeRequests;
    final combined = <YonkeRequestSummary>[...sessionRequests];
    for (final item in list) {
      if (!combined.any((existing) => existing.requestId == item.requestId)) {
        combined.add(item);
      }
    }
    final updated = combined.map((item) {
      if (SessionSyncStore.instance.isUnavailable(item.requestYonkeId)) {
        return item.copyWith(status: YonkeRequestStatus.unavailable);
      }
      if (SessionSyncStore.instance.isQuoted(item.requestYonkeId)) {
        return item.copyWith(status: YonkeRequestStatus.quoted, hasQuote: true);
      }
      return item;
    }).toList();

    final items = updated.where((item) => _matches(item, filters)).toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return YonkeRequestsPageResult(
      items: items,
      page: safePage,
      hasMore: list.length >= pageSize,
    );
  }

  @override
  Future<void> markAsViewed(String requestYonkeId) =>
      _requestsApi.markAsViewedByYonke(requestYonkeId);
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
  final hasQuote = quotes is List && quotes.isNotEmpty;
  final closed = request['cerrada'] == true;
  final receivedAt =
      _date(json['fechaEnvio']) ??
      _date(request['fechaCreacion']) ??
      _date(json['fechaCreacion']) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  return YonkeRequestSummary(
    requestId: requestId,
    requestYonkeId: requestYonkeId,
    part: part,
    status: _status(
      statusText,
      closed: closed,
      hasQuote: hasQuote,
      viewed: _date(json['fechaVista']) != null,
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
    city: _cityName(request['solicitudesCiudades']),
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
  );
}

String? _firstSafeImage(dynamic images) {
  if (images is! List) return null;
  for (final image in images.whereType<Map>()) {
    final value = _text(image['urlImagen']);
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
  required bool closed,
  required bool hasQuote,
  required bool viewed,
}) {
  final normalized = text?.toLowerCase() ?? '';
  if (closed || normalized.contains('cerr') || normalized.contains('cancel')) {
    return YonkeRequestStatus.closed;
  }
  if (normalized.contains('no disp')) return YonkeRequestStatus.unavailable;
  if (normalized.contains('cotiz') || hasQuote) {
    return YonkeRequestStatus.quoted;
  }
  if (normalized.contains('vista') || viewed) return YonkeRequestStatus.viewed;
  if (normalized.contains('nueva') ||
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
