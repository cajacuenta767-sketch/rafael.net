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
