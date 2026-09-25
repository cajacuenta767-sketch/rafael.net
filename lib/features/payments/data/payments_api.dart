import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class PaymentsApi {
  const PaymentsApi(this._client);

  final ApiClient _client;

  Future<dynamic> createCheckout(String orderId) =>
      _client.post(ApiEndpoints.paymentCheckout(orderId));

  Future<dynamic> getResult(String sessionId) =>
      _client.get(ApiEndpoints.paymentResult(sessionId));

  // El webhook de Stripe no debe invocarse desde la aplicación móvil.
}

/// URL de Stripe Checkout en la respuesta de `POST /api/Pagos/checkout`.
///
/// Swagger no documenta el cuerpo: se acepta la URL como `data` o en las
/// claves habituales. Devuelve `null` si no hay una URL https.
Uri? checkoutUrlFromResponse(dynamic response) {
  dynamic data = response;
  if (data is Map && data.containsKey('data')) data = data['data'];
  String? raw;
  if (data is String) {
    raw = data;
  } else if (data is Map) {
    for (final key in const ['url', 'checkoutUrl', 'sessionUrl', 'urlPago']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        raw = value;
        break;
      }
    }
  }
  final uri = Uri.tryParse(raw?.trim() ?? '');
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}
