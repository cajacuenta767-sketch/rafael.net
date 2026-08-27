import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class DashboardApi {
  const DashboardApi(this._client);

  final ApiClient _client;

  Future<dynamic> getSummary() => _client.get(ApiEndpoints.dashboardSummary);

  Future<dynamic> getMyRequests({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) => _client.get(
    ApiEndpoints.dashboardRequests,
    queryParameters: {
      'Page': page,
      'CantidadRegistrosPorPagina': pageSize,
      'Search': search,
    },
  );

  Future<dynamic> getMyQuotes() => _client.get(ApiEndpoints.dashboardQuotes);

  Future<dynamic> getRecentRequest() =>
      _client.get(ApiEndpoints.dashboardRecentRequest);
}
