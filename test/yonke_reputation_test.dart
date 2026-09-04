import 'package:app_yonke/features/ratings/data/yonke_reputation_repository.dart';
import 'package:app_yonke/features/ratings/presentation/yonke_reputation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'calcula reputación desde las calificaciones documentadas por la API',
    () {
      final reputation = reputationFromResponse({
        'data': [
          {'calificacion': 5, 'comentario': 'Excelente', 'activa': true},
          {'calificacion': 3, 'comentario': 'Sin usar', 'activa': false},
          {'calificacion': 4, 'comentario': 'Buena atención', 'activa': true},
        ],
      });

      expect(reputation.count, 2);
      expect(reputation.average, 4.5);
      expect(reputation.comments.map((item) => item.comment), [
        'Excelente',
        'Buena atención',
      ]);
    },
  );

  testWidgets('muestra reputación de prueba del yonke', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: YonkeReputationCard(
              yonkeId: 'mock-yonke-norte',
              isDemo: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4.7'), findsOneWidget);
    expect(find.text('3 calificaciones'), findsOneWidget);
    expect(find.textContaining('Buena atención'), findsOneWidget);
  });
}
