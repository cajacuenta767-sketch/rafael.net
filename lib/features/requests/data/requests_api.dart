import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_file.dart';

class RequestsApi {
  const RequestsApi(this._client);

  final ApiClient _client;

  Future<dynamic> getPaged({
    int page = 1,
    int pageSize = 20,
    String? search,
    DateTime? from,
    DateTime? to,
    String? userId,
  }) => _client.get(
    ApiEndpoints.pagedRequests,
    queryParameters: {
      'Page': page,
      'CantidadRegistrosPorPagina': pageSize,
      'Search': search,
      'desde': from?.toIso8601String(),
      'hasta': to?.toIso8601String(),
      'userId': userId,
    },
  );

  Future<dynamic> getById(String requestId) =>
      _client.get(ApiEndpoints.request(requestId));

  Future<dynamic> create({
    required int brandId,
    required int modelId,
    required int year,
    required String part,
    List<int> cityIds = const [],
    String? engine,
    String? transmission,
    String? partNumber,
    String? description,
  }) => _client.post(
    ApiEndpoints.requests,
    data: {
      'marcaId': brandId,
      'modeloId': modelId,
      'año': year,
      'motor': engine,
      'transmicion': transmission,
      'piezaBuscada': part,
      'numeroParte': partNumber,
      'descripcion': description,
      'ciudadesIds': cityIds,
    },
  );

  Future<dynamic> cancel({
    required String requestId,
    required int statusId,
    String? userId,
    String? notes,
  }) => _client.delete(
    ApiEndpoints.request(requestId),
    data: {
      'guidId': requestId,
      'estatusId': statusId,
      'userId': userId,
      'notas': notes,
    },
  );

  Future<dynamic> addCity(String requestId, int cityId) =>
      _client.post(ApiEndpoints.requestCity(requestId, cityId));

  Future<dynamic> removeCity(String requestId, int cityId) =>
      _client.delete(ApiEndpoints.requestCity(requestId, cityId));

  Future<dynamic> addCities(String requestId, List<int> cityIds) =>
      _client.post(ApiEndpoints.requestCities(requestId), data: cityIds);

  Future<dynamic> getCities(String requestId) =>
      _client.get(ApiEndpoints.requestCities(requestId));

  Future<dynamic> replaceCities(String requestId, List<int> cityIds) =>
      _client.put(ApiEndpoints.requestCities(requestId), data: cityIds);

  Future<dynamic> removeAllCities(String requestId) =>
      _client.delete(ApiEndpoints.requestCities(requestId));

  Future<dynamic> cityExists(String requestId, int cityId) => _client.get(
    ApiEndpoints.requestCityExists,
    queryParameters: {'solicitudGuidId': requestId, 'ciudadId': cityId},
  );

  Future<dynamic> addImages(String requestId, List<ApiFile> images) =>
      _client.multipart(
        ApiEndpoints.addRequestImage(requestId),
        method: 'POST',
        files: images,
      );

  Future<dynamic> getImages(String requestId) =>
      _client.get(ApiEndpoints.requestImages(requestId));

  Future<dynamic> getImage(String imageId) =>
      _client.get(ApiEndpoints.requestImage(imageId));

  Future<dynamic> deleteImage(String imageId) =>
      _client.delete(ApiEndpoints.requestImage(imageId));

  Future<dynamic> sendToCoveredYonkes(String requestId) =>
      _client.post(ApiEndpoints.sendRequestToYonkes(requestId));

  Future<dynamic> markAsViewedByYonke(String requestYonkeId) =>
      _client.put(ApiEndpoints.markYonkeRequestViewed(requestYonkeId));
}
