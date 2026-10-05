import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class PaymentsApi {
  const PaymentsApi(this._client);

  final ApiClient _client;

  Future<dynamic> createCheckout(String orderId) =>
      _client.post(ApiEndpoints.paymentCheckout(orderId));

  Future<dynamic> getResult(String sessionId) =>
      _client.get(ApiEndpoints.paymentResult(sessionId));

  static StripeCheckoutSession? parseCheckout(Object? response) {
    dynamic data = response;
    for (var i = 0; i < 3 && data is Map; i++) {
      if (data['sessionId'] != null || data['SessionId'] != null) break;
      data = data['data'] ?? data['Data'] ?? data;
    }
    if (data is! Map) return null;
    final sessionId = (data['sessionId'] ?? data['SessionId'])?.toString();
    final checkoutUrl =
        (data['checkoutUrl'] ??
                data['CheckoutUrl'] ??
                data['url'] ??
                data['Url'])
            ?.toString();
    final uri = checkoutUrl == null ? null : Uri.tryParse(checkoutUrl);
    if (sessionId == null ||
        sessionId.isEmpty ||
        uri?.scheme != 'https' ||
        uri?.host != 'checkout.stripe.com') {
      return null;
    }
    return StripeCheckoutSession(sessionId: sessionId, checkoutUrl: uri!);
  }

  static Map<String, dynamic>? parseResult(Object? response) {
    dynamic data = response;
    for (var i = 0; i < 3 && data is Map; i++) {
      if (data['estado'] != null ||
          data['Estado'] != null ||
          data['paymentStatus'] != null ||
          data['PaymentStatus'] != null) {
        break;
      }
      data = data['data'] ?? data['Data'] ?? data;
    }
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  // El webhook de Stripe no debe invocarse desde la aplicación móvil.
}

class StripeCheckoutSession {
  const StripeCheckoutSession({
    required this.sessionId,
    required this.checkoutUrl,
  });
  final String sessionId;
  final Uri checkoutUrl;
}
