import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class CatalogsApi {
  const CatalogsApi(this._client);

  final ApiClient _client;

  Future<dynamic> getStates() => _client.get(ApiEndpoints.states);
  Future<dynamic> getState(int id) => _client.get(ApiEndpoints.state(id));
  Future<dynamic> getCitiesByState(int stateId) =>
      _client.get(ApiEndpoints.citiesByState(stateId));
  Future<dynamic> getCity(int id) => _client.get(ApiEndpoints.city(id));
  Future<dynamic> getBrands() => _client.get(ApiEndpoints.brands);
  Future<dynamic> getBrand(int id) => _client.get(ApiEndpoints.brand(id));
  Future<dynamic> getModels({int? brandId}) =>
      _client.get(ApiEndpoints.models, queryParameters: {'marcaId': brandId});
  Future<dynamic> getModel(int id) => _client.get(ApiEndpoints.model(id));

  // Estas operaciones parecen administrativas en el Swagger actual.
  Future<dynamic> createBrand(Map<String, dynamic> payload) =>
      _client.post(ApiEndpoints.brandCreate, data: payload);
  Future<dynamic> updateBrand(int id, Map<String, dynamic> payload) =>
      _client.put(ApiEndpoints.brand(id), data: payload);
  Future<dynamic> createModel(Map<String, dynamic> payload) =>
      _client.post(ApiEndpoints.modelCreate, data: payload);
  Future<dynamic> updateModel(int id, Map<String, dynamic> payload) =>
      _client.put(ApiEndpoints.model(id), data: payload);
}
