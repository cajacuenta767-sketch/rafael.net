import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/auth/domain/client_auth_repository.dart';
import 'package:app_yonke/features/auth/domain/international_phone.dart';
import 'package:app_yonke/features/auth/presentation/client_login_controller.dart';
import 'package:app_yonke/features/auth/presentation/client_login_page.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires a phone before requesting an OTP', () async {
    final repository = _TestClientAuthRepository();
    final controller = _controller(repository);
    addTearDown(controller.dispose);

    expect(await controller.requestCode(), isFalse);
    expect(controller.phoneError, contains('número de celular'));
    expect(repository.requestedPhones, isEmpty);
  });

  test('normalizes a valid Mexican phone to E.164', () async {
    final repository = _TestClientAuthRepository(
      verification: const ClientOtpVerification(
        accessToken: 'verified-access-token',
        refreshToken: 'verified-refresh-token',
      ),
    );
    final store = _MemoryTokenStore();
    final controller = ClientLoginController(
      repository: repository,
      tokenStore: store,
    );
    addTearDown(controller.dispose);

    controller.updatePhone('6621234567');
    expect(await controller.requestCode(), isTrue);
    controller.updateCode('123456');

    expect(await controller.verifyCode(), isTrue);
    expect(repository.verifiedPhone, '+526621234567');
    expect(store.accessToken, 'verified-access-token');
  });

  test('validates and normalizes a Bolivian phone by its country', () async {
    final repository = _TestClientAuthRepository();
    final controller = _controller(repository);
    addTearDown(controller.dispose);

    controller.selectCountry(
      const PhoneCountry(
        isoCode: 'BO',
        dialCode: '591',
        flag: '🇧🇴',
        name: 'Bolivia',
        example: '71234567',
      ),
    );
    controller.updatePhone('71234567');

    expect(await controller.requestCode(), isTrue);
    expect(repository.requestedPhones, ['+59171234567']);
  });

  test('does not duplicate a pasted international prefix', () async {
    final repository = _TestClientAuthRepository();
    final controller = _controller(repository);
    addTearDown(controller.dispose);

    controller.updatePhone('+526621234567');

    expect(controller.phoneDigits, '6621234567');
    expect(await controller.requestCode(), isTrue);
    expect(repository.requestedPhones, ['+526621234567']);
  });

  test('does not invent a session while the API contract is pending', () async {
    final store = _MemoryTokenStore();
    final controller = ClientLoginController(
      repository: _TestClientAuthRepository(),
      tokenStore: store,
    );
    addTearDown(controller.dispose);

    controller.updatePhone('6621234567');
    await controller.requestCode();
    controller.updateCode('123456');

    expect(await controller.verifyCode(), isFalse);
    expect(store.accessToken, isNull);
    expect(controller.message, contains('contrato de sesión'));
  });

  testWidgets('starts empty and renders every login method', (tester) async {
    await tester.pumpWidget(_loginHarness(_TestClientAuthRepository()));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('client_phone_field')),
    );
    expect(field.controller!.text, isEmpty);
    expect(find.byKey(const Key('client_otp_field')), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con Apple'), findsOneWidget);
    expect(find.text('Al continuar, aceptas nuestros'), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('opens the supplied legal documents from the login', (
    tester,
  ) async {
    await tester.pumpWidget(
      _loginHarness(_TestClientAuthRepository(), initialLegalAccepted: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('read_terms')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legal_document_content')), findsOneWidget);
    expect(find.textContaining('1. ¿QUÉ ES refaNet?'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('read_privacy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legal_document_content')), findsOneWidget);
    expect(
      find.textContaining('1. Datos personales que podemos recopilar'),
      findsOneWidget,
    );
  });

  testWidgets('requires both legal documents before requesting the OTP', (
    tester,
  ) async {
    final repository = _TestClientAuthRepository();
    await tester.pumpWidget(
      _loginHarness(repository, initialLegalAccepted: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Antes de continuar'), findsOneWidget);
    expect(repository.requestedPhones, isEmpty);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm_legal_acceptance')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('accept_all_legal')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm_legal_acceptance')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('client_phone_field')),
      '6621234567',
    );
    await tester.pump();
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    expect(repository.requestedPhones, ['+526621234567']);
  });

  testWidgets('legal dialog supports individual choices and rejection review', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      _loginHarness(_TestClientAuthRepository(), initialLegalAccepted: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accept_terms')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm_legal_acceptance')),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.byKey(const Key('accept_privacy')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('accept_privacy')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm_legal_acceptance')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('reject_legal_acceptance')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legal_rejection_alert')), findsOneWidget);
    expect(find.text('No podrás utilizar refaNet'), findsOneWidget);
    await tester.tap(find.text('Volver y revisar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legal_consent_dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cannot dismiss legal consent with the system back button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _loginHarness(_TestClientAuthRepository(), initialLegalAccepted: false),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('legal_consent_dialog')), findsOneWidget);
  });

  testWidgets('opens a searchable country selector and selects Bolivia', (
    tester,
  ) async {
    await tester.pumpWidget(_loginHarness(_TestClientAuthRepository()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('country_selector')));
    await tester.pumpAndSettle();

    expect(find.text('Buscar país'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Bolivia');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bolivia').last);
    await tester.pumpAndSettle();

    expect(find.text('+591'), findsOneWidget);
  });

  testWidgets('requests the real OTP and shows the six digit interface', (
    tester,
  ) async {
    final repository = _TestClientAuthRepository();
    await tester.pumpWidget(_loginHarness(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('client_phone_field')),
      '6621234567',
    );
    await tester.pump();
    await tester.tap(find.text('Enviar código'));
    await tester.pump();

    expect(repository.requestedPhones, ['+526621234567']);
    expect(find.byKey(const Key('client_otp_field')), findsOneWidget);
    expect(find.text('Reenviar código (01:00)'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('OTP boxes accept manual input and show every digit', (
    tester,
  ) async {
    final repository = _TestClientAuthRepository();
    await tester.pumpWidget(_loginHarness(repository));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('client_phone_field')),
      '6621234567',
    );
    await tester.pump();
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('otp_digit_0')));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const Key('client_otp_field')),
    );
    expect(field.enabled, isTrue);
    expect(field.focusNode!.hasFocus, isTrue);

    await tester.enterText(find.byKey(const Key('client_otp_field')), '123');
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(repository.verificationCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('OTP boxes are writable before the API sends a code', (
    tester,
  ) async {
    final repository = _TestClientAuthRepository();
    await tester.pumpWidget(_loginHarness(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('otp_digit_0')));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const Key('client_otp_field')),
    );
    expect(field.enabled, isTrue);
    expect(field.focusNode!.hasFocus, isTrue);

    await tester.enterText(find.byKey(const Key('client_otp_field')), '123456');
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(repository.verificationCount, 0);
  });

  testWidgets('pastes a separated OTP and verifies it once automatically', (
    tester,
  ) async {
    final repository = _TestClientAuthRepository();
    await tester.pumpWidget(_loginHarness(repository));
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
      '123-456',
    );
    await tester.pump();

    expect(repository.verifiedCode, '123456');
    expect(repository.verificationCount, 1);
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      expect(find.text(digit), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('automatic OTP verification disables duplicate submission', (
    tester,
  ) async {
    final repository = _TestClientAuthRepository(
      verificationDelay: const Duration(milliseconds: 100),
    );
    await tester.pumpWidget(_loginHarness(repository));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('client_phone_field')),
      '6621234567',
    );
    await tester.pump();
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('client_otp_field')), '123456');
    await tester.pump();

    expect(repository.verificationCount, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(repository.verificationCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a vertical drag cannot move the fixed login page', (
    tester,
  ) async {
    await tester.pumpWidget(_loginHarness(_TestClientAuthRepository()));
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('client_login_card'));
    final before = tester.getTopLeft(card);

    await tester.drag(card, const Offset(0, -180));
    await tester.pump();

    expect(tester.getTopLeft(card), before);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(ListView), findsNothing);
  });

  const sizes = <Size>[
    Size(320, 640),
    Size(360, 720),
    Size(360, 800),
    Size(375, 667),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
    Size(600, 960),
    Size(800, 1280),
    Size(800, 360),
    Size(932, 430),
  ];
  const scales = <double>[1, 1.15, 1.3];

  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets(
        'fixed login fits ${size.width}x${size.height} at $scale text',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            _loginHarness(_TestClientAuthRepository(), textScale: scale),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.text('INGRESO PARA CLIENTES'), findsOneWidget);
          expect(find.text('Enviar código'), findsOneWidget);
          expect(find.byKey(const Key('client_otp_field')), findsOneWidget);
          expect(find.text('Continuar con Google'), findsOneWidget);
          expect(find.text('Continuar con Apple'), findsOneWidget);
          expect(find.text('Al continuar, aceptas nuestros'), findsNothing);
          expect(find.text('Regresar'), findsOneWidget);
          expect(find.byType(SingleChildScrollView), findsNothing);
          expect(find.byType(ListView), findsNothing);
        },
      );
    }
  }

  testWidgets('keyboard overlay keeps the phone focused and layout mounted', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = _TestClientAuthRepository();

    await tester.pumpWidget(_loginHarness(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('client_phone_field')));
    await tester.pump();
    final before = tester.getRect(find.byKey(const Key('client_phone_field')));
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasFocus,
      isTrue,
    );

    await tester.pumpWidget(_loginHarness(repository, keyboardInset: 290));
    await tester.pump();

    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasFocus,
      isTrue,
    );
    expect(tester.getRect(find.byKey(const Key('client_phone_field'))), before);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con Apple'), findsOneWidget);
  });

  testWidgets('keyboard keeps the phone and action visible without scrolling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _loginHarness(_TestClientAuthRepository(), keyboardInset: 290),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('client_phone_field')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('client_phone_field')), findsOneWidget);
    expect(find.text('Enviar código'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets(
    'OTP controls remain visible with the keyboard and never scroll',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _loginHarness(_TestClientAuthRepository(), keyboardInset: 290),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('client_phone_field')),
        '6621234567',
      );
      await tester.pump();
      await tester.tap(find.text('Enviar código'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('client_otp_field')), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('OTP boxes lift with the keyboard and return when it closes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = _TestClientAuthRepository();

    await tester.pumpWidget(_loginHarness(repository));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('client_phone_field')),
      '6621234567',
    );
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('otp_digit_0')));
    await tester.pump();
    final normalTop = tester
        .getTopLeft(find.byKey(const Key('otp_digit_0')))
        .dy;

    await tester.pumpWidget(_loginHarness(repository, keyboardInset: 290));
    await tester.pump();
    final keyboardTop = tester
        .getTopLeft(find.byKey(const Key('otp_digit_0')))
        .dy;
    expect(keyboardTop, lessThan(normalTop));

    await tester.pumpWidget(_loginHarness(repository));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('otp_digit_0'))).dy,
      normalTop,
    );
  });
}

ClientLoginController _controller(ClientAuthRepository repository) =>
    ClientLoginController(
      repository: repository,
      tokenStore: _MemoryTokenStore(),
    );

Widget _loginHarness(
  ClientAuthRepository repository, {
  double textScale = 1,
  double keyboardInset = 0,
  bool initialLegalAccepted = true,
}) {
  return ProviderScope(
    overrides: [
      clientAuthRepositoryProvider.overrideWithValue(repository),
      tokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        CountryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('es'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
        ),
        child: child!,
      ),
      home: ClientLoginPage(initialLegalAccepted: initialLegalAccepted),
    ),
  );
}

class _TestClientAuthRepository implements ClientAuthRepository {
  _TestClientAuthRepository({
    this.verification = const ClientOtpVerification(
      sessionContractPending: true,
    ),
    this.verificationDelay = Duration.zero,
  });

  final ClientOtpVerification verification;
  final Duration verificationDelay;
  final List<String> requestedPhones = [];
  String? verifiedPhone;
  String? verifiedCode;
  int verificationCount = 0;

  @override
  Future<ClientOtpVerification> loginWithGoogle(String idToken) async =>
      verification;

  @override
  Future<void> requestOtp(String phone) async => requestedPhones.add(phone);

  @override
  Future<ClientOtpVerification> verifyOtp({
    required String phone,
    required String code,
  }) async {
    verificationCount++;
    verifiedPhone = phone;
    verifiedCode = code;
    if (verificationDelay > Duration.zero) {
      await Future<void>.delayed(verificationDelay);
    }
    return verification;
  }
}

class _MemoryTokenStore implements TokenStore {
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
