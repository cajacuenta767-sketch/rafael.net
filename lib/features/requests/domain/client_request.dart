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
    this.imageUrl,
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
  final String? imageUrl;

  String get vehicle => [
    brand,
    model,
    year?.toString(),
  ].whereType<String>().where((value) => value.isNotEmpty).join(' ');

  /// Pieza y vehículo en dos líneas, como se muestra en las tarjetas.
  String get title => vehicle.isEmpty ? part : '$part\n$vehicle';

  bool get isInProgress =>
      !closed && status.toLowerCase().trim() != 'cancelada';

  ClientRequestSummary copyWith({
    String? id,
    String? part,
    String? status,
    int? quoteCount,
    String? brand,
    String? model,
    int? year,
    String? folio,
    DateTime? createdAt,
    bool? closed,
    String? imageUrl,
  }) => ClientRequestSummary(
    id: id ?? this.id,
    part: part ?? this.part,
    status: status ?? this.status,
    quoteCount: quoteCount ?? this.quoteCount,
    brand: brand ?? this.brand,
    model: model ?? this.model,
    year: year ?? this.year,
    folio: folio ?? this.folio,
    createdAt: createdAt ?? this.createdAt,
    closed: closed ?? this.closed,
    imageUrl: imageUrl ?? this.imageUrl,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'part': part,
    'status': status,
    'quoteCount': quoteCount,
    'brand': brand,
    'model': model,
    'year': year,
    'folio': folio,
    'createdAt': createdAt?.toIso8601String(),
    'closed': closed,
    'imageUrl': imageUrl,
  };

  factory ClientRequestSummary.fromJson(Map<String, dynamic> json) =>
      ClientRequestSummary(
        id: json['id']?.toString() ?? '',
        part: json['part']?.toString() ?? '',
        status: json['status']?.toString() ?? 'En proceso',
        quoteCount: (json['quoteCount'] as num?)?.toInt() ?? 0,
        brand: json['brand']?.toString(),
        model: json['model']?.toString(),
        year: (json['year'] as num?)?.toInt(),
        folio: json['folio']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
        closed: json['closed'] == true,
        imageUrl: json['imageUrl']?.toString(),
      );
}

class ClientRequestDetail {
  const ClientRequestDetail({
    required this.summary,
    required this.cities,
    required this.imageUrls,
    this.imageIds = const {},
    this.description,
    this.engine,
    this.transmission,
    this.partNumber,
  });

  final ClientRequestSummary summary;
  final List<String> cities;
  final List<String> imageUrls;

  /// `guidId` de cada imagen por URL; permite eliminarla con
  /// `DELETE /api/SolicitudesImagenes/{imagenGuidId}`.
  final Map<String, String> imageIds;
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
  final images = json['solicitudesImagenes'];
  final closed = json['cerrada'] == true;
  final rawStatusId = json['estatusSolicitudId'] ??
      json['EstatusSolicitudId'] ??
      json['estatusId'] ??
      json['EstatusId'];
  final statusId = rawStatusId is num
      ? rawStatusId.toInt()
      : int.tryParse('$rawStatusId');
  final mappedStatus = switch (statusId) {
    1 => 'Pendiente',
    2 => 'Enviada',
    3 => 'Cotizada',
    4 => 'Aceptada',
    5 => 'Rechazada',
    6 => 'Cancelada',
    7 => 'Cerrada',
    _ => null,
  };
  final status =
      _text(json['estatusSolicitud']) ??
      (statusRecord is Map
          ? _text(statusRecord['estatus']) ??
              _text(statusRecord['descripcion'])
          : null) ??
      mappedStatus ??
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
    imageUrl:
        _text(json['imagenUrl']) ??
        _text(json['imageUrl']) ??
        _firstImage(images),
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
    imageIds: requestImageIdsFromResponse(imagesResponse),
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

/// `guidId` de los registros `SolicitudesImagenes`, indexado por `urlImagen`.
Map<String, String> requestImageIdsFromResponse(dynamic response) {
  final ids = <String, String>{};
  for (final image in _records(response).whereType<Map>()) {
    final url = _text(image['urlImagen']);
    final id = _text(image['guidId']);
    if (url != null && id != null) ids[url] = id;
  }
  return ids;
}

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
  if (value.startsWith('asset://assets/')) return true;
  if (value.startsWith('data:image/') && value.contains(';base64,')) {
    return true;
  }
  final uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

String? _firstImage(dynamic images) {
  if (images is! List) return null;
  for (final image in images.whereType<Map>()) {
    final value = _text(image['urlImagen']);
    if (value != null && _isSafeImageUrl(value)) return value;
  }
  return null;
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

class RequestRecipient {
  const RequestRecipient({
    required this.id,
    required this.yonkeId,
    required this.yonkeName,
    this.logoUrl,
    this.telephone,
    this.status = 'Enviada',
    this.viewed = false,
    this.sentAt,
  });

  final String id;
  final String yonkeId;
  final String yonkeName;
  final String? logoUrl;
  final String? telephone;
  final String status;
  final bool viewed;
  final DateTime? sentAt;
}

List<RequestRecipient> requestRecipientsFromResponse(dynamic response) {
  final records = _records(response);
  return records
      .whereType<Map>()
      .map((record) {
        final rawLogo = _text(record['logo'] ?? record['logoUrl']);
        final logo = rawLogo != null && _isSafeImageUrl(rawLogo)
            ? rawLogo
            : null;
        return RequestRecipient(
          id: _text(record['solicitudYonkeGuidId'] ?? record['guidId']) ?? '',
          yonkeId: _text(record['yonkeGuidId']) ?? '',
          yonkeName: _text(record['nombreYonke']) ?? 'Yonke',
          logoUrl: logo,
          telephone: _text(record['telefono']),
          status: _text(record['estatus']) ?? 'Enviada',
          viewed: record['vista'] == true,
          sentAt: DateTime.tryParse(record['fechaEnvio']?.toString() ?? ''),
        );
      })
      .toList(growable: false);
}
