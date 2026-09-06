import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/auth/presentation/yonke_session_gate.dart';
import 'package:app_yonke/features/yonke_profile/data/yonke_profile_repository.dart';
import 'package:app_yonke/features/yonke_profile/domain/yonke_profile.dart';
import 'package:app_yonke/features/yonke_profile/presentation/yonke_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('yonke profile shows the API data and exposes its operations', (
    tester,
  ) async {
    final store = _MemoryTokenStore(accessToken: 'test-token');
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('Perfil del yonke'), findsOneWidget);
    expect(find.text('Yonke Norte'), findsOneWidget);
    expect(find.text('Perfil de la API'), findsOneWidget);
    expect(find.text('+52 631 123 4567'), findsOneWidget);
    expect(find.text('Solicitudes recibidas'), findsOneWidget);
    expect(find.text('Cotizaciones enviadas'), findsOneWidget);
    expect(find.text('Ciudades de cobertura'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('yonke sign out clears local credentials and returns to login', (
    tester,
  ) async {
    final store = _MemoryTokenStore(accessToken: 'test-token');
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('yonke-sign-out')));
    await tester.tap(find.byKey(const Key('yonke-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-yonke-sign-out')));
    await tester.pumpAndSettle();

    expect(store.accessToken, isNull);
    expect(find.text('LOGIN YONKE'), findsOneWidget);
  });

  testWidgets('protected yonke content redirects when there is no session', (
    tester,
  ) async {
    final store = _MemoryTokenStore();
    final router = GoRouter(
      initialLocation: '/privado',
      routes: [
        GoRoute(
          path: '/privado',
          builder: (context, state) => YonkeSessionGate(
            builder: (_) => const Text('CONTENIDO YONKE PROTEGIDO'),
          ),
        ),
        GoRoute(
          path: '/yonke/login',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('LOGIN YONKE'))),
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

    expect(find.text('LOGIN YONKE'), findsOneWidget);
    expect(find.text('CONTENIDO YONKE PROTEGIDO'), findsNothing);
  });
}

Widget _app(_MemoryTokenStore store) {
  final router = GoRouter(
    initialLocation: '/yonke/perfil',
    routes: [
      GoRoute(
        path: '/yonke/perfil',
        builder: (context, state) => YonkeProfilePage(
          tokenStore: store,
          repository: const _FixedProfileRepository(),
        ),
      ),
      GoRoute(
        path: '/yonke/login',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('LOGIN YONKE'))),
      ),
      GoRoute(
        path: '/yonke',
        builder: (context, state) => const Scaffold(body: Text('SOLICITUDES')),
      ),
      GoRoute(
        path: '/yonke/cotizaciones',
        builder: (context, state) => const Scaffold(body: Text('COTIZACIONES')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [tokenStoreProvider.overrideWithValue(store)],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _FixedProfileRepository implements YonkeProfileRepository {
  const _FixedProfileRepository();

  @override
  Future<YonkeProfileSnapshot> load() async => const YonkeProfileSnapshot(
    availability: YonkeProfileAvailability.available,
    profile: YonkeProfile(
      guidId: 'yonke-1',
      name: 'Yonke Norte',
      manager: 'Rafael',
      phone: '+52 631 123 4567',
      email: 'norte@ejemplo.com',
      address: 'Av. Obregón 100',
      postalCode: 84000,
      city: 'Nogales, Sonora',
    ),
  );
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore({this.accessToken});

  String? accessToken;
  String? refreshToken;

  DateTime? expiresAt;
  String? yonkeGuidId;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
    yonkeGuidId = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<DateTime?> readExpiresAt() async => expiresAt;

  @override
  Future<String?> readYonkeGuidId() async => yonkeGuidId;

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.expiresAt = expiresAt;
    this.yonkeGuidId = yonkeGuidId;
  }
}
