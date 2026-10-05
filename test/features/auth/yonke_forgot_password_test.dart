import 'package:app_yonke/features/auth/domain/yonke_auth_repository.dart';
import 'package:app_yonke/features/auth/presentation/yonke_forgot_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeYonkeAuthRepository implements YonkeAuthRepository {
  String? lastRequestedEmail;
  bool shouldFail = false;

  @override
  Future<YonkeLoginResult> login({
    required String email,
    required String password,
  }) async =>
      const YonkeLoginResult(sessionContractPending: false);

  @override
  Future<String> requestPasswordReset(String email) async {
    lastRequestedEmail = email;
    if (shouldFail) {
      throw Exception('Fallo de red');
    }
    return 'Si el correo está registrado, recibirás instrucciones para recuperar tu contraseña.';
  }
}

void main() {
  testWidgets('muestra validación si el correo es inválido', (tester) async {
    final repo = _FakeYonkeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: YonkeForgotPasswordPage(repository: repo),
        ),
      ),
    );

    expect(find.text('Recuperar contraseña'), findsOneWidget);
    final submitButton = find.byKey(const Key('yonke-forgot-submit-button'));
    expect(submitButton, findsOneWidget);

    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu correo electrónico.'), findsOneWidget);
    expect(repo.lastRequestedEmail, isNull);

    await tester.enterText(
      find.byKey(const Key('yonke-forgot-email-field')),
      'correo-invalido',
    );
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un correo electrónico válido.'), findsOneWidget);
    expect(repo.lastRequestedEmail, isNull);
  });

  testWidgets('envía solicitud exitosamente y pasa a pantalla de éxito con cooldown', (
    tester,
  ) async {
    final repo = _FakeYonkeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: YonkeForgotPasswordPage(repository: repo),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('yonke-forgot-email-field')),
      'contacto@yonke.com',
    );
    await tester.tap(find.byKey(const Key('yonke-forgot-submit-button')));
    await tester.pumpAndSettle();

    expect(repo.lastRequestedEmail, 'contacto@yonke.com');
    expect(find.text('¡Revisa tu correo!'), findsOneWidget);
    expect(
      find.textContaining('Si el correo está registrado, recibirás instrucciones'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('yonke-open-mail-app-button')), findsOneWidget);
    expect(find.byKey(const Key('yonke-resend-reset-button')), findsOneWidget);
  });
}
