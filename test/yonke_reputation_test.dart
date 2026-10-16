import 'package:app_yonke/features/ratings/data/yonke_reputation_repository.dart';
import 'package:app_yonke/features/ratings/domain/yonke_reputation.dart';
import 'package:app_yonke/features/ratings/presentation/yonke_reputation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('un yonke sin identificador no deja un cargador permanente', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: YonkeReputationCard(yonkeId: '')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('falta identificar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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

  testWidgets('muestra la reputación que entrega el repositorio', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: YonkeReputationCard(
              yonkeId: 'yonke-norte',
              repository: _FixedReputationRepository(),
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

  testWidgets(
    'muestra estado sin calificaciones si el repositorio falla o está vacío',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: YonkeReputationCard(
                yonkeId: 'yonke-nuevo',
                repository: _FailingReputationRepository(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Este yonke aún no tiene calificaciones.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.star_outline), findsOneWidget);
      expect(find.text('No se pudo cargar la reputación.'), findsNothing);
    },
  );
}

class _FailingReputationRepository implements YonkeReputationRepository {
  const _FailingReputationRepository();

  @override
  Future<YonkeReputation> getReputation(String yonkeId) async =>
      throw Exception('API 500');
}

class _FixedReputationRepository implements YonkeReputationRepository {
  const _FixedReputationRepository();

  @override
  Future<YonkeReputation> getReputation(String yonkeId) async =>
      const YonkeReputation(
        records: [
          YonkeRatingRecord(rating: 5, comment: 'Buena atención y rapidez.'),
          YonkeRatingRecord(rating: 4, comment: 'Respondieron rápido.'),
          YonkeRatingRecord(rating: 5),
        ],
      );
}
