import 'package:app_yonke/features/yonke_messages/presentation/yonke_messages_page.dart';
import 'package:app_yonke/features/yonke_profile/presentation/yonke_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('yonke demo inbox opens a conversation and sends a message', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/yonke/mensajes',
      routes: [
        GoRoute(
          path: '/yonke/mensajes',
          builder: (context, state) =>
              const YonkeMessagesPage(isDemoSession: true),
        ),
        GoRoute(
          path: '/yonke/mensajes/:quoteId',
          builder: (context, state) => YonkeConversationPage(
            args: state.extra! as YonkeConversationArgs,
          ),
        ),
        GoRoute(
          path: '/yonke',
          builder: (context, state) =>
              const Scaffold(body: Text('SOLICITUDES')),
        ),
        GoRoute(
          path: '/yonke/cotizaciones',
          builder: (context, state) =>
              const Scaffold(body: Text('COTIZACIONES')),
        ),
        GoRoute(
          path: '/yonke/perfil',
          builder: (context, state) =>
              const YonkeProfilePage(isDemoSession: true),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conversaciones'), findsOneWidget);
    expect(find.textContaining('Mensajes de prueba'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('yonke-conversation-demo-quote-alternador')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hola, ¿la pieza incluye garantía?'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('yonke-message-input')),
      'La garantía está confirmada.',
    );
    await tester.tap(find.byKey(const Key('yonke-send-message')));
    await tester.pumpAndSettle();

    expect(find.text('La garantía está confirmada.'), findsOneWidget);
    expect(find.text('Mensaje enviado.'), findsOneWidget);
  });
}
