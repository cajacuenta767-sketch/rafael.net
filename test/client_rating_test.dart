import 'package:app_yonke/features/quotes/domain/client_quote.dart';
import 'package:app_yonke/features/ratings/data/client_ratings_repository.dart';
import 'package:app_yonke/features/ratings/presentation/client_rating_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cliente envía una calificación con comentario', (tester) async {
    final repository = _RecordingRatingsRepository();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClientRatingPage(
            args: ClientRatingArgs(quote: _quote),
            repository: repository,
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

    expect(repository.ratings.single, (
      quoteId: 'quote-norte',
      rating: 5,
      comment: 'Muy buena atención.',
    ));
    expect(find.text('Gracias por tu calificación'), findsOneWidget);
  });
}

const _quote = ClientQuote(
  id: 'quote-norte',
  requestId: 'request-alternador',
  yonkeId: 'yonke-norte',
  yonkeName: 'Yonke Norte',
  price: 1700,
  available: true,
  isNew: false,
  hasWarranty: true,
  warrantyDays: 15,
  shippingAvailable: true,
  shippingCost: 120,
  active: true,
  status: 'Enviada',
  imageUrls: [],
);

class _RecordingRatingsRepository implements ClientRatingsRepository {
  final ratings = <({String quoteId, int rating, String? comment})>[];

  @override
  Future<void> register({
    required String quoteId,
    required int rating,
    String? comment,
  }) async {
    ratings.add((quoteId: quoteId, rating: rating, comment: comment));
  }
}
