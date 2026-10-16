import '../../../core/network/api_file.dart';
import '../../quotes/data/quotes_api.dart';
import '../../requests/data/requests_api.dart';
import '../../yonke_quotes/data/yonke_quote_registry.dart';
import '../domain/yonke_request_detail.dart';
import 'yonke_requests_repository.dart';
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

  Future<void> markAsViewed(String requestYonkeId);
}

class ApiYonkeRequestDetailRepository implements YonkeRequestDetailRepository {
  const ApiYonkeRequestDetailRepository(
    this._requestsApi,
    this._quotesApi, [
    this._registry,
  ]);

  final RequestsApi _requestsApi;
  final QuotesApi _quotesApi;
  final YonkeQuoteRegistry? _registry;

  @override
  Future<YonkeRequestDetail> getDetail({
    required String requestId,
    required String requestYonkeId,
    YonkeRequestSummary? summary,
  }) async {
    final searchId = requestId.isNotEmpty ? requestId : requestYonkeId;
    if (searchId.isEmpty) throw const YonkeRequestDetailNotFoundException();

    YonkeRequestSummary? known = summary ?? await _assignedSummary(searchId);
    final effectiveRequestId =
        known?.requestId ?? (requestId.isNotEmpty ? requestId : requestYonkeId);
    final effectiveRequestYonkeId =
        known?.requestYonkeId ??
        (requestYonkeId.isNotEmpty ? requestYonkeId : requestId);

    dynamic imagesResponse;
    try {
      imagesResponse = await _requestsApi.getImages(effectiveRequestId);
    } catch (_) {
      imagesResponse = null;
    }

    dynamic requestResponse;
    try {
      requestResponse = await _requestsApi.getById(effectiveRequestId);
    } catch (_) {
      if (known != null) {
        requestResponse = {
          'guidId': effectiveRequestId,
          'piezaBuscada': known.part,
          'descripcion': known.description,
          'folio': known.folio,
          'ciudad': known.city,
        };
      }
    }

    final detail = yonkeRequestDetailFromResponses(
      requestResponse: requestResponse ?? {'guidId': effectiveRequestId},
      imagesResponse: imagesResponse,
      requestYonkeId: effectiveRequestYonkeId,
      summary: known,
    );
    if (detail == null) throw const YonkeRequestDetailNotFoundException();
    if (effectiveRequestYonkeId.isNotEmpty) {
      try {
        await _requestsApi.markAsViewedByYonke(effectiveRequestYonkeId);
      } catch (_) {}
    }
    return detail;
  }

  @override
  Future<void> markAsViewed(String requestYonkeId) =>
      _requestsApi.markAsViewedByYonke(requestYonkeId);

  Future<YonkeRequestSummary?> _assignedSummary(String id) async {
    try {
      final items = yonkeAssignedRequestsFromResponse(
        await _requestsApi.getAssignedToYonke(),
      );
      if (items == null) return null;
      final clean = id.trim().toLowerCase();
      return items.where((item) {
        return item.requestYonkeId.toLowerCase() == clean ||
            item.requestId.toLowerCase() == clean;
      }).firstOrNull;
    } catch (_) {
      return null;
    }
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
    final response = await _quotesApi.create(
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
    // Sin lista de cotizaciones del yonke en el API, se recuerda la creada
    // para que su conversación aparezca en la bandeja de mensajes.
    final quoteId = createdQuoteId(response);
    if (quoteId != null) await _registry?.add(quoteId);
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
  var imageUrls = images
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
  if (imageUrls.isEmpty &&
      summary?.imageUrl != null &&
      _isSafeRemoteImage(summary!.imageUrl!)) {
    imageUrls = [summary.imageUrl!];
  }
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
    engine: _text(raw['motor']) ?? summary?.engine,
    transmission: _text(raw['transmicion']) ?? summary?.transmission,
    partNumber: _text(raw['numeroParte']),
    description: _text(raw['descripcion']) ?? summary?.description,
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
  final data = response['data'] ?? response['Data'];
  return data is Map ? data : response;
}

List<dynamic> _unwrapList(dynamic response) {
  if (response is List) return response;
  if (response is Map) {
    final list = response['data'] ?? response['Data'];
    if (list is List) return list;
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
  if (normalized.contains('acept')) return YonkeRequestStatus.accepted;
  if (normalized.contains('cotiz')) return YonkeRequestStatus.quoted;
  if (normalized.contains('vista')) return YonkeRequestStatus.viewed;
  if (normalized.contains('cerr')) return YonkeRequestStatus.closed;
  if (normalized.contains('nueva')) return YonkeRequestStatus.newRequest;
  return YonkeRequestStatus.unknown;
}
