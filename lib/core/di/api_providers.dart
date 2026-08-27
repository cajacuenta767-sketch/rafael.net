import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_api.dart';
import '../../features/auth/domain/client_auth_repository.dart';
import '../../features/catalogs/data/catalogs_api.dart';
import '../../features/dashboard/data/dashboard_api.dart';
import '../../features/orders/data/orders_api.dart';
import '../../features/payments/data/payments_api.dart';
import '../../features/quotes/data/quotes_api.dart';
import '../../features/requests/data/requests_api.dart';
import '../../features/yonkes/data/yonkes_api.dart';
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
