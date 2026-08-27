import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_file.dart';

class YonkesApi {
  const YonkesApi(this._client);

  final ApiClient _client;

  Future<dynamic> getPaged({
    int page = 1,
    int pageSize = 20,
    String? search,
    int? cityId,
  }) => _client.get(
    ApiEndpoints.pagedYonkes,
    queryParameters: {
      'Page': page,
      'CantidadRegistrosPorPagina': pageSize,
      'Search': search,
      'ciudadId': cityId,
    },
  );

  Future<dynamic> getById(String yonkeId) =>
      _client.get(ApiEndpoints.yonke(yonkeId));

  Future<dynamic> register({
    required Map<String, dynamic> fields,
    List<ApiFile> files = const [],
  }) => _client.multipart(
    ApiEndpoints.yonkes,
    method: 'POST',
    fields: fields,
    files: files,
  );

  Future<dynamic> updateInfo({
    required String yonkeId,
    required Map<String, dynamic> payload,
  }) => _client.put(ApiEndpoints.updateYonke(yonkeId), data: payload);

  Future<dynamic> updateLogo(ApiFile logo) => _client.multipart(
    ApiEndpoints.updateYonkeLogo,
    method: 'PUT',
    files: [logo],
  );

  Future<dynamic> deactivate(String yonkeId) =>
      _client.put(ApiEndpoints.deactivateYonke(yonkeId));

  Future<dynamic> registerRating({
    required String quoteId,
    required int rating,
    String? comment,
  }) => _client.post(
    ApiEndpoints.ratings,
    data: {
      'cotizacionGuidId': quoteId,
      'calificacion': rating,
      'comentario': comment,
    },
  );

  Future<dynamic> getRatings(String yonkeId) =>
      _client.get(ApiEndpoints.yonkeRatings(yonkeId));

  Future<dynamic> getCoverage(String yonkeId) =>
      _client.get(ApiEndpoints.yonkeCoverage(yonkeId));

  Future<dynamic> updateCoverage({
    required String yonkeId,
    required List<int> cityIds,
  }) => _client.put(
    ApiEndpoints.coverage,
    data: {'yonkeGuidId': yonkeId, 'ciudadesIds': cityIds},
  );

  Future<dynamic> registerDevice({
    required String yonkeId,
    required String firebaseToken,
    required String platform,
    required String model,
  }) => _client.post(
    ApiEndpoints.yonkeDevices,
    data: {
      'yonkeGuidId': yonkeId,
      'firebaseToken': firebaseToken,
      'plataforma': platform,
      'modelo': model,
    },
  );
}
