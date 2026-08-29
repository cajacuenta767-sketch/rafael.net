import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/client_login_page.dart';
import '../../features/home/presentation/role_home_page.dart';
import '../../features/home/presentation/start_page.dart';
import '../../features/requests/presentation/new_request_page.dart';
import '../../features/requests/domain/request_draft.dart';
import '../../features/requests/presentation/request_photos_page.dart';
import '../../features/requests/presentation/request_city_page.dart';
import '../../features/requests/presentation/request_review_page.dart';
import '../../features/requests/presentation/my_requests_page.dart';

abstract final class AppRoutes {
  static const start = '/';
  static const clientLogin = '/cliente/login';
  static const clientHome = '/cliente';
  static const clientNewRequest = '/cliente/solicitudes/nueva';
  static const clientRequestPhotos = '/cliente/solicitudes/fotografias';
  static const clientRequestCity = '/cliente/solicitudes/ciudad';
  static const clientRequestReview = '/cliente/solicitudes/revision';
  static const clientRequests = '/cliente/solicitudes';
  static const yonkeHome = '/yonke';
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
      path: AppRoutes.clientNewRequest,
      builder: (context, state) => const NewRequestPage(),
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
      path: AppRoutes.yonkeHome,
      builder: (context, state) => const RoleHomePage.yonke(),
    ),
  ],
);
