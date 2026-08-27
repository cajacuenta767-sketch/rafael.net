import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/client_login_page.dart';
import '../../features/home/presentation/role_home_page.dart';
import '../../features/home/presentation/start_page.dart';

abstract final class AppRoutes {
  static const start = '/';
  static const clientLogin = '/cliente/login';
  static const clientHome = '/cliente';
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
      path: AppRoutes.yonkeHome,
      builder: (context, state) => const RoleHomePage.yonke(),
    ),
  ],
);
