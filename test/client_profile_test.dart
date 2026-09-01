import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/auth/presentation/client_session_gate.dart';
import 'package:app_yonke/features/profile/data/client_profile_repository.dart';
import 'package:app_yonke/features/profile/domain/client_profile.dart';
import 'package:app_yonke/features/profile/presentation/client_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('profile identifies demo data and exposes existing modules', (
    tester,
  ) async {
    final store = _MemoryTokenStore(accessToken: 'test-token');
    final router = _profileRouter(store);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(store)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('Modo de prueba'), findsOneWidget);
    expect(find.text('Mis solicitudes'), findsOneWidget);
    expect(find.text('Cotizaciones recibidas'), findsOneWidget);
    expect(find.text('Términos y condiciones'), findsOneWidget);
    expect(find.text('Aviso de privacidad'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.textContaining('662'), findsNothing);
  });

  testWidgets('sign out clears secure session and removes profile history', (
    tester,
  ) async {
    final store = _MemoryTokenStore(accessToken: 'test-token');
    final router = _profileRouter(store);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(store)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('client-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('client-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-client-sign-out')));
    await tester.pumpAndSettle();

    expect(store.accessToken, isNull);
    expect(find.text('LOGIN CLIENTE'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('protected client content redirects when session is absent', (
    tester,
  ) async {
    final store = _MemoryTokenStore();
    final router = GoRouter(
      initialLocation: '/protegido',
      routes: [
        GoRoute(
          path: '/protegido',
          builder: (context, state) => ClientSessionGate(
            allowDemoSession: false,
            builder: (_) => const Text('CONTENIDO PROTEGIDO'),
          ),
        ),
        GoRoute(
          path: '/cliente/login',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('LOGIN CLIENTE'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(store)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LOGIN CLIENTE'), findsOneWidget);
    expect(find.text('CONTENIDO PROTEGIDO'), findsNothing);
  });
}

GoRouter _profileRouter(_MemoryTokenStore store) => GoRouter(
  initialLocation: '/cliente/perfil',
  routes: [
    GoRoute(
      path: '/cliente/perfil',
      builder: (context, state) => ClientProfilePage(
        tokenStore: store,
        repository: const _DemoProfileRepository(),
      ),
    ),
    GoRoute(
      path: '/cliente/login',
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('LOGIN CLIENTE'))),
    ),
    GoRoute(
      path: '/cliente',
      builder: (context, state) => const Scaffold(body: Text('INICIO')),
    ),
    GoRoute(
      path: '/cliente/buscar',
      builder: (context, state) => const Scaffold(body: Text('BUSCAR')),
    ),
    GoRoute(
      path: '/cliente/solicitudes',
      builder: (context, state) => const Scaffold(body: Text('SOLICITUDES')),
    ),
    GoRoute(
      path: '/cliente/solicitudes/nueva',
      builder: (context, state) => const Scaffold(body: Text('NUEVA')),
    ),
  ],
);

class _DemoProfileRepository implements ClientProfileRepository {
  const _DemoProfileRepository();

  @override
  Future<ClientProfileSnapshot> load() async =>
      const ClientProfileSnapshot(availability: ClientProfileAvailability.demo);
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore({this.accessToken});

  String? accessToken;
  String? refreshToken;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }
}
