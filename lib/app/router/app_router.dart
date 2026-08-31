import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/client_login_page.dart';
import '../../features/auth/presentation/yonke_login_page.dart';
import '../../features/home/presentation/role_home_page.dart';
import '../../features/home/presentation/start_page.dart';
import '../../features/requests/presentation/new_request_page.dart';
import '../../features/requests/domain/request_draft.dart';
import '../../features/requests/presentation/request_photos_page.dart';
import '../../features/requests/presentation/request_city_page.dart';
import '../../features/requests/presentation/request_review_page.dart';
import '../../features/requests/presentation/my_requests_page.dart';
import '../../features/requests/presentation/request_detail_page.dart';
import '../../features/quotes/domain/client_quote.dart';
import '../../features/quotes/presentation/quote_detail_page.dart';
import '../../features/quotes/presentation/request_quotes_page.dart';
import '../../features/search/presentation/parts_search_page.dart';
import '../../features/yonke_requests/domain/yonke_request_summary.dart';
import '../../features/yonke_requests/presentation/yonke_quote_page.dart';
import '../../features/yonke_requests/presentation/yonke_request_detail_page.dart';
import '../../features/yonke_requests/presentation/yonke_requests_page.dart';
import '../../features/yonke_quotes/domain/yonke_quote.dart';
import '../../features/yonke_quotes/presentation/yonke_quote_detail_page.dart';
import '../../features/yonke_quotes/presentation/yonke_quotes_page.dart';

abstract final class AppRoutes {
  static const start = '/';
  static const clientLogin = '/cliente/login';
  static const clientHome = '/cliente';
  static const clientSearch = '/cliente/buscar';
  static const clientNewRequest = '/cliente/solicitudes/nueva';
  static const clientRequestPhotos = '/cliente/solicitudes/fotografias';
  static const clientRequestCity = '/cliente/solicitudes/ciudad';
  static const clientRequestReview = '/cliente/solicitudes/revision';
  static const clientRequests = '/cliente/solicitudes';
  static String clientRequestDetail(String requestId) =>
      '/cliente/solicitudes/detalle/${Uri.encodeComponent(requestId)}';
  static String clientRequestQuotes(String requestId) =>
      '${clientRequestDetail(requestId)}/cotizaciones';
  static String clientQuoteDetail(String quoteId) =>
      '/cliente/cotizaciones/${Uri.encodeComponent(quoteId)}';
  static const yonkeHome = '/yonke';
  static const yonkeLogin = '/yonke/login';
  static const yonkeQuotes = '/yonke/cotizaciones';
  static String yonkeQuoteDetail(String quoteId) =>
      '/yonke/cotizaciones/${Uri.encodeComponent(quoteId)}';
  static String yonkeRequestDetail(String requestYonkeId) =>
      '/yonke/solicitudes/${Uri.encodeComponent(requestYonkeId)}';
  static String yonkeNewQuote(String requestYonkeId) =>
      '${yonkeRequestDetail(requestYonkeId)}/cotizar';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.start,
  routes: [
    GoRoute(
      path: AppRoutes.start,
      builder: (context, state) => const StartPage(),
    ),
    GoRoute(
      path: AppRoutes.clientLogin,
      builder: (context, state) => const ClientLoginPage(),
    ),
    GoRoute(
      path: AppRoutes.clientHome,
      builder: (context, state) => const RoleHomePage.client(),
    ),
    GoRoute(
      path: AppRoutes.clientSearch,
      builder: (context, state) =>
          PartsSearchPage(initialQuery: state.uri.queryParameters['q']),
    ),
    GoRoute(
      path: AppRoutes.clientNewRequest,
      builder: (context, state) => NewRequestPage(
        draft: state.extra is RequestDraft
            ? state.extra! as RequestDraft
            : null,
      ),
    ),
    GoRoute(
      path: AppRoutes.clientRequestPhotos,
      builder: (context, state) =>
          RequestPhotosPage(draft: state.extra! as RequestDraft),
    ),
    GoRoute(
      path: AppRoutes.clientRequestCity,
      builder: (context, state) =>
          RequestCityPage(draft: state.extra! as RequestDraft),
    ),
    GoRoute(
      path: AppRoutes.clientRequestReview,
      builder: (context, state) =>
          RequestReviewPage(draft: state.extra! as RequestDraft),
    ),
    GoRoute(
      path: AppRoutes.clientRequests,
      builder: (context, state) => const MyRequestsPage(),
    ),
    GoRoute(
      path: '/cliente/solicitudes/detalle/:requestId',
      builder: (context, state) =>
          RequestDetailPage(requestId: state.pathParameters['requestId']!),
    ),
    GoRoute(
      path: '/cliente/solicitudes/detalle/:requestId/cotizaciones',
      builder: (context, state) => RequestQuotesPage(
        requestId: state.pathParameters['requestId']!,
        requestTitle: state.extra as String?,
      ),
    ),
    GoRoute(
      path: '/cliente/cotizaciones/:quoteId',
      builder: (context, state) => QuoteDetailPage(
        quoteId: state.pathParameters['quoteId']!,
        initialQuote: state.extra is ClientQuote
            ? state.extra! as ClientQuote
            : null,
      ),
    ),
    GoRoute(
      path: AppRoutes.yonkeLogin,
      builder: (context, state) => const YonkeLoginPage(),
    ),
    GoRoute(
      path: AppRoutes.yonkeHome,
      builder: (context, state) =>
          YonkeRequestsPage(isDemoSession: state.extra == true),
    ),
    GoRoute(
      path: AppRoutes.yonkeQuotes,
      builder: (context, state) =>
          YonkeQuotesPage(isDemoSession: state.extra == true),
    ),
    GoRoute(
      path: '/yonke/cotizaciones/:quoteId',
      builder: (context, state) {
        final quote = state.extra is YonkeQuote
            ? state.extra! as YonkeQuote
            : null;
        return YonkeQuoteDetailPage(
          quoteId: state.pathParameters['quoteId']!,
          initialQuote: quote,
          isDemoSession: quote?.isDemo == true,
        );
      },
    ),
    GoRoute(
      path: '/yonke/solicitudes/:requestYonkeId',
      builder: (context, state) => YonkeRequestDetailPage(
        requestYonkeId: state.pathParameters['requestYonkeId']!,
        request: state.extra is YonkeRequestSummary
            ? state.extra! as YonkeRequestSummary
            : null,
      ),
    ),
    GoRoute(
      path: '/yonke/solicitudes/:requestYonkeId/cotizar',
      redirect: (context, state) => state.extra is YonkeQuotePageArgs
          ? null
          : AppRoutes.yonkeRequestDetail(
              state.pathParameters['requestYonkeId']!,
            ),
      builder: (context, state) {
        final args = state.extra as YonkeQuotePageArgs;
        return YonkeQuotePage(
          requestYonkeId: state.pathParameters['requestYonkeId']!,
          detail: args.detail,
        );
      },
    ),
  ],
);
