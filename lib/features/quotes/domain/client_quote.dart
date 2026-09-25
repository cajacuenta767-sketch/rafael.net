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
    this.requestFolio,
    this.partName,
    this.brand,
    this.model,
    this.year,
    this.createdAt,
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
  final String? requestFolio;
  final String? partName;
  final String? brand;
  final String? model;
  final int? year;
  final DateTime? createdAt;
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
  // `mis-cotizaciones` ya filtra `Activo` en el servidor, pero su proyección
  // no incluye el campo (siempre llega `false`); por eso aquí se asume activo.
  return records
      .whereType<Map>()
      .map((json) => clientQuoteFromJson(json, fromActiveList: true))
      .whereType<ClientQuote>()
      .toList();
}

ClientQuote? clientQuoteFromResponse(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  return data is Map ? clientQuoteFromJson(data) : null;
}

ClientQuote? clientQuoteFromJson(
  Map<dynamic, dynamic> json, {
  bool fromActiveList = false,
}) {
  final rawRequestYonke = json['solicitudYonkes'];
  final requestYonke = rawRequestYonke is Map ? rawRequestYonke : null;
  final yonke = requestYonke?['yonkes'];
  final status = json['solicitudCotizacionEstatus'];
  final id = json['guidId']?.toString() ?? '';
  final requestId =
      requestYonke?['solicitudGuidId']?.toString() ??
      json['solicitudGuidId']?.toString() ??
      '';
  final requestFolio = json['folio']?.toString();
  if (id.isEmpty || (requestId.isEmpty && (requestFolio?.isEmpty ?? true))) {
    return null;
  }

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
    requestFolio: requestFolio,
    partName: _cleanText(json['piezaBuscada']),
    brand: _cleanText(json['marca']),
    model: _cleanText(json['modelo']),
    year: ((json['año'] ?? json['anio']) as num?)?.toInt(),
    createdAt: DateTime.tryParse(
      json['fechaCreacionCotizacion']?.toString() ??
          json['fechaCreacion']?.toString() ??
          '',
    )?.toLocal(),
    // `solicitudYonkeGuidId` identifica la asignación, no al yonke.
    yonkeId:
        requestYonke?['yonkeGuidId']?.toString() ??
        json['yonkeGuidId']?.toString() ??
        '',
    yonkeName: yonke is Map && yonke['nombre'] != null
        ? yonke['nombre'].toString()
        : json['yonkeNombre']?.toString() ?? 'Yonke asignado',
    logoUrl: yonke is Map && _isSafeImageUrl(yonke['logoUrl']?.toString())
        ? yonke['logoUrl'].toString()
        : _isSafeImageUrl(json['logoUrl']?.toString())
        ? json['logoUrl'].toString()
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
    active: fromActiveList || json['activo'] == true,
    status: status is Map && status['descripcion'] != null
        ? status['descripcion'].toString()
        : json['estatusSolicitud']?.toString() ?? 'Sin estado',
    imageUrls: imageUrls,
  );
}

bool _isSafeImageUrl(String? value) {
  if (value == null || value.isEmpty) return false;
  if (value.startsWith('asset://assets/')) return true;
  if (value.startsWith('data:image/') && value.contains(';base64,')) {
    return true;
  }
  final uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

String formatQuotePrice(double value) => '\$${value.toStringAsFixed(2)}';

String? _cleanText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
