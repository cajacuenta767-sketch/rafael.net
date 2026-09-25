import 'dart:typed_data';

import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_file.dart';
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
  testWidgets('profile matches the menu and exposes functional modules', (
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
    expect(find.text('Cliente Refanet'), findsOneWidget);
    expect(find.text('Mis datos'), findsOneWidget);
    expect(find.text('Direcciones'), findsOneWidget);
    expect(find.text('Métodos de pago'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Ayuda y soporte'), findsOneWidget);
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

  testWidgets('edita datos, notificaciones y direcciones localmente', (
    tester,
  ) async {
    final repository = _EditableProfileRepository()
      ..profile = const ClientProfile(
        name: 'Cliente Refanet',
        phone: '+526621234567',
        email: 'noe@email.com',
        stateId: 26,
        stateName: 'Sonora',
        cityId: 12,
        cityName: 'Hermosillo',
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(_CatalogApi())],
        child: MaterialApp(
          home: ClientProfilePage(
            repository: repository,
            tokenStore: _MemoryTokenStore(accessToken: 'test-token'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-data')));
    await tester.pumpAndSettle();
    expect(find.text('Mis datos'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      'Noe Gamez',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-profile-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-profile-data')));
    await tester.pumpAndSettle();
    expect(find.text('Noe Gamez'), findsOneWidget);
    expect(repository.profile.cityName, 'Hermosillo');
    expect(repository.profile.email, 'noe@email.com');

    await tester.ensureVisible(find.byKey(const Key('profile-notifications')));
    await tester.tap(find.byKey(const Key('profile-notifications')));
    await tester.pumpAndSettle();
    expect(repository.notificationsEnabled, isFalse);

    await tester.ensureVisible(find.byKey(const Key('profile-addresses')));
    await tester.tap(find.byKey(const Key('profile-addresses')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-address')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('address-street-field')),
      'Av. Reforma 123',
    );
    await tester.enterText(
      find.byKey(const Key('address-city-field')),
      'Nogales, Sonora',
    );
    await tester.tap(find.byKey(const Key('save-address')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Av. Reforma 123'), findsOneWidget);
  });

  testWidgets('perfil conserva la composición visual de referencia', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _EditableProfileRepository()
      ..profile = const ClientProfile(
        name: 'Noe Gamez',
        email: 'nogamez@email.com',
      );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClientProfilePage(
            repository: repository,
            tokenStore: _MemoryTokenStore(accessToken: 'test-token'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ClientProfilePage),
      matchesGoldenFile('goldens/client_profile_reference.png'),
    );
  });
}

GoRouter _profileRouter(_MemoryTokenStore store) => GoRouter(
  initialLocation: '/cliente/perfil',
  routes: [
    GoRoute(
      path: '/cliente/perfil',
      builder: (context, state) => ClientProfilePage(
        tokenStore: store,
        repository: const _PendingProfileRepository(),
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

class _PendingProfileRepository implements ClientProfileRepository {
  const _PendingProfileRepository();

  @override
  Future<List<ClientAddress>> loadAddresses() async => const [];

  @override
  Future<bool> readNotificationsEnabled() async => true;

  @override
  Future<void> saveAddresses(List<ClientAddress> addresses) async {}

  @override
  Future<void> saveProfile(ClientProfile profile) async {}

  @override
  Future<void> writeNotificationsEnabled(bool enabled) async {}

  @override
  Future<ClientProfileSnapshot> load() async => const ClientProfileSnapshot(
    availability: ClientProfileAvailability.available,
    profile: ClientProfile(name: 'Cliente Refanet'),
  );

  @override
  Future<bool> needsOnboarding() async => false;

  @override
  Future<ClientProfile> draftForOnboarding() async => const ClientProfile();

  @override
  Future<void> saveLoginHints(ClientLoginHints hints) async {}

  @override
  Future<String> savePhoto(
    Uint8List bytes, {
    required String extension,
  }) async => '/tmp/foto.$extension';

  @override
  Future<void> deletePhoto(String path) async {}
}

class _EditableProfileRepository implements ClientProfileRepository {
  ClientProfile profile = const ClientProfile(name: 'Cliente Refanet');
  List<ClientAddress> addresses = [];
  bool notificationsEnabled = true;

  @override
  Future<ClientProfileSnapshot> load() async => ClientProfileSnapshot(
    availability: ClientProfileAvailability.available,
    profile: profile,
  );

  @override
  Future<List<ClientAddress>> loadAddresses() async => addresses;

  @override
  Future<bool> readNotificationsEnabled() async => notificationsEnabled;

  @override
  Future<void> saveAddresses(List<ClientAddress> value) async {
    addresses = value;
  }

  @override
  Future<void> saveProfile(ClientProfile value) async {
    profile = value;
  }

  @override
  Future<void> writeNotificationsEnabled(bool enabled) async {
    notificationsEnabled = enabled;
  }

  @override
  Future<bool> needsOnboarding() async => false;

  @override
  Future<ClientProfile> draftForOnboarding() async => const ClientProfile();

  @override
  Future<void> saveLoginHints(ClientLoginHints hints) async {}

  @override
  Future<String> savePhoto(
    Uint8List bytes, {
    required String extension,
  }) async => '/tmp/foto.$extension';

  @override
  Future<void> deletePhoto(String path) async {}
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

/// Catálogo de estados y ciudades con la forma de `Utilerias`.
class _CatalogApi implements ApiClient {
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => switch (path) {
    '/api/Utilerias/entidades' => {
      'data': [
        {'id': 26, 'entidad': 'Sonora'},
        {'id': 2, 'entidad': 'Baja California'},
      ],
    },
    '/api/Utilerias/entidad/26/ciudades' => {
      'data': [
        {'id': 12, 'ciudad': 'Hermosillo'},
        {'id': 13, 'ciudad': 'Nogales'},
      ],
    },
    _ => {'data': <Object>[]},
  };

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => throw UnimplementedError(path);

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => throw UnimplementedError(path);

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => throw UnimplementedError(path);

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) async => throw UnimplementedError(path);
}
