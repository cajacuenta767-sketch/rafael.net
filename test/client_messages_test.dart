import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_yonke/features/messages/presentation/client_conversation_page.dart';
import 'package:app_yonke/features/quotes/domain/client_quote.dart';

void main() {
  testWidgets('cliente puede ver y enviar un mensaje de prueba', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClientConversationPage(
            args: ClientConversationArgs(
              quote: mockQuoteById('mock-quote-norte')!,
              isDemo: true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Hola, ¿la pieza incluye garantía?'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('client-message-input')),
      '¿Puedes enviarla mañana?',
    );
    await tester.tap(find.byKey(const Key('client-send-message')));
    await tester.pumpAndSettle();

    expect(find.text('¿Puedes enviarla mañana?'), findsOneWidget);
    expect(find.text('Mensaje enviado.'), findsOneWidget);
  });
}
