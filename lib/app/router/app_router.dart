import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/client_login_page.dart';
import '../../features/auth/presentation/client_session_gate.dart';
import '../../features/auth/presentation/yonke_login_page.dart';
import '../../features/auth/presentation/yonke_session_gate.dart';
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
import '../../features/profile/presentation/client_profile_page.dart';
import '../../features/messages/presentation/client_conversation_page.dart';
import '../../features/orders/presentation/client_order_pages.dart';
import '../../features/ratings/presentation/client_rating_page.dart';
import '../../features/yonke_requests/domain/yonke_request_summary.dart';
import '../../features/yonke_requests/presentation/yonke_quote_page.dart';
import '../../features/yonke_requests/presentation/yonke_request_detail_page.dart';
import '../../features/yonke_requests/presentation/yonke_requests_page.dart';
import '../../features/yonke_quotes/domain/yonke_quote.dart';
import '../../features/yonke_quotes/presentation/yonke_quote_detail_page.dart';
import '../../features/yonke_quotes/presentation/yonke_quotes_page.dart';
import '../../features/yonke_profile/presentation/yonke_profile_page.dart';
import '../../features/yonke_messages/presentation/yonke_messages_page.dart';
import '../../features/yonke_coverage/presentation/yonke_coverage_page.dart';
import '../../features/yonke_notifications/presentation/yonke_notifications_page.dart';

abstract final class AppRoutes {
  static const start = '/';
  static const clientLogin = '/cliente/login';
  static const clientHome = '/cliente';
  static const clientSearch = '/cliente/buscar';
  static const clientProfile = '/cliente/perfil';
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
  static String clientQuoteConversation(String quoteId) =>
      '${clientQuoteDetail(quoteId)}/mensajes';
  static String clientOrderConfirmation(String quoteId) =>
      '${clientQuoteDetail(quoteId)}/orden';
  static String clientOrderTracking(String quoteId) =>
      '${clientQuoteDetail(quoteId)}/orden/seguimiento';
  static const clientOrderSuccess = '/cliente/ordenes/exito';
  static String clientRating(String quoteId) =>
      '/cliente/cotizaciones/${Uri.encodeComponent(quoteId)}/calificacion';
  static const yonkeHome = '/yonke';
  static const yonkeLogin = '/yonke/login';
  static const yonkeQuotes = '/yonke/cotizaciones';
  static const yonkeProfile = '/yonke/perfil';
  static const yonkeMessages = '/yonke/mensajes';
  static const yonkeCoverage = '/yonke/cobertura';
  static const yonkeNotifications = '/yonke/notificaciones';
  static String yonkeConversation(String quoteId) =>
      '$yonkeMessages/${Uri.encodeComponent(quoteId)}';
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
      builder: (context, state) =>
          ClientSessionGate(builder: (_) => const RoleHomePage.client()),
    ),
    GoRoute(
      path: AppRoutes.clientSearch,
      builder: (context, state) => ClientSessionGate(
        builder: (_) =>
            PartsSearchPage(initialQuery: state.uri.queryParameters['q']),
      ),
    ),
    GoRoute(
      path: AppRoutes.clientProfile,
      builder: (context, state) =>
          ClientSessionGate(builder: (_) => const ClientProfilePage()),
    ),
    GoRoute(
      path: AppRoutes.clientNewRequest,
      builder: (context, state) => ClientSessionGate(
        builder: (_) => NewRequestPage(
          draft: state.extra is RequestDraft
              ? state.extra! as RequestDraft
              : null,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.clientRequestPhotos,
      builder: (context, state) => ClientSessionGate(
        builder: (_) => RequestPhotosPage(draft: state.extra! as RequestDraft),
      ),
    ),
    GoRoute(
      path: AppRoutes.clientRequestCity,
      builder: (context, state) => ClientSessionGate(
        builder: (_) => RequestCityPage(draft: state.extra! as RequestDraft),
      ),
    ),
    GoRoute(
      path: AppRoutes.clientRequestReview,
      builder: (context, state) => ClientSessionGate(
        builder: (_) => RequestReviewPage(draft: state.extra! as RequestDraft),
      ),
    ),
    GoRoute(
      path: AppRoutes.clientRequests,
      builder: (context, state) =>
          ClientSessionGate(builder: (_) => const MyRequestsPage()),
    ),
    GoRoute(
      path: '/cliente/solicitudes/detalle/:requestId',
      builder: (context, state) => ClientSessionGate(
        builder: (_) =>
            RequestDetailPage(requestId: state.pathParameters['requestId']!),
      ),
    ),
    GoRoute(
      path: '/cliente/solicitudes/detalle/:requestId/cotizaciones',
      builder: (context, state) => ClientSessionGate(
        builder: (_) => RequestQuotesPage(
          requestId: state.pathParameters['requestId']!,
          requestTitle: state.extra as String?,
        ),
      ),
    ),
    GoRoute(
      path: '/cliente/cotizaciones/:quoteId',
      builder: (context, state) => ClientSessionGate(
        builder: (_) => QuoteDetailPage(
          quoteId: state.pathParameters['quoteId']!,
          initialQuote: state.extra is ClientQuote
              ? state.extra! as ClientQuote
              : null,
        ),
      ),
    ),
    GoRoute(
      path: '/cliente/cotizaciones/:quoteId/mensajes',
      redirect: (context, state) => state.extra is ClientConversationArgs
          ? null
          : AppRoutes.clientQuoteDetail(state.pathParameters['quoteId']!),
      builder: (context, state) {
        final args = state.extra as ClientConversationArgs;
        return ClientSessionGate(
          builder: (_) => ClientConversationPage(args: args),
        );
      },
    ),
    GoRoute(
      path: '/cliente/cotizaciones/:quoteId/orden',
      redirect: (context, state) => state.extra is ClientOrderConfirmationArgs
          ? null
          : AppRoutes.clientQuoteDetail(state.pathParameters['quoteId']!),
      builder: (context, state) {
        final args = state.extra as ClientOrderConfirmationArgs;
        return ClientSessionGate(
          builder: (_) => ClientOrderConfirmationPage(args: args),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.clientOrderSuccess,
      redirect: (context, state) => state.extra is ClientOrderSuccessArgs
          ? null
          : AppRoutes.clientRequests,
      builder: (context, state) => ClientSessionGate(
        builder: (_) => ClientOrderSuccessPage(
          args: state.extra! as ClientOrderSuccessArgs,
        ),
      ),
    ),
    GoRoute(
      path: '/cliente/cotizaciones/:quoteId/orden/seguimiento',
      redirect: (context, state) => state.extra is ClientOrderTrackingArgs
          ? null
          : AppRoutes.clientQuoteDetail(state.pathParameters['quoteId']!),
      builder: (context, state) => ClientSessionGate(
        builder: (_) => ClientOrderTrackingPage(
          args: state.extra! as ClientOrderTrackingArgs,
        ),
      ),
    ),
    GoRoute(
      path: '/cliente/cotizaciones/:quoteId/calificacion',
      redirect: (context, state) => state.extra is ClientRatingArgs
          ? null
          : AppRoutes.clientQuoteDetail(state.pathParameters['quoteId']!),
      builder: (context, state) => ClientSessionGate(
        builder: (_) =>
            ClientRatingPage(args: state.extra! as ClientRatingArgs),
      ),
    ),
    GoRoute(
      path: AppRoutes.yonkeLogin,
      builder: (context, state) => const YonkeLoginPage(),
    ),
    GoRoute(
      path: AppRoutes.yonkeHome,
      builder: (context, state) => YonkeSessionGate(
        isDemoSession: state.extra == true,
        builder: (_) => YonkeRequestsPage(isDemoSession: state.extra == true),
      ),
    ),
    GoRoute(
      path: AppRoutes.yonkeQuotes,
      builder: (context, state) => YonkeSessionGate(
        isDemoSession: state.extra == true,
        builder: (_) => YonkeQuotesPage(isDemoSession: state.extra == true),
      ),
    ),
    GoRoute(
      path: AppRoutes.yonkeProfile,
      builder: (context, state) => YonkeSessionGate(
        isDemoSession: state.extra == true,
        builder: (_) => YonkeProfilePage(isDemoSession: state.extra == true),
      ),
    ),
    GoRoute(
      path: AppRoutes.yonkeCoverage,
      builder: (context, state) => YonkeSessionGate(
        isDemoSession: state.extra == true,
        builder: (_) => YonkeCoveragePage(isDemoSession: state.extra == true),
      ),
    ),
    GoRoute(
      path: AppRoutes.yonkeNotifications,
      builder: (context, state) => YonkeSessionGate(
        isDemoSession: state.extra == true,
        builder: (_) =>
            YonkeNotificationsPage(isDemoSession: state.extra == true),
      ),
    ),
    GoRoute(
      path: AppRoutes.yonkeMessages,
      builder: (context, state) => YonkeSessionGate(
        isDemoSession: state.extra == true,
        builder: (_) => YonkeMessagesPage(isDemoSession: state.extra == true),
      ),
    ),
    GoRoute(
      path: '/yonke/mensajes/:quoteId',
      redirect: (context, state) =>
          state.extra is YonkeConversationArgs ? null : AppRoutes.yonkeMessages,
      builder: (context, state) {
        final args = state.extra as YonkeConversationArgs;
        return YonkeSessionGate(
          isDemoSession: args.isDemoSession,
          builder: (_) => YonkeConversationPage(args: args),
        );
      },
    ),
    GoRoute(
      path: '/yonke/cotizaciones/:quoteId',
      builder: (context, state) {
        final quote = state.extra is YonkeQuote
            ? state.extra! as YonkeQuote
            : null;
        return YonkeSessionGate(
          isDemoSession: quote?.isDemo == true,
          builder: (_) => YonkeQuoteDetailPage(
            quoteId: state.pathParameters['quoteId']!,
            initialQuote: quote,
            isDemoSession: quote?.isDemo == true,
          ),
        );
      },
    ),
    GoRoute(
      path: '/yonke/solicitudes/:requestYonkeId',
      builder: (context, state) {
        final request = state.extra is YonkeRequestSummary
            ? state.extra! as YonkeRequestSummary
            : null;
        return YonkeSessionGate(
          isDemoSession: request?.isDemo == true,
          builder: (_) => YonkeRequestDetailPage(
            requestYonkeId: state.pathParameters['requestYonkeId']!,
            request: request,
          ),
        );
      },
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
        return YonkeSessionGate(
          isDemoSession: args.detail.isDemo,
          builder: (_) => YonkeQuotePage(
            requestYonkeId: state.pathParameters['requestYonkeId']!,
            detail: args.detail,
          ),
        );
      },
    ),
  ],
);
