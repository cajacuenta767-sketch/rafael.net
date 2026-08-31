enum YonkeQuoteStatus { sent, viewed, accepted, rejected, closed, unknown }

extension YonkeQuoteStatusLabel on YonkeQuoteStatus {
  String get label => switch (this) {
    YonkeQuoteStatus.sent => 'Enviada',
    YonkeQuoteStatus.viewed => 'Vista',
    YonkeQuoteStatus.accepted => 'Aceptada',
    YonkeQuoteStatus.rejected => 'Rechazada',
    YonkeQuoteStatus.closed => 'Cerrada',
    YonkeQuoteStatus.unknown => 'Sin estado',
  };
}

class YonkeQuote {
  const YonkeQuote({
    required this.id,
    required this.requestYonkeId,
    required this.requestId,
    required this.part,
    required this.price,
    required this.available,
    required this.isNew,
    required this.hasWarranty,
    required this.warrantyDays,
    required this.shippingAvailable,
    required this.active,
    required this.status,
    required this.createdAt,
    required this.imageUrls,
    required this.isDemo,
    this.brand,
    this.model,
    this.year,
    this.folio,
    this.partNumber,
    this.comments,
    this.deliveryDays,
    this.shippingCost,
  });

  final String id;
  final String requestYonkeId;
  final String requestId;
  final String part;
  final double price;
  final bool available;
  final bool isNew;
  final bool hasWarranty;
  final int warrantyDays;
  final bool shippingAvailable;
  final bool active;
  final YonkeQuoteStatus status;
  final DateTime createdAt;
  final List<String> imageUrls;
  final bool isDemo;
  final String? brand;
  final String? model;
  final int? year;
  final String? folio;
  final String? partNumber;
  final String? comments;
  final int? deliveryDays;
  final double? shippingCost;

  String get vehicle => [
    brand,
    model,
    year?.toString(),
  ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');

  String get condition => isNew ? 'Nueva' : 'Usada';

  String get warranty => hasWarranty
      ? '$warrantyDays ${warrantyDays == 1 ? 'día' : 'días'}'
      : 'Sin garantía';

  // Swagger publica PUT, pero no define qué estados permiten editar.
  bool get canEdit => false;
}

class YonkeQuoteFilters {
  const YonkeQuoteFilters({
    this.status,
    this.onlyAvailable,
    this.from,
    this.to,
  });

  final YonkeQuoteStatus? status;
  final bool? onlyAvailable;
  final DateTime? from;
  final DateTime? to;

  int get activeCount =>
      [status, onlyAvailable, from, to].where((value) => value != null).length;
}

class YonkeQuotesPageResult {
  const YonkeQuotesPageResult({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<YonkeQuote> items;
  final int page;
  final bool hasMore;
}

YonkeQuotesPageResult? yonkeQuotesPageFromResponse(dynamic response) {
  final records = _extractRecords(response);
  if (records == null) return null;
  return YonkeQuotesPageResult(
    items: records
        .whereType<Map>()
        .map((record) => yonkeQuoteFromJson(record, isDemo: false))
        .whereType<YonkeQuote>()
        .toList(growable: false),
    page: 1,
    hasMore: false,
  );
}

YonkeQuote? yonkeQuoteFromResponse(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  return data is Map ? yonkeQuoteFromJson(data, isDemo: false) : null;
}

YonkeQuote? yonkeQuoteFromJson(
  Map<dynamic, dynamic> json, {
  required bool isDemo,
}) {
  final assignment = json['solicitudYonkes'];
  final request = assignment is Map ? assignment['solicitudes'] : null;
  final statusRecord = json['solicitudCotizacionEstatus'];
  final id = _text(json['guidId']);
  final requestYonkeId =
      _text(json['solicitudYonkeGuidId']) ??
      (assignment is Map ? _text(assignment['guidId']) : null);
  final requestId = assignment is Map
      ? _text(assignment['solicitudGuidId'])
      : null;
  if (id == null || requestYonkeId == null || requestId == null) return null;

  final imageRecords = json['solicitudCotizacionesImagenes'];
  final imageUrls = imageRecords is List
      ? imageRecords
            .whereType<Map>()
            .map((image) => _text(image['urlImagen']))
            .whereType<String>()
            .where(_isSafeImageUrl)
            .toList(growable: false)
      : const <String>[];
  final statusText = statusRecord is Map
      ? _text(statusRecord['descripcion'])
      : null;
  final brands = request is Map ? request['marcas'] : null;
  final models = request is Map ? request['modelos'] : null;

  return YonkeQuote(
    id: id,
    requestYonkeId: requestYonkeId,
    requestId: requestId,
    part: request is Map
        ? _text(request['piezaBuscada']) ?? 'Pieza sin nombre'
        : 'Pieza sin nombre',
    price: (json['precio'] as num?)?.toDouble() ?? 0,
    available: json['disponible'] == true,
    isNew: json['esNueva'] == true,
    hasWarranty: json['tieneGarantia'] == true,
    warrantyDays: (json['diasGarantia'] as num?)?.toInt() ?? 0,
    shippingAvailable: json['envioDisponible'] == true,
    active: json['activo'] == true,
    status: _statusFromText(statusText),
    createdAt:
        DateTime.tryParse(json['fechaCreacion']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    imageUrls: imageUrls,
    isDemo: isDemo,
    brand: request is Map
        ? _text(request['marca']) ??
              (brands is Map ? _text(brands['nombre']) : null)
        : null,
    model: request is Map
        ? _text(request['modelo']) ??
              (models is Map ? _text(models['nombre']) : null)
        : null,
    year: request is Map ? (request['año'] as num?)?.toInt() : null,
    folio: request is Map ? _text(request['folio']) : null,
    partNumber: _text(json['numeroParte']),
    comments: _text(json['comentarios']),
    deliveryDays: (json['tiempoEntregaDias'] as num?)?.toInt(),
    shippingCost: (json['costoEnvio'] as num?)?.toDouble(),
  );
}

List<dynamic>? _extractRecords(dynamic response) {
  final data = response is Map ? response['data'] : response;
  if (data is List) return data;
  if (data is Map && data['items'] is List) return data['items'] as List;
  if (data is Map && data['registros'] is List) {
    return data['registros'] as List;
  }
  return null;
}

YonkeQuoteStatus _statusFromText(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  if (normalized.contains('acept')) return YonkeQuoteStatus.accepted;
  if (normalized.contains('rechaz')) return YonkeQuoteStatus.rejected;
  if (normalized.contains('cerr') || normalized.contains('cancel')) {
    return YonkeQuoteStatus.closed;
  }
  if (normalized.contains('vista') || normalized.contains('leída')) {
    return YonkeQuoteStatus.viewed;
  }
  if (normalized.contains('envi') || normalized.contains('pend')) {
    return YonkeQuoteStatus.sent;
  }
  return YonkeQuoteStatus.unknown;
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool _isSafeImageUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

String formatYonkeQuotePrice(double value) =>
    '\$${value.toStringAsFixed(2)} MXN';
