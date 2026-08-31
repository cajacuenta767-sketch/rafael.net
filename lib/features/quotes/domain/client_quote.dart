class ClientQuote {
  const ClientQuote({
    required this.id,
    required this.requestId,
    required this.yonkeId,
    required this.yonkeName,
    required this.price,
    required this.available,
    required this.isNew,
    required this.hasWarranty,
    required this.warrantyDays,
    required this.shippingAvailable,
    required this.active,
    required this.status,
    required this.imageUrls,
    this.logoUrl,
    this.phone,
    this.partNumber,
    this.comments,
    this.deliveryDays,
    this.shippingCost,
  });

  final String id;
  final String requestId;
  final String yonkeId;
  final String yonkeName;
  final String? logoUrl;
  final String? phone;
  final double price;
  final bool available;
  final bool isNew;
  final String? partNumber;
  final String? comments;
  final int? deliveryDays;
  final bool hasWarranty;
  final int warrantyDays;
  final bool shippingAvailable;
  final double? shippingCost;
  final bool active;
  final String status;
  final List<String> imageUrls;

  String get condition => isNew ? 'Nueva' : 'Usada';
  String get availability => available ? 'Disponible' : 'No disponible';
  String get warranty => hasWarranty
      ? '$warrantyDays ${warrantyDays == 1 ? 'día' : 'días'}'
      : 'Sin garantía';
}

List<ClientQuote> clientQuotesFromDashboard(dynamic response) {
  final data = response is Map ? response['data'] : response;
  final records = switch (data) {
    List() => data,
    Map() when data['items'] is List => data['items'] as List,
    Map() when data['registros'] is List => data['registros'] as List,
    _ => const <dynamic>[],
  };
  return records
      .whereType<Map>()
      .map(clientQuoteFromJson)
      .whereType<ClientQuote>()
      .toList();
}

ClientQuote? clientQuoteFromResponse(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  return data is Map ? clientQuoteFromJson(data) : null;
}

ClientQuote? clientQuoteFromJson(Map<dynamic, dynamic> json) {
  final requestYonke = json['solicitudYonkes'];
  if (requestYonke is! Map) return null;
  final yonke = requestYonke['yonkes'];
  final status = json['solicitudCotizacionEstatus'];
  final id = json['guidId']?.toString() ?? '';
  final requestId = requestYonke['solicitudGuidId']?.toString() ?? '';
  if (id.isEmpty || requestId.isEmpty) return null;

  final imageRecords = json['solicitudCotizacionesImagenes'];
  final imageUrls = imageRecords is List
      ? imageRecords
            .whereType<Map>()
            .map((image) => image['urlImagen']?.toString())
            .whereType<String>()
            .where(_isSafeImageUrl)
            .toList()
      : const <String>[];

  return ClientQuote(
    id: id,
    requestId: requestId,
    yonkeId: requestYonke['yonkeGuidId']?.toString() ?? '',
    yonkeName: yonke is Map && yonke['nombre'] != null
        ? yonke['nombre'].toString()
        : 'Yonke sin nombre',
    logoUrl: yonke is Map && _isSafeImageUrl(yonke['logoUrl']?.toString())
        ? yonke['logoUrl'].toString()
        : null,
    phone: yonke is Map ? yonke['telefono']?.toString() : null,
    price: (json['precio'] as num?)?.toDouble() ?? 0,
    available: json['disponible'] == true,
    isNew: json['esNueva'] == true,
    partNumber: json['numeroParte']?.toString(),
    comments: json['comentarios']?.toString(),
    deliveryDays: (json['tiempoEntregaDias'] as num?)?.toInt(),
    hasWarranty: json['tieneGarantia'] == true,
    warrantyDays: (json['diasGarantia'] as num?)?.toInt() ?? 0,
    shippingAvailable: json['envioDisponible'] == true,
    shippingCost: (json['costoEnvio'] as num?)?.toDouble(),
    active: json['activo'] == true,
    status: status is Map && status['descripcion'] != null
        ? status['descripcion'].toString()
        : 'Sin estado',
    imageUrls: imageUrls,
  );
}

bool _isSafeImageUrl(String? value) {
  if (value == null || value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

String formatQuotePrice(double value) => '\$${value.toStringAsFixed(2)}';

List<ClientQuote> mockQuotesForRequest(String requestId) {
  if (requestId == 'mock-request-faro') return const [_mockFaroQuote];
  if (requestId == 'mock-request-alternador') return _mockQuotes;
  return const [];
}

ClientQuote? mockQuoteById(String quoteId) {
  for (final quote in [..._mockQuotes, _mockFaroQuote]) {
    if (quote.id == quoteId) return quote;
  }
  return null;
}

const _mockQuotes = [
  ClientQuote(
    id: 'mock-quote-norte',
    requestId: 'mock-request-alternador',
    yonkeId: 'mock-yonke-norte',
    yonkeName: 'Yonke de prueba Norte',
    price: 1700,
    available: true,
    isNew: false,
    hasWarranty: true,
    warrantyDays: 15,
    shippingAvailable: true,
    shippingCost: 120,
    deliveryDays: 2,
    active: true,
    status: 'Enviada',
    imageUrls: [],
    comments: 'Pieza usada, probada y en buen estado.',
  ),
  ClientQuote(
    id: 'mock-quote-centro',
    requestId: 'mock-request-alternador',
    yonkeId: 'mock-yonke-centro',
    yonkeName: 'Yonke de prueba Centro',
    price: 1850,
    available: true,
    isNew: false,
    hasWarranty: true,
    warrantyDays: 30,
    shippingAvailable: false,
    active: true,
    status: 'Enviada',
    imageUrls: [],
    comments: 'Alternador original usado y probado.',
  ),
  ClientQuote(
    id: 'mock-quote-sur',
    requestId: 'mock-request-alternador',
    yonkeId: 'mock-yonke-sur',
    yonkeName: 'Yonke de prueba Sur',
    price: 2100,
    available: true,
    isNew: true,
    hasWarranty: true,
    warrantyDays: 45,
    shippingAvailable: true,
    shippingCost: 0,
    deliveryDays: 4,
    active: true,
    status: 'Enviada',
    imageUrls: [],
    comments: 'Pieza nueva compatible.',
  ),
];

const _mockFaroQuote = ClientQuote(
  id: 'mock-quote-faro',
  requestId: 'mock-request-faro',
  yonkeId: 'mock-yonke-faro',
  yonkeName: 'Yonke de prueba Faro',
  price: 950,
  available: true,
  isNew: false,
  hasWarranty: true,
  warrantyDays: 15,
  shippingAvailable: false,
  active: true,
  status: 'Enviada',
  imageUrls: [],
  comments: 'Faro usado en buen estado.',
);
