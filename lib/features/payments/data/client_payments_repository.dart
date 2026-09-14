import '../../../core/network/api_exception.dart';
import '../domain/payment_checkout.dart';
import 'payments_api.dart';

/// Pago de una orden con Stripe Checkout.
///
/// Swagger no publica el cuerpo de las respuestas de `Pagos`, así que los
/// parsers aceptan los nombres de campo más probables y fallan con un mensaje
/// claro cuando falta lo imprescindible (la URL de pago).
abstract interface class ClientPaymentsRepository {
  Future<PaymentCheckout> createCheckout(String orderId);
  Future<PaymentResult> getResult(String sessionId);
}

class ApiClientPaymentsRepository implements ClientPaymentsRepository {
  const ApiClientPaymentsRepository(this._api);

  final PaymentsApi _api;

  @override
  Future<PaymentCheckout> createCheckout(String orderId) async {
    final response = await _api.createCheckout(orderId);
    final checkout = paymentCheckoutFromResponse(response);
    if (checkout == null) {
      throw ApiException(
        message:
            'El servidor no devolvió la URL de pago de Stripe. '
            'Claves recibidas: ${_describe(response)}.',
      );
    }
    return checkout;
  }

  @override
  Future<PaymentResult> getResult(String sessionId) async {
    final response = await _api.getResult(sessionId);
    return paymentResultFromResponse(response);
  }
}

const _urlKeys = [
  'url',
  'checkouturl',
  'sessionurl',
  'paymenturl',
  'urlpago',
  'urlcheckout',
  'link',
  'redirecturl',
];
const _sessionKeys = [
  'sessionid',
  'session_id',
  'stripesessionid',
  'checkoutsessionid',
  'idsesion',
  'id',
];
const _statusKeys = [
  'paymentstatus',
  'payment_status',
  'estatuspago',
  'status',
  'estatus',
  'estado',
];
const _paidValues = {
  'paid',
  'pagado',
  'pagada',
  'complete',
  'completed',
  'completado',
  'succeeded',
  'success',
  'exitoso',
  'approved',
  'aprobado',
};

/// Interpreta la respuesta del checkout. Devuelve `null` si no hay URL.
PaymentCheckout? paymentCheckoutFromResponse(dynamic response) {
  final data = _unwrap(response);
  Uri? url;
  String? sessionId;
  if (data is String) {
    url = _asHttpUri(data);
  } else if (data is Map) {
    final map = _lower(data);
    for (final key in _urlKeys) {
      url = _asHttpUri(map[key]);
      if (url != null) break;
    }
    for (final key in _sessionKeys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        sessionId = value.trim();
        break;
      }
    }
  }
  if (url == null) return null;
  sessionId ??= _sessionFromUrl(url);
  return PaymentCheckout(url: url, sessionId: sessionId);
}

PaymentResult paymentResultFromResponse(dynamic response) {
  final data = _unwrap(response);
  if (data is bool) {
    return PaymentResult(status: data ? 'paid' : 'unpaid', paid: data);
  }
  if (data is String) {
    final text = data.trim();
    return PaymentResult(
      status: text,
      paid: _paidValues.contains(text.toLowerCase()),
    );
  }
  if (data is! Map) {
    return const PaymentResult(status: '', paid: false);
  }
  final map = _lower(data);
  var status = '';
  for (final key in _statusKeys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      status = value.trim();
      break;
    }
  }
  final paidFlag = map['pagado'] ?? map['paid'] ?? map['exitoso'];
  final paid = paidFlag == true || _paidValues.contains(status.toLowerCase());
  final amountRaw = map['monto'] ?? map['amount'] ?? map['amounttotal'];
  final amount = amountRaw is num
      ? amountRaw.toDouble()
      : double.tryParse(amountRaw?.toString() ?? '');
  final message = map['message'] ?? map['mensaje'];
  return PaymentResult(
    status: status,
    paid: paid,
    message: message is String && message.trim().isNotEmpty ? message : null,
    amount: amount,
  );
}

dynamic _unwrap(dynamic response) {
  if (response is Map) {
    final low = _lower(response);
    for (final key in const ['data', 'result', 'resultado']) {
      if (low.containsKey(key) && low[key] != null) return low[key];
    }
  }
  return response;
}

Map<String, dynamic> _lower(Map<dynamic, dynamic> map) => {
  for (final entry in map.entries)
    entry.key.toString().toLowerCase(): entry.value,
};

Uri? _asHttpUri(dynamic value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) return null;
  return (uri.scheme == 'https' || uri.scheme == 'http') ? uri : null;
}

String? _sessionFromUrl(Uri url) {
  final fromQuery = url.queryParameters['session_id'];
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
  for (final segment in url.pathSegments.reversed) {
    if (segment.startsWith('cs_')) return segment;
  }
  return null;
}

String _describe(dynamic response) {
  final data = _unwrap(response);
  if (data is Map) return data.keys.map((k) => k.toString()).join(', ');
  if (data == null) return 'ninguna';
  return data.runtimeType.toString();
}
