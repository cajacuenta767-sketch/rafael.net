import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_api.dart';
import '../../features/auth/domain/client_auth_repository.dart';
import '../../features/auth/domain/yonke_auth_repository.dart';
import '../../features/catalogs/data/catalogs_api.dart';
import '../../features/dashboard/data/dashboard_api.dart';
import '../../features/orders/data/orders_api.dart';
import '../../features/payments/data/payments_api.dart';
import '../../features/quotes/data/quotes_api.dart';
import '../../features/requests/data/requests_api.dart';
import '../../features/search/data/parts_search_repository.dart';
import '../../features/search/data/search_history_repository.dart';
import '../../features/yonkes/data/yonkes_api.dart';
import '../../features/yonke_quotes/data/yonke_quotes_repository.dart';
import '../../features/yonke_requests/data/yonke_request_detail_repository.dart';
import '../../features/yonke_requests/data/yonke_requests_repository.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/dio_api_client.dart';
import '../storage/secure_token_store.dart';
import '../storage/token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => DioApiClient(ref.watch(tokenStoreProvider)),
);

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);
final clientAuthRepositoryProvider = Provider<ClientAuthRepository>(
  (ref) => ApiClientAuthRepository(ref.watch(authApiProvider)),
);
final yonkeAuthRepositoryProvider = Provider<YonkeAuthRepository>(
  (ref) => ApiYonkeAuthRepository(ref.watch(authApiProvider)),
);
final catalogsApiProvider = Provider<CatalogsApi>(
  (ref) => CatalogsApi(ref.watch(apiClientProvider)),
);
final dashboardApiProvider = Provider<DashboardApi>(
  (ref) => DashboardApi(ref.watch(apiClientProvider)),
);
final requestsApiProvider = Provider<RequestsApi>(
  (ref) => RequestsApi(ref.watch(apiClientProvider)),
);
final quotesApiProvider = Provider<QuotesApi>(
  (ref) => QuotesApi(ref.watch(apiClientProvider)),
);
final ordersApiProvider = Provider<OrdersApi>(
  (ref) => OrdersApi(ref.watch(apiClientProvider)),
);
final paymentsApiProvider = Provider<PaymentsApi>(
  (ref) => PaymentsApi(ref.watch(apiClientProvider)),
);
final yonkesApiProvider = Provider<YonkesApi>(
  (ref) => YonkesApi(ref.watch(apiClientProvider)),
);
final yonkeRequestsRepositoryProvider = Provider<YonkeRequestsRepository>(
  (ref) => const UnavailableYonkeRequestsRepository(),
);
final yonkeRequestDetailRepositoryProvider =
    Provider<YonkeRequestDetailRepository>(
      (ref) => ApiYonkeRequestDetailRepository(
        ref.watch(requestsApiProvider),
        ref.watch(quotesApiProvider),
      ),
    );
final yonkeQuotesRepositoryProvider = Provider<YonkeQuotesRepository>(
  (ref) => ApiYonkeQuotesRepository(
    ref.watch(dashboardApiProvider),
    ref.watch(quotesApiProvider),
  ),
);
final partsSearchRepositoryProvider = Provider<PartsSearchRepository>(
  (ref) => AppConfig.enableMockAuth
      ? const DemoPartsSearchRepository()
      : const UnavailablePartsSearchRepository(),
);
final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
  (ref) => SecureSearchHistoryRepository(),
);
