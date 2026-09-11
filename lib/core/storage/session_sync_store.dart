import 'dart:convert';
import 'dart:math';

import '../../features/quotes/domain/client_quote.dart';
import '../../features/requests/domain/client_request.dart';
import '../../features/requests/domain/request_draft.dart';
import '../../features/yonke_quotes/domain/yonke_quote.dart';
import '../../features/yonke_requests/domain/yonke_request_detail.dart';
import '../../features/yonke_requests/domain/yonke_request_summary.dart';

String generateSessionUuid() {
  final random = Random();
  String hex(int length) => List.generate(
        length,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
}

/// Almacen en memoria para sincronizar cotizaciones, estados y solicitudes
/// entre la sesion activa del Yonke y del Cliente cuando ocurren discrepancias
/// de asignacion en el servidor (ej. SolicitudYonkes pendiente o limite de requests).
class SessionSyncStore {
  SessionSyncStore._();
  static final SessionSyncStore instance = SessionSyncStore._();

  final List<YonkeQuote> _yonkeQuotes = [];
  final List<ClientQuote> _clientQuotes = [];
  final List<ClientRequestSummary> _clientRequests = [];
  final List<YonkeRequestSummary> _yonkeRequests = [];
  final Set<String> _unavailableRequestIds = {};
  final Set<String> _quotedRequestIds = {};

  List<YonkeQuote> get yonkeQuotes => List.unmodifiable(_yonkeQuotes);
  List<ClientQuote> get clientQuotes => List.unmodifiable(_clientQuotes);
  List<ClientRequestSummary> get clientRequests =>
      List.unmodifiable(_clientRequests);
  List<YonkeRequestSummary> get yonkeRequests =>
      List.unmodifiable(_yonkeRequests);

  bool isUnavailable(String requestId) =>
      _unavailableRequestIds.contains(requestId);

  bool isQuoted(String requestId) => _quotedRequestIds.contains(requestId);

  void recordUnavailable(String requestId) {
    _unavailableRequestIds.add(requestId);
  }

  YonkeQuote recordQuote({
    required String requestYonkeId,
    required YonkeQuoteSubmission submission,
    YonkeRequestDetail? detail,
    String? yonkeName,
  }) {
    final quoteId = generateSessionUuid();
    final now = DateTime.now();
    _quotedRequestIds.add(requestYonkeId);

    final imageUrls = submission.images
        .map((img) => 'data:image/jpeg;base64,${base64Encode(img.bytes)}')
        .toList();

    final yQuote = YonkeQuote(
      id: quoteId,
      requestYonkeId: requestYonkeId,
      requestId: detail?.requestId ?? requestYonkeId,
      part: detail?.part ?? 'Autoparte',
      price: submission.price,
      available: true,
      isNew: submission.isNew,
      hasWarranty: submission.hasWarranty,
      warrantyDays: submission.warrantyDays,
      shippingAvailable: submission.shippingAvailable,
      active: true,
      status: YonkeQuoteStatus.sent,
      createdAt: now,
      imageUrls: imageUrls,
      brand: detail?.brand,
      model: detail?.model,
      year: detail?.year,
      folio: detail?.folio,
      partNumber: submission.partNumber,
      comments: submission.comments,
      deliveryDays: submission.deliveryDays,
      shippingCost: submission.shippingCost,
    );
    _yonkeQuotes.removeWhere((q) => q.requestYonkeId == requestYonkeId);
    _yonkeQuotes.insert(0, yQuote);

    final cQuote = ClientQuote(
      id: quoteId,
      requestId: detail?.requestId ?? requestYonkeId,
      yonkeId: 'test-yonke-guid',
      yonkeName: yonkeName ?? 'Yonke Test',
      price: submission.price,
      available: true,
      isNew: submission.isNew,
      hasWarranty: submission.hasWarranty,
      warrantyDays: submission.warrantyDays,
      shippingAvailable: submission.shippingAvailable,
      shippingCost: submission.shippingCost,
      active: true,
      status: 'Enviada',
      imageUrls: imageUrls,
      requestFolio: detail?.folio,
      partName: detail?.part,
      brand: detail?.brand,
      model: detail?.model,
      year: detail?.year,
      createdAt: now,
      comments: submission.comments,
      partNumber: submission.partNumber,
      deliveryDays: submission.deliveryDays,
    );
    _clientQuotes.removeWhere(
      (q) => q.requestId == (detail?.requestId ?? requestYonkeId),
    );
    _clientQuotes.insert(0, cQuote);

    return yQuote;
  }

  void recordDraftRequest(RequestDraft draft, {required String requestId}) {
    final now = DateTime.now();
    final suffix = requestId.length > 4 ? requestId.substring(0, 4).toUpperCase() : 'TEST';
    final folio = 'SOL-${now.year}${now.month.toString().padLeft(2, '0')}-$suffix';
    final summary = ClientRequestSummary(
      id: requestId,
      part: draft.part,
      status: 'Enviada',
      quoteCount: 0,
      brand: draft.brandName,
      model: draft.modelName,
      year: draft.year,
      folio: folio,
      createdAt: now,
      imageUrl: draft.photos.isNotEmpty ? draft.photos.first.file.path : null,
    );
    _clientRequests.insert(0, summary);

    final yonkeSummary = YonkeRequestSummary(
      requestId: requestId,
      requestYonkeId: requestId,
      part: draft.part,
      status: YonkeRequestStatus.newRequest,
      receivedAt: now,
      brand: draft.brandName,
      model: draft.modelName,
      year: draft.year,
      city: 'Nogales, Sonora',
      folio: folio,
      photoCount: draft.photos.length,
      hasQuote: false,
    );
    _yonkeRequests.insert(0, yonkeSummary);
  }

  void removeRequest(String requestId) {
    _clientRequests.removeWhere((r) => r.id == requestId);
    _yonkeRequests.removeWhere((r) => r.requestId == requestId);
    _yonkeQuotes.removeWhere((q) => q.requestId == requestId);
    _clientQuotes.removeWhere((q) => q.requestId == requestId);
  }

  void clear() {
    _yonkeQuotes.clear();
    _clientQuotes.clear();
    _clientRequests.clear();
    _yonkeRequests.clear();
    _unavailableRequestIds.clear();
    _quotedRequestIds.clear();
  }
}
