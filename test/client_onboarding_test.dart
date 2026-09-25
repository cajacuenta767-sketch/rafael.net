import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/auth/domain/client_auth_repository.dart';
import 'package:app_yonke/features/auth/presentation/client_login_page.dart';
import 'package:app_yonke/features/auth/presentation/client_session_gate.dart';
import 'package:app_yonke/features/profile/data/client_profile_repository.dart';
import 'package:app_yonke/features/profile/domain/client_profile.dart';
import 'package:app_yonke/features/profile/presentation/client_onboarding_page.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// JWT de cliente como lo firma el API (`JwtService.GenerarTokenCliente`).
String _jwt(String sub, {String? name, String? email, String? phone}) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': sub, 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name': ?name, 'email': ?email, 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/mobilephone': ?phone, 'http://schemas.microsoft.com/ws/2008/06/identity/claims/role': 'Cliente', 'exp': DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000})}.firma';
}

const _complete = ClientProfile(
  name: 'Noe Gamez',
  phone: '+526621234567',
  email: 'noe@email.com',
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  LocalClientProfileRepository repositoryFor(_MemoryTokenStore tokens) =>
      LocalClientProfileRepository(
        tokenStore: tokens,
        photosDirectory: () async => Directory.systemTemp.createTemp('perfil'),
      );

  group('perfil del cliente en el dispositivo', () {
    test('un cliente de OTP es nuevo y su teléfono no es su nombre', () async {
      final tokens = _MemoryTokenStore(
        _jwt('cliente-1', name: 'Cliente refaNet', phone: '+526621234567'),
      );
      final repository = repositoryFor(tokens);
      await repository.saveLoginHints(
        const ClientLoginHints(phone: '+526621234567'),
      );

      expect(await repository.needsOnboarding(), isTrue);
      final draft = await repository.draftForOnboarding();
      expect(draft.name, isNull);
      expect(draft.phone, '+526621234567');
    });

    test('un cliente de Google llega con nombre, correo y foto', () async {
      final tokens = _MemoryTokenStore(
        _jwt('cliente-2', name: 'Ana López', email: 'ana@gmail.com'),
      );
      final repository = repositoryFor(tokens);
      await repository.saveLoginHints(
        const ClientLoginHints(
          name: 'Ana López',
          email: 'ana@gmail.com',
          photoUrl: 'https://lh3.googleusercontent.com/foto',
        ),
      );

      final draft = await repository.draftForOnboarding();
      expect(draft.name, 'Ana López');
      expect(draft.email, 'ana@gmail.com');
      expect(draft.phone, isNull);
      expect(draft.photoUrl, 'https://lh3.googleusercontent.com/foto');
    });

    test('con el perfil completo ya no pide el registro', () async {
      final repository = repositoryFor(_MemoryTokenStore(_jwt('cliente-3')));
      await repository.saveProfile(_complete);

      expect(await repository.needsOnboarding(), isFalse);
      final snapshot = await repository.load();
      expect(snapshot.profile.name, 'Noe Gamez');
      expect(snapshot.profile.email, 'noe@email.com');
    });

    test('dos cuentas en el mismo teléfono no comparten perfil', () async {
      final tokens = _MemoryTokenStore(_jwt('cliente-a'));
      final repository = repositoryFor(tokens);
      await repository.saveProfile(_complete);

      tokens.accessToken = _jwt('cliente-b');
      expect(await repository.needsOnboarding(), isTrue);
      expect((await repository.load()).profile.name, isNull);

      tokens.accessToken = _jwt('cliente-a');
      expect(await repository.needsOnboarding(), isFalse);
    });

    test('el perfil guardado con la clave anterior se adopta', () async {
      FlutterSecureStorage.setMockInitialValues({
        'client.profile': jsonEncode(
          _complete.toJson()..['id'] = 'cliente-viejo',
        ),
      });
      final repository = repositoryFor(
        _MemoryTokenStore(_jwt('cliente-viejo')),
      );

      expect(await repository.needsOnboarding(), isFalse);
    });

    test('sin sesión no pide registro', () async {
      final repository = repositoryFor(_MemoryTokenStore(null));
      expect(await repository.needsOnboarding(), isFalse);
    });

    test('la foto se guarda en el dispositivo y se puede borrar', () async {
      final repository = repositoryFor(_MemoryTokenStore(_jwt('cliente-4')));
      final path = await repository.savePhoto(
        Uint8List.fromList([1, 2, 3]),
        extension: 'png',
      );

      expect(File(path).existsSync(), isTrue);
      expect(path, endsWith('.png'));
      await repository.deletePhoto(path);
      expect(File(path).existsSync(), isFalse);
    });
  });

  test('el login de Google expone nombre, correo y foto de la respuesta', () {
    final result = ClientOtpVerification.fromResponse({
      'token': _jwt('cliente-5'),
      'clienteGuidId': 'cliente-5',
      'nombre': 'Ana López',
      'correo': 'ana@gmail.com',
      'fotoPerfil': 'https://lh3.googleusercontent.com/foto',
    });

    expect(result.name, 'Ana López');
    expect(result.email, 'ana@gmail.com');
    expect(result.photoUrl, 'https://lh3.googleusercontent.com/foto');
  });

  group('pantalla de registro', () {
    GoRouter router(String initial) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/cliente',
          builder: (context, state) => ClientSessionGate(
            builder: (_) => const Scaffold(body: Text('INICIO')),
          ),
        ),
        GoRoute(
          path: '/cliente/registro',
          builder: (context, state) => ClientSessionGate(
            requireCompleteProfile: false,
            builder: (_) => const ClientOnboardingPage(),
          ),
        ),
        GoRoute(
          path: '/cliente/login',
          builder: (context, state) => const Scaffold(body: Text('LOGIN')),
        ),
      ],
    );

    Widget app(_MemoryTokenStore tokens, GoRouter router) => ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWithValue(_CatalogApi()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );

    Future<void> loginWithOtp(
      WidgetTester tester,
      _MemoryTokenStore tokens,
    ) async {
      final router = GoRouter(
        initialLocation: '/cliente/login',
        routes: [
          GoRoute(
            path: '/cliente/login',
            builder: (context, state) =>
                const ClientLoginPage(initialLegalAccepted: true),
          ),
          GoRoute(
            path: '/cliente',
            builder: (context, state) => const Scaffold(body: Text('INICIO')),
          ),
          GoRoute(
            path: '/cliente/registro',
            builder: (context, state) => const ClientOnboardingPage(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStoreProvider.overrideWithValue(tokens),
            clientAuthRepositoryProvider.overrideWithValue(
              _OtpRepository(_jwt('cliente-otp', name: 'Cliente refaNet')),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              CountryLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('es')],
            locale: const Locale('es'),
            home: Router(
              routerDelegate: router.routerDelegate,
              routeInformationParser: router.routeInformationParser,
              routeInformationProvider: router.routeInformationProvider,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('client_phone_field')),
        '6621234567',
      );
      await tester.pump();
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('otp_digit_0')));
      await tester.enterText(
        find.byKey(const Key('client_otp_field')),
        '123456',
      );
      await tester.pumpAndSettle();
    }

    testWidgets('OTP de un cliente nuevo abre directo el registro', (
      tester,
    ) async {
      final tokens = _MemoryTokenStore(null);
      await loginWithOtp(tester, tokens);

      expect(find.text('Completa tu perfil'), findsOneWidget);
      expect(find.text('INICIO'), findsNothing);
      final phone = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('profile-phone-field')),
          matching: find.byType(TextField),
        ),
      );
      expect(phone.controller!.text, contains('6621234567'));
    });

    testWidgets('OTP de un cliente ya registrado va al inicio', (tester) async {
      final tokens = _MemoryTokenStore(_jwt('cliente-otp'));
      await LocalClientProfileRepository(tokenStore: tokens)
          .saveProfile(_complete);
      tokens.accessToken = null;

      await loginWithOtp(tester, tokens);

      expect(find.text('INICIO'), findsOneWidget);
      expect(find.text('Completa tu perfil'), findsNothing);
    });

    testWidgets('un cliente ya registrado entra directo al inicio', (
      tester,
    ) async {
      final tokens = _MemoryTokenStore(_jwt('cliente-6'));
      await LocalClientProfileRepository(tokenStore: tokens)
          .saveProfile(_complete);

      await tester.pumpWidget(app(tokens, router('/cliente')));
      await tester.pumpAndSettle();

      expect(find.text('INICIO'), findsOneWidget);
      expect(find.text('Completa tu perfil'), findsNothing);
    });

    testWidgets('un cliente nuevo completa el registro y llega al inicio', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tokens = _MemoryTokenStore(
        _jwt('cliente-7', name: 'Cliente refaNet'),
      );
      await LocalClientProfileRepository(tokenStore: tokens)
          .saveLoginHints(const ClientLoginHints(phone: '+526621234567'));

      await tester.pumpWidget(app(tokens, router('/cliente')));
      await tester.pumpAndSettle();

      expect(find.text('Completa tu perfil'), findsOneWidget);
      expect(find.text('Agregar foto (opcional)'), findsOneWidget);
      // Solo los campos que existen en la tabla Clientes del API.
      expect(find.text('Estado *'), findsNothing);
      expect(find.text('Ciudad *'), findsNothing);
      final phone = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('profile-phone-field')),
          matching: find.byType(TextField),
        ),
      );
      expect(phone.controller!.text, '+526621234567');
      expect(phone.readOnly, isTrue);

      // Sin los datos obligatorios no avanza.
      await tester.tap(find.byKey(const Key('save-profile-data')));
      await tester.pumpAndSettle();
      expect(find.text('Escribe tu nombre completo'), findsOneWidget);
      expect(find.text('INICIO'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('profile-name-field')),
        'Noe Gamez',
      );
      await tester.enterText(
        find.byKey(const Key('profile-email-field')),
        'noe@email.com',
      );
      await tester.tap(find.byKey(const Key('save-profile-data')));
      await tester.pumpAndSettle();

      expect(find.text('INICIO'), findsOneWidget);
      final saved = await LocalClientProfileRepository(tokenStore: tokens)
          .load();
      expect(saved.profile.name, 'Noe Gamez');
      expect(saved.profile.phone, '+526621234567');
      expect(saved.profile.photoPath, isNull);
    });
  });
}

class _OtpRepository implements ClientAuthRepository {
  _OtpRepository(this.token);

  final String token;

  @override
  Future<ClientOtpVerification> loginWithGoogle(String idToken) =>
      throw UnimplementedError();

  @override
  Future<void> requestOtp(String phone) async {}

  @override
  Future<ClientOtpVerification> verifyOtp({
    required String phone,
    required String code,
  }) async => ClientOtpVerification.fromResponse({
    'token': token,
    'nombre': 'Cliente refaNet',
  });
}

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

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore(this.accessToken);

  String? accessToken;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<DateTime?> readExpiresAt() async => null;

  @override
  Future<String?> readYonkeGuidId() async => null;

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async => this.accessToken = accessToken;

  @override
  Future<void> clear() async => accessToken = null;
}
