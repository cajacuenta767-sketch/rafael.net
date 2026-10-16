import 'quote_payment_status.dart';

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
    this.paymentStatus = QuotePaymentStatus.pending,
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
  final QuotePaymentStatus paymentStatus;

  bool get isPaid => paymentStatus == QuotePaymentStatus.paid;

  /// Nombre que se muestra mientras no se conoce el yonke real.
  static const pendingYonkeName = 'Yonke asignado';

  bool get hasYonkeIdentity =>
      yonkeName.trim().isNotEmpty && yonkeName != pendingYonkeName;

  ClientQuote withYonke({
    required String yonkeId,
    required String yonkeName,
    String? logoUrl,
    String? phone,
  }) => ClientQuote(
    id: id,
    requestId: requestId,
    yonkeId: yonkeId,
    yonkeName: yonkeName,
    price: price,
    available: available,
    isNew: isNew,
    hasWarranty: hasWarranty,
    warrantyDays: warrantyDays,
    shippingAvailable: shippingAvailable,
    active: active,
    status: status,
    imageUrls: imageUrls,
    logoUrl: logoUrl ?? this.logoUrl,
    requestFolio: requestFolio,
    partName: partName,
    brand: brand,
    model: model,
    year: year,
    createdAt: createdAt,
    phone: phone ?? this.phone,
    partNumber: partNumber,
    comments: comments,
    deliveryDays: deliveryDays,
    shippingCost: shippingCost,
    paymentStatus: paymentStatus,
  );

  ClientQuote withStatus(String newStatus) => ClientQuote(
    id: id,
    requestId: requestId,
    yonkeId: yonkeId,
    yonkeName: yonkeName,
    price: price,
    available: available,
    isNew: isNew,
    hasWarranty: hasWarranty,
    warrantyDays: warrantyDays,
    shippingAvailable: shippingAvailable,
    active: active,
    status: newStatus,
    imageUrls: imageUrls,
    logoUrl: logoUrl,
    requestFolio: requestFolio,
    partName: partName,
    brand: brand,
    model: model,
    year: year,
    createdAt: createdAt,
    phone: phone,
    partNumber: partNumber,
    comments: comments,
    deliveryDays: deliveryDays,
    shippingCost: shippingCost,
    paymentStatus: paymentStatus,
  );

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
  final rawRequestYonke = json['solicitudYonkes'] ?? json['SolicitudYonkes'];
  final requestYonke = rawRequestYonke is Map ? rawRequestYonke : null;
  final yonke = requestYonke?['yonkes'] ?? requestYonke?['Yonkes'];
  final status =
      json['solicitudCotizacionEstatus'] ?? json['SolicitudCotizacionEstatus'];
  final id = json['guidId']?.toString() ?? json['GuidId']?.toString() ?? '';
  final requestId =
      requestYonke?['solicitudGuidId']?.toString() ??
      requestYonke?['SolicitudGuidId']?.toString() ??
      json['solicitudGuidId']?.toString() ??
      json['SolicitudGuidId']?.toString() ??
      '';
  final requestFolio = (json['folio'] ?? json['Folio'])?.toString();
  if (id.isEmpty || (requestId.isEmpty && (requestFolio?.isEmpty ?? true))) {
    return null;
  }

  final imageRecords =
      json['solicitudCotizacionesImagenes'] ??
      json['SolicitudCotizacionesImagenes'];
  final imageUrls = imageRecords is List
      ? imageRecords
            .whereType<Map>()
            .map(
              (image) => (image['urlImagen'] ?? image['UrlImagen'])?.toString(),
            )
            .whereType<String>()
            .where(_isSafeImageUrl)
            .toList()
      : const <String>[];

  return ClientQuote(
    id: id,
    requestId: requestId,
    requestFolio: requestFolio,
    partName: _cleanText(json['piezaBuscada'] ?? json['PiezaBuscada']),
    brand: _cleanText(json['marca'] ?? json['Marca']),
    model: _cleanText(json['modelo'] ?? json['Modelo']),
    year: ((json['año'] ?? json['anio'] ?? json['Año'] ?? json['Anio']) as num?)
        ?.toInt(),
    createdAt: DateTime.tryParse(
      json['fechaCreacionCotizacion']?.toString() ??
          json['FechaCreacionCotizacion']?.toString() ??
          json['fechaCreacion']?.toString() ??
          json['FechaCreacion']?.toString() ??
          '',
    )?.toLocal(),
    // `solicitudYonkeGuidId` identifica la asignación, no al yonke.
    yonkeId:
        requestYonke?['yonkeGuidId']?.toString() ??
        requestYonke?['YonkeGuidId']?.toString() ??
        json['yonkeGuidId']?.toString() ??
        json['YonkeGuidId']?.toString() ??
        '',
    yonkeName: yonke is Map && (yonke['nombre'] ?? yonke['Nombre']) != null
        ? (yonke['nombre'] ?? yonke['Nombre']).toString()
        : (json['yonkeNombre'] ?? json['YonkeNombre'])?.toString() ??
              ClientQuote.pendingYonkeName,
    logoUrl:
        yonke is Map &&
            _isSafeImageUrl((yonke['logoUrl'] ?? yonke['LogoUrl'])?.toString())
        ? (yonke['logoUrl'] ?? yonke['LogoUrl']).toString()
        : _isSafeImageUrl((json['logoUrl'] ?? json['LogoUrl'])?.toString())
        ? (json['logoUrl'] ?? json['LogoUrl']).toString()
        : null,
    phone: yonke is Map
        ? (yonke['telefono'] ?? yonke['Telefono'])?.toString()
        : null,
    price: ((json['precio'] ?? json['Precio']) as num?)?.toDouble() ?? 0,
    available: (json['disponible'] ?? json['Disponible']) == true,
    isNew: (json['esNueva'] ?? json['EsNueva']) == true,
    partNumber: (json['numeroParte'] ?? json['NumeroParte'])?.toString(),
    comments: (json['comentarios'] ?? json['Comentarios'])?.toString(),
    deliveryDays:
        ((json['tiempoEntregaDias'] ?? json['TiempoEntregaDias']) as num?)
            ?.toInt(),
    hasWarranty: (json['tieneGarantia'] ?? json['TieneGarantia']) == true,
    warrantyDays:
        ((json['diasGarantia'] ?? json['DiasGarantia']) as num?)?.toInt() ?? 0,
    shippingAvailable:
        (json['envioDisponible'] ?? json['EnvioDisponible']) == true,
    shippingCost: ((json['costoEnvio'] ?? json['CostoEnvio']) as num?)
        ?.toDouble(),
    active: fromActiveList || (json['activo'] ?? json['Activo']) == true,
    status: _mapQuoteStatus(
      json['estatusId'] ?? json['EstatusId'],
      status,
      json['estatusSolicitud'] ?? json['EstatusSolicitud'],
    ),
    imageUrls: imageUrls,
    paymentStatus: QuotePaymentStatus.fromValue(
      json['estadoPago'] ?? json['EstadoPago'],
    ),
  );
}

bool _isSafeImageUrl(String? value) {
  if (value == null || value.isEmpty) return false;
  if (value.startsWith('asset://assets/')) return true;
  if (value.startsWith('data:image/') && value.contains(';base64,')) {
    return true;
  }
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;
}

String formatQuotePrice(double value) => '\$${value.toStringAsFixed(2)}';

String? _cleanText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String _mapQuoteStatus(
  dynamic estatusId,
  dynamic statusObj,
  dynamic statusDesc,
) {
  if (statusObj is Map) {
    final desc = statusObj['descripcion'] ??
        statusObj['Descripcion'] ??
        statusObj['estatus'] ??
        statusObj['Estatus'];
    if (desc != null && desc.toString().trim().isNotEmpty) {
      return desc.toString().trim();
    }
  }
  if (statusDesc != null && statusDesc.toString().trim().isNotEmpty) {
    return statusDesc.toString().trim();
  }
  final id = estatusId is num ? estatusId.toInt() : int.tryParse('$estatusId');
  return switch (id) {
    1 => 'Activa',
    2 => 'Aceptada',
    3 => 'Cotizada',
    4 => 'Rechazada',
    5 => 'Expirada',
    6 => 'Cancelada',
    7 => 'Aceptada',
    8 => 'Recibida',
    _ => 'Cotizada',
  };
}
