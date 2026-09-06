import '../domain/client_order_creation.dart';
import '../domain/client_order.dart';
import '../../../core/network/api_exception.dart';
import 'orders_api.dart';

abstract interface class ClientOrdersRepository {
  Future<ClientOrderCreationResult> createOrder(String quoteId);
  Future<ClientOrder?> getForQuote(String quoteId);
  Future<ClientOrder> getById(String orderId, {String? quoteId});
  Future<ClientOrder> cancel(ClientOrder order);
}

/// Envía únicamente el identificador de cotización que pide CrearOrden. La API
/// aún no documenta el JSON del resultado, así que solo usa un id si es claro.
class ApiClientOrdersRepository implements ClientOrdersRepository {
  const ApiClientOrdersRepository(this._ordersApi);

  final OrdersApi _ordersApi;

  @override
  Future<ClientOrderCreationResult> createOrder(String quoteId) async {
    final response = await _ordersApi.create(quoteId);
    final orderId = _orderIdFromResponse(response);
    return ClientOrderCreationResult(
      orderId: orderId,
      responseContractPending: orderId == null,
    );
  }

  @override
  Future<ClientOrder?> getForQuote(String quoteId) async {
    try {
      final response = await _ordersApi.getByQuote(quoteId);
      return _orderFromResponse(response, quoteId: quoteId);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<ClientOrder> getById(String orderId, {String? quoteId}) async {
    final response = await _ordersApi.getById(orderId);
    return _orderFromResponse(
      response,
      fallbackId: orderId,
      quoteId: quoteId ?? '',
    );
  }

  @override
  Future<ClientOrder> cancel(ClientOrder order) async {
    final orderId = order.id;
    if (orderId == null || orderId.isEmpty) {
      throw const ApiException(
        message: 'La orden no tiene un identificador válido.',
      );
    }
    final response = await _ordersApi.cancel(orderId);
    final updated = _orderFromResponse(
      response,
      fallbackId: orderId,
      quoteId: order.quoteId,
    );
    // El endpoint confirma con 200 pero Swagger aún no define el cuerpo.
    return updated.copyWith(
      status: updated.status ?? 'Cancelada',
      isCancelled: true,
      canCancel: false,
    );
  }
}

String? _orderIdFromResponse(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data is String && data.trim().isNotEmpty) return data.trim();
  if (data is! Map) return null;
  for (final key in const ['guidId', 'ordenGuidId', 'orderId', 'id']) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

ClientOrder _orderFromResponse(
  dynamic response, {
  required String quoteId,
  String? fallbackId,
}) {
  final data = response is Map ? response['data'] ?? response : response;
  final json = data is Map ? data : const <dynamic, dynamic>{};
  final statusValue =
      json['estatus'] ??
      json['estado'] ??
      json['status'] ??
      json['ordenEstatus'];
  final status = statusValue is Map
      ? (statusValue['descripcion'] ?? statusValue['nombre'])?.toString()
      : statusValue?.toString();
  final normalizedStatus = (status ?? '').toLowerCase();
  final cancelled =
      json['cancelada'] == true ||
      json['activo'] == false ||
      normalizedStatus.contains('cancel');
  final completed =
      normalizedStatus.contains('complet') ||
      normalizedStatus.contains('entreg') ||
      normalizedStatus.contains('finaliz');
  final explicitCanCancel = json['puedeCancelar'] ?? json['cancelable'];

  return ClientOrder(
    id: _orderIdFromResponse(response) ?? fallbackId,
    quoteId: json['cotizacionGuidId']?.toString() ?? quoteId,
    status: status,
    createdAt: _dateFrom(
      json['fechaCreacion'] ?? json['creadoEn'] ?? json['fecha'],
    ),
    isCancelled: cancelled,
    canCancel: explicitCanCancel is bool
        ? explicitCanCancel && !cancelled
        : !cancelled &&
              !completed &&
              (_orderIdFromResponse(response) ?? fallbackId) != null,
    responseContractPending:
        data is! Map ||
        _orderIdFromResponse(response) == null ||
        status == null,
  );
}

DateTime? _dateFrom(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;
