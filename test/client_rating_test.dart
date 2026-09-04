import 'package:app_yonke/features/quotes/domain/client_quote.dart';
import 'package:app_yonke/features/ratings/presentation/client_rating_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cliente puede enviar una calificación de prueba', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClientRatingPage(
            args: ClientRatingArgs(
              quote: mockQuoteById('mock-quote-norte')!,
              isDemo: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('client-rating-5')));
    await tester.enterText(
      find.byKey(const Key('client-rating-comment')),
      'Muy buena atención.',
    );
    await tester.ensureVisible(find.byKey(const Key('client-submit-rating')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('client-submit-rating')));
    await tester.pumpAndSettle();

    expect(find.text('Calificación de prueba enviada'), findsOneWidget);
  });
}
