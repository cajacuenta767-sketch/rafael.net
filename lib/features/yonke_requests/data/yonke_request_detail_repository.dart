import '../../../core/network/api_file.dart';
import '../../quotes/data/quotes_api.dart';
import '../../requests/data/requests_api.dart';
import '../domain/yonke_request_detail.dart';
import '../domain/yonke_request_summary.dart';
import 'yonke_requests_repository.dart';

abstract interface class YonkeRequestDetailRepository {
  bool get usesDemoData;

  Future<YonkeRequestDetail> getDetail({
    required String requestId,
    required String requestYonkeId,
    YonkeRequestSummary? summary,
  });

  Future<void> markUnavailable(String requestYonkeId);

  Future<void> submitQuote(
    String requestYonkeId,
    YonkeQuoteSubmission submission,
  );
}

class ApiYonkeRequestDetailRepository implements YonkeRequestDetailRepository {
  const ApiYonkeRequestDetailRepository(this._requestsApi, this._quotesApi);

  final RequestsApi _requestsApi;
  final QuotesApi _quotesApi;

  @override
  bool get usesDemoData => false;

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
  Future<void> markUnavailable(String requestYonkeId) async {
    await _quotesApi.create(
      requestYonkeId: requestYonkeId,
      fields: const {'Disponible': false},
    );
  }

  @override
  Future<void> submitQuote(
    String requestYonkeId,
    YonkeQuoteSubmission submission,
  ) async {
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

class DemoYonkeRequestDetailRepository implements YonkeRequestDetailRepository {
  const DemoYonkeRequestDetailRepository();

  @override
  bool get usesDemoData => true;

  @override
  Future<YonkeRequestDetail> getDetail({
    required String requestId,
    required String requestYonkeId,
    YonkeRequestSummary? summary,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final detail = demoYonkeRequestDetail(
      requestId: requestId,
      requestYonkeId: requestYonkeId,
      summary: summary,
    );
    if (detail == null) throw const YonkeRequestDetailNotFoundException();
    return detail;
  }

  @override
  Future<void> markUnavailable(String requestYonkeId) async {
    _requireDemoId(requestYonkeId);
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }

  @override
  Future<void> submitQuote(
    String requestYonkeId,
    YonkeQuoteSubmission submission,
  ) async {
    _requireDemoId(requestYonkeId);
    await Future<void>.delayed(const Duration(milliseconds: 220));
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
    isDemo: false,
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

YonkeRequestDetail? demoYonkeRequestDetail({
  required String requestId,
  required String requestYonkeId,
  YonkeRequestSummary? summary,
}) {
  if (!requestId.startsWith('demo-') || !requestYonkeId.startsWith('demo-')) {
    return null;
  }
  final current =
      summary ??
      demoYonkeRequests.firstWhereOrNull((item) => item.requestId == requestId);
  if (current == null) return null;
  final isAlternator = requestId.contains('alternador');
  return YonkeRequestDetail(
    requestId: current.requestId,
    requestYonkeId: current.requestYonkeId,
    part: current.part,
    status: current.status,
    imageUrls: List.generate(
      current.photoCount,
      (index) => 'demo://photo-${index + 1}',
    ),
    isDemo: true,
    brandId: isAlternator ? 1 : null,
    brand: current.brand,
    model: current.model,
    year: current.year,
    engine: isAlternator ? '2.0 L' : null,
    transmission: isAlternator ? 'Automática' : null,
    partNumber: isAlternator ? '23100-3SH1A' : null,
    description: isAlternator
        ? 'Original o compatible, funcionando y en buen estado.'
        : 'Se requiere una pieza completa y en buen estado.',
    folio: current.folio,
    city: current.city,
    receivedAt: current.receivedAt,
    closed: current.status == YonkeRequestStatus.closed,
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

void _requireDemoId(String value) {
  if (!value.startsWith('demo-')) {
    throw StateError('El repositorio de prueba solo admite IDs demo.');
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T value) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}
