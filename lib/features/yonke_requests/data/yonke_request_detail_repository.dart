import '../../../core/network/api_file.dart';
import '../../quotes/data/quotes_api.dart';
import '../../requests/data/requests_api.dart';
import '../domain/yonke_request_detail.dart';
import '../domain/yonke_request_summary.dart';

abstract interface class YonkeRequestDetailRepository {
  Future<YonkeRequestDetail> getDetail({
    required String requestId,
    required String requestYonkeId,
    YonkeRequestSummary? summary,
  });

  /// Responde que la pieza no está disponible. La API no publica una
  /// operación de rechazo: se registra una cotización con `Disponible=false`
  /// y el resto de campos obligatorios en cero.
  Future<void> markUnavailable(String requestYonkeId, {int? brandId});

  Future<void> submitQuote(
    String requestYonkeId,
    YonkeQuoteSubmission submission, {
    YonkeRequestDetail? detail,
  });
}

class ApiYonkeRequestDetailRepository implements YonkeRequestDetailRepository {
  const ApiYonkeRequestDetailRepository(this._requestsApi, this._quotesApi);

  final RequestsApi _requestsApi;
  final QuotesApi _quotesApi;

  @override
  Future<YonkeRequestDetail> getDetail({
    required String requestId,
    required String requestYonkeId,
    YonkeRequestSummary? summary,
  }) async {
    if (requestId.isEmpty) throw const YonkeRequestDetailNotFoundException();
    final responses = await Future.wait<dynamic>([
      _requestsApi.getById(requestId),
      _requestsApi.getImages(requestId),
    ]);
    final detail = yonkeRequestDetailFromResponses(
      requestResponse: responses[0],
      imagesResponse: responses[1],
      requestYonkeId: requestYonkeId,
      summary: summary,
    );
    if (detail == null) throw const YonkeRequestDetailNotFoundException();
    return detail;
  }

  @override
  Future<void> markUnavailable(String requestYonkeId, {int? brandId}) async {
    await _quotesApi.create(
      requestYonkeId: requestYonkeId,
      fields: {
        'Precio': 0,
        'Disponible': false,
        'EsNueva': false,
        'MarcaId': ?brandId,
        'Comentarios': 'Pieza no disponible',
        'DiasGarantia': 0,
        'EnvioDisponible': false,
        'TieneGarantia': false,
      },
    );
  }

  @override
  Future<void> submitQuote(
    String requestYonkeId,
    YonkeQuoteSubmission submission, {
    YonkeRequestDetail? detail,
  }) async {
    await _quotesApi.create(
      requestYonkeId: requestYonkeId,
      fields: {
        'Precio': submission.price,
        'Disponible': true,
        'EsNueva': submission.isNew,
        if (submission.brandId != null) 'MarcaId': submission.brandId,
        if (_notBlank(submission.partNumber))
          'NumeroParte': submission.partNumber!.trim(),
        if (_notBlank(submission.comments))
          'Comentarios': submission.comments!.trim(),
        if (submission.deliveryDays != null)
          'TiempoEntregaDias': submission.deliveryDays,
        'DiasGarantia': submission.hasWarranty ? submission.warrantyDays : 0,
        'EnvioDisponible': submission.shippingAvailable,
        if (submission.shippingAvailable && submission.shippingCost != null)
          'CostoEnvio': submission.shippingCost,
        'TieneGarantia': submission.hasWarranty,
      },
      images: submission.images
          .map(
            (image) => ApiFile(
              fieldName: 'Imagenes',
              fileName: image.fileName,
              bytes: image.bytes,
            ),
          )
          .toList(),
    );
  }
}

class YonkeRequestDetailNotFoundException implements Exception {
  const YonkeRequestDetailNotFoundException();
}

YonkeRequestDetail? yonkeRequestDetailFromResponses({
  required dynamic requestResponse,
  required dynamic imagesResponse,
  required String requestYonkeId,
  YonkeRequestSummary? summary,
}) {
  final raw = _unwrapMap(requestResponse);
  if (raw == null) return null;

  final images = _unwrapList(imagesResponse);
  final imageUrls = images
      .whereType<Map>()
      .map(
        (image) =>
            image['urlImagen']?.toString() ??
            image['imagenUrl']?.toString() ??
            image['url']?.toString(),
      )
      .whereType<String>()
      .where(_isSafeRemoteImage)
      .toList(growable: false);
  final closed = raw['cerrada'] == true;

  return YonkeRequestDetail(
    requestId: raw['guidId']?.toString() ?? summary?.requestId ?? '',
    requestYonkeId: requestYonkeId,
    part: _text(raw['piezaBuscada']) ?? summary?.part ?? 'Pieza sin nombre',
    status: closed
        ? YonkeRequestStatus.closed
        : summary?.status ?? _statusFromText(_text(raw['estatusSolicitud'])),
    imageUrls: imageUrls,
    brandId: (raw['marcaId'] as num?)?.toInt(),
    brand: _text(raw['marca']) ?? summary?.brand,
    model: _text(raw['modelo']) ?? summary?.model,
    year: (raw['año'] as num?)?.toInt() ?? summary?.year,
    engine: _text(raw['motor']),
    transmission: _text(raw['transmicion']),
    partNumber: _text(raw['numeroParte']),
    description: _text(raw['descripcion']),
    folio: _text(raw['folio']) ?? summary?.folio,
    city: summary?.city,
    receivedAt:
        DateTime.tryParse(raw['fechaCreacion']?.toString() ?? '') ??
        summary?.receivedAt,
    closed: closed,
  );
}

Map<dynamic, dynamic>? _unwrapMap(dynamic response) {
  if (response is! Map) return null;
  final data = response['data'];
  return data is Map ? data : response;
}

List<dynamic> _unwrapList(dynamic response) {
  if (response is List) return response;
  if (response is Map && response['data'] is List) {
    return response['data'] as List<dynamic>;
  }
  return const [];
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool _notBlank(String? value) => value != null && value.trim().isNotEmpty;

bool _isSafeRemoteImage(String value) {
  if (value.startsWith('asset://assets/')) return true;
  if (value.startsWith('data:image/') && value.contains(';base64,')) {
    return true;
  }
  final uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

YonkeRequestStatus _statusFromText(String? value) {
  final normalized = value?.toLowerCase() ?? '';
  if (normalized.contains('cotiz')) return YonkeRequestStatus.quoted;
  if (normalized.contains('vista')) return YonkeRequestStatus.viewed;
  if (normalized.contains('cerr')) return YonkeRequestStatus.closed;
  if (normalized.contains('nueva')) return YonkeRequestStatus.newRequest;
  return YonkeRequestStatus.unknown;
}
