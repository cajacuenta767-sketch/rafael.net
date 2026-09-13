import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_api.dart';
import '../../features/auth/domain/client_auth_repository.dart';
import '../../features/auth/domain/yonke_auth_repository.dart';
import '../../features/catalogs/data/catalogs_api.dart';
import '../../features/dashboard/data/dashboard_api.dart';
import '../../features/orders/data/orders_api.dart';
import '../../features/orders/data/client_orders_repository.dart';
import '../../features/payments/data/payments_api.dart';
import '../../features/quotes/data/quotes_api.dart';
import '../../features/requests/data/requests_api.dart';
import '../../features/requests/data/request_submission_repository.dart';
import '../../features/ratings/data/client_ratings_repository.dart';
import '../../features/ratings/data/yonke_reputation_repository.dart';
import '../../features/search/data/parts_search_repository.dart';
import '../../features/search/data/search_history_repository.dart';
import '../../features/yonkes/data/yonkes_api.dart';
import '../../features/yonkes/data/client_yonkes_repository.dart';
import '../../features/yonke_quotes/data/yonke_quotes_repository.dart';
import '../../features/yonke_messages/data/yonke_messages_repository.dart';
import '../../features/yonke_coverage/data/yonke_coverage_repository.dart';
import '../../features/yonke_notifications/data/yonke_notifications_repository.dart';
import '../../features/yonke_profile/data/yonke_profile_repository.dart';
import '../../features/messages/data/client_messages_repository.dart';
import '../../features/yonke_requests/data/yonke_request_detail_repository.dart';
import '../../features/yonke_requests/data/yonke_requests_repository.dart';
import '../network/api_client.dart';
import '../network/dio_api_client.dart';
import '../storage/secure_token_store.dart';
import '../storage/token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Cliente HTTP real contra la API publicada. No existe modo demo ni datos
/// locales: cada pantalla consulta el servidor con el token de la sesión.
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
final requestSubmissionRepositoryProvider =
    Provider<RequestSubmissionRepository>(
      (ref) => ApiRequestSubmissionRepository(ref.watch(requestsApiProvider)),
    );
final quotesApiProvider = Provider<QuotesApi>(
  (ref) => QuotesApi(ref.watch(apiClientProvider)),
);
final ordersApiProvider = Provider<OrdersApi>(
  (ref) => OrdersApi(ref.watch(apiClientProvider)),
);
final clientOrdersRepositoryProvider = Provider<ClientOrdersRepository>(
  (ref) => ApiClientOrdersRepository(ref.watch(ordersApiProvider)),
);
final paymentsApiProvider = Provider<PaymentsApi>(
  (ref) => PaymentsApi(ref.watch(apiClientProvider)),
);
final yonkesApiProvider = Provider<YonkesApi>(
  (ref) => YonkesApi(ref.watch(apiClientProvider)),
);
final clientYonkesRepositoryProvider = Provider<ClientYonkesRepository>(
  (ref) => ApiClientYonkesRepository(
    ref.watch(yonkesApiProvider),
    ref.watch(catalogsApiProvider),
  ),
);
final clientRatingsRepositoryProvider = Provider<ClientRatingsRepository>(
  (ref) => ApiClientRatingsRepository(ref.watch(yonkesApiProvider)),
);
final yonkeReputationRepositoryProvider = Provider<YonkeReputationRepository>(
  (ref) => ApiYonkeReputationRepository(ref.watch(yonkesApiProvider)),
);
final yonkeRequestsRepositoryProvider = Provider<YonkeRequestsRepository>(
  (ref) => ApiYonkeRequestsRepository(
    ref.watch(dashboardApiProvider),
    ref.watch(requestsApiProvider),
  ),
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
final yonkeMessagesRepositoryProvider = Provider<YonkeMessagesRepository>(
  (ref) => ApiYonkeMessagesRepository(
    ref.watch(quotesApiProvider),
    ref.watch(dashboardApiProvider),
    ref.watch(tokenStoreProvider),
  ),
);
final yonkeCoverageRepositoryProvider = Provider<YonkeCoverageRepository>(
  (ref) => ApiYonkeCoverageRepository(
    ref.watch(catalogsApiProvider),
    ref.watch(yonkesApiProvider),
  ),
);
final yonkeProfileRepositoryProvider = Provider<YonkeProfileRepository>(
  (ref) => ApiYonkeProfileRepository(
    ref.watch(yonkesApiProvider),
    ref.watch(tokenStoreProvider),
  ),
);
final yonkeNotificationsRepositoryProvider =
    Provider<YonkeNotificationsRepository>(
      (ref) => ApiYonkeNotificationsRepository(ref.watch(yonkesApiProvider)),
    );
final clientMessagesRepositoryProvider = Provider<ClientMessagesRepository>(
  (ref) => ApiClientMessagesRepository(
    ref.watch(quotesApiProvider),
    ref.watch(dashboardApiProvider),
    ref.watch(tokenStoreProvider),
  ),
);
final partsSearchRepositoryProvider = Provider<PartsSearchRepository>(
  (ref) => const UnavailablePartsSearchRepository(),
);
final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
  (ref) => SecureSearchHistoryRepository(),
);
