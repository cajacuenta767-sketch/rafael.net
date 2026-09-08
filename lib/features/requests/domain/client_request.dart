/// Solicitud del cliente según `Solicitud_Busqueda_DTO` del OpenAPI:
/// `guidId`, `piezaBuscada`, `marca`, `modelo`, `año`, `estatusSolicitud`,
/// `totalCotizaciones`, `folio`, `fechaCreacion`, `cerrada`. También acepta
/// la entidad `Solicitudes`, que anida `marcas.marca`, `modelos.modelo` y
/// `solicitudEstatus.estatus`.
class ClientRequestSummary {
  const ClientRequestSummary({
    required this.id,
    required this.part,
    required this.status,
    required this.quoteCount,
    this.brand,
    this.model,
    this.year,
    this.folio,
    this.createdAt,
    this.closed = false,
  });

  final String id;
  final String part;
  final String status;
  final int quoteCount;
  final String? brand;
  final String? model;
  final int? year;
  final String? folio;
  final DateTime? createdAt;
  final bool closed;

  String get vehicle => [
    brand,
    model,
    year?.toString(),
  ].whereType<String>().where((value) => value.isNotEmpty).join(' ');

  /// Pieza y vehículo en dos líneas, como se muestra en las tarjetas.
  String get title => vehicle.isEmpty ? part : '$part\n$vehicle';

  bool get isInProgress => !closed;
}

class ClientRequestDetail {
  const ClientRequestDetail({
    required this.summary,
    required this.cities,
    required this.imageUrls,
    this.description,
    this.engine,
    this.transmission,
    this.partNumber,
  });

  final ClientRequestSummary summary;
  final List<String> cities;
  final List<String> imageUrls;
  final String? description;
  final String? engine;
  final String? transmission;
  final String? partNumber;

  String get city => cities.isEmpty ? 'Sin información' : cities.join(' · ');
}

List<ClientRequestSummary> clientRequestSummariesFromResponse(
  dynamic response,
) =>
    _records(response)
        .whereType<Map>()
        .map(clientRequestSummaryFromJson)
        .whereType<ClientRequestSummary>()
        .toList(growable: false);

/// Para `mi-solicitud-reciente`: `data` puede ser el objeto o una lista con
/// un elemento. Devuelve `null` si no hay solicitud.
ClientRequestSummary? clientRequestSummaryFromResponse(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data is Map) return clientRequestSummaryFromJson(data);
  final records = _records(response).whereType<Map>();
  return records.isEmpty ? null : clientRequestSummaryFromJson(records.first);
}

ClientRequestSummary? clientRequestSummaryFromJson(Map<dynamic, dynamic> json) {
  final id = _text(json['guidId']) ?? _text(json['id']);
  final part = _text(json['piezaBuscada']);
  if (id == null || part == null) return null;
  final brands = json['marcas'];
  final models = json['modelos'];
  final statusRecord = json['solicitudEstatus'];
  final quotes = json['solicitudYonkes'];
  final closed = json['cerrada'] == true;
  final status =
      _text(json['estatusSolicitud']) ??
      (statusRecord is Map ? _text(statusRecord['estatus']) : null) ??
      (closed ? 'Cerrada' : 'En proceso');
  return ClientRequestSummary(
    id: id,
    part: part,
    status: status,
    quoteCount:
        (json['totalCotizaciones'] as num?)?.toInt() ??
        (quotes is List ? _quoteCount(quotes) : 0),
    brand:
        _text(json['marca']) ?? (brands is Map ? _text(brands['marca']) : null),
    model:
        _text(json['modelo']) ??
        (models is Map ? _text(models['modelo']) : null),
    year: (json['año'] as num?)?.toInt(),
    folio: _text(json['folio']),
    createdAt: DateTime.tryParse(json['fechaCreacion']?.toString() ?? '')
        ?.toLocal(),
    closed: closed,
  );
}

ClientRequestDetail? clientRequestDetailFromResponses({
  required dynamic requestResponse,
  dynamic imagesResponse,
  dynamic citiesResponse,
}) {
  final raw = requestResponse is Map
      ? requestResponse['data'] ?? requestResponse
      : null;
  if (raw is! Map) return null;
  final summary = clientRequestSummaryFromJson(raw);
  if (summary == null) return null;
  return ClientRequestDetail(
    summary: summary,
    cities: requestCityNamesFromResponse(citiesResponse),
    imageUrls: requestImageUrlsFromResponse(imagesResponse),
    description: _text(raw['descripcion']),
    engine: _text(raw['motor']),
    transmission: _text(raw['transmicion']),
    partNumber: _text(raw['numeroParte']),
  );
}

/// Registros `SolicitudesImagenes`: la URL pública viene en `urlImagen`.
List<String> requestImageUrlsFromResponse(dynamic response) =>
    _records(response)
        .whereType<Map>()
        .map((image) => _text(image['urlImagen']))
        .whereType<String>()
        .where(_isSafeImageUrl)
        .toList(growable: false);

/// `GET /api/SolicitudCiudades/{id}/ciudades`: registros `SolicitudesCiudades`
/// (con `ciudades` anidada) o `Ciudades` directamente.
List<String> requestCityNamesFromResponse(dynamic response) =>
    _requestCityRecords(response)
        .whereType<Map>()
        .map((record) {
          final nested = record['ciudades'];
          final city = nested is Map ? nested : record;
          final name = _text(city['ciudad']);
          if (name == null) return null;
          final state = city['entidades'];
          final stateName = state is Map ? _text(state['entidad']) : null;
          return stateName == null ? name : '$name, $stateName';
        })
        .whereType<String>()
        .toList(growable: false);

List<dynamic> _requestCityRecords(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data is Map) {
    final header = data['solicitudHeader'];
    if (header is Map && header['ciudadesSaveBySolicitud'] is List) {
      return header['ciudadesSaveBySolicitud'] as List;
    }
  }
  return _records(response);
}

int _quoteCount(List<dynamic> assignments) => assignments
    .whereType<Map>()
    .map((assignment) => assignment['solicitudCotizaciones'])
    .whereType<List>()
    .fold(0, (total, quotes) => total + quotes.length);

List<dynamic> _records(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  return switch (data) {
    List() => data,
    Map() when data['data'] is List => data['data'] as List,
    Map() when data['items'] is List => data['items'] as List,
    Map() when data['registros'] is List => data['registros'] as List,
    _ => const <dynamic>[],
  };
}

bool _isSafeImageUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
