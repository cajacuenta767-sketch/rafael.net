import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class OrdersApi {
  const OrdersApi(this._client);

  final ApiClient _client;

  Future<dynamic> getById(String orderId) =>
      _client.get(ApiEndpoints.order(orderId));

  Future<dynamic> getByQuote(String quoteId) =>
      _client.get(ApiEndpoints.orderByQuote(quoteId));

  Future<dynamic> create(String quoteId) =>
      _client.post(ApiEndpoints.orders, data: {'cotizacionGuidId': quoteId});

  Future<dynamic> cancel(String orderId) =>
      _client.post(ApiEndpoints.cancelOrder(orderId));
}
