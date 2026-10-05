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
    dynamic response;
    try {
      response = await _ordersApi.create(quoteId);
    } catch (error, stack) {
      // Un timeout/500 puede ocurrir después de persistir. Recuperar por
      // cotización, sin repetir el POST ni fabricar un identificador.
      if (error is ApiException &&
          error.statusCode != null &&
          error.statusCode != 408 &&
          error.statusCode! < 500) {
        rethrow;
      }
      try {
        final recovered = await getForQuote(quoteId);
        if (recovered?.id != null) {
          return ClientOrderCreationResult(
            orderId: recovered!.id,
            responseContractPending: recovered.responseContractPending,
          );
        }
      } catch (_) {
        // La respuesta de creación sigue siendo desconocida.
      }
      Error.throwWithStackTrace(error, stack);
    }
    var orderId = _orderIdFromResponse(response);
    if (orderId == null) {
      try {
        orderId = (await getForQuote(quoteId))?.id;
      } catch (_) {
        // Algunas versiones del backend confirman la creación sin devolver
        // todavía el detalle de la orden.
      }
    }
    return ClientOrderCreationResult(
      orderId: orderId,
      responseContractPending: orderId == null,
    );
  }

  @override
  Future<ClientOrder?> getForQuote(String quoteId) async {
    try {
      final response = await _ordersApi.getByQuote(quoteId);
      if (!_hasOrderPayload(response)) return null;
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
    if (updated.isCancelled) return updated;
    // Un 200 sin estado no demuestra la transición: volver a consultar.
    final confirmed = await getById(orderId, quoteId: order.quoteId);
    if (!confirmed.isCancelled) {
      throw const ApiException(
        message: 'La cancelación fue enviada, pero el servidor aún no confirma el estado. Actualiza la orden antes de volver a cancelar.',
      );
    }
    return confirmed;
  }
}

bool _hasOrderPayload(dynamic response) {
  if (response == null) return false;
  final data = response is Map && response.containsKey('data')
      ? response['data']
      : response;
  if (data == null) return false;
  if (data is List) return data.isNotEmpty;
  if (data is Map) return data.isNotEmpty && _orderIdFromResponse(data) != null;
  return data is String && data.trim().isNotEmpty;
}

String? _orderIdFromResponse(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data is String && data.trim().isNotEmpty) return data.trim();
  if (data is! Map) return null;
  final orderMap = data['orden'] ?? data['Orden'];
  final target = orderMap is Map ? orderMap : data;
  for (final key in const [
    'guidId',
    'ordenGuidId',
    'orderId',
    'id',
    'GuidId',
    'OrdenGuidId',
    'OrderId',
    'Id',
  ]) {
    final value = target[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

ClientOrder _orderFromResponse(
  dynamic response, {
  required String quoteId,
  String? fallbackId,
}) {
  final rawData = response is Map ? response['data'] ?? response : response;
  final data = rawData is Map
      ? (rawData['orden'] ?? rawData['Orden'] ?? rawData)
      : rawData;
  final json = data is Map ? data : const <dynamic, dynamic>{};
  final statusValue =
      json['estatus'] ??
      json['estado'] ??
      json['status'] ??
      json['ordenEstatus'] ??
      json['estatusOrdenId'] ??
      json['EstatusOrdenId'];
  final status = statusValue is Map
      ? (statusValue['descripcion'] ??
                statusValue['nombre'] ??
                statusValue['Descripcion'] ??
                statusValue['Nombre'])
            ?.toString()
      : statusValue is num
      ? _orderStatusFromId(statusValue.toInt())
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
  final pendingPayment = normalizedStatus == 'pendiente de pago';
  final paid =
      normalizedStatus.contains('pagada') ||
      normalizedStatus.contains('pagado');

  return ClientOrder(
    id: _orderIdFromResponse(response) ?? fallbackId,
    quoteId:
        json['cotizacionGuidId']?.toString() ??
        json['CotizacionGuidId']?.toString() ??
        quoteId,
    status: status,
    createdAt: _dateFrom(
      json['fechaCreacion'] ??
          json['FechaCreacion'] ??
          json['creadoEn'] ??
          json['fecha'],
    ),
    isCancelled: cancelled,
    canCancel: explicitCanCancel is bool
        ? explicitCanCancel && !cancelled && !completed && !paid
        : !cancelled &&
              !completed &&
              pendingPayment &&
              (_orderIdFromResponse(response) ?? fallbackId) != null,
    responseContractPending:
        data is! Map ||
        _orderIdFromResponse(response) == null ||
        status == null ||
        normalizedStatus.startsWith('estado no reconocido'),
  );
}

DateTime? _dateFrom(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

String _orderStatusFromId(int id) => switch (id) {
  1 => 'Pendiente de pago',
  2 => 'Procesando',
  3 => 'Pagada',
  4 => 'En camino',
  7 => 'Completada',
  9 => 'Cancelada',
  _ => 'Estado no reconocido ($id)',
};
