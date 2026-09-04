import 'package:app_yonke/features/yonke_coverage/presentation/yonke_coverage_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('yonke demo selecciona y guarda ciudades de cobertura', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: YonkeCoveragePage(isDemoSession: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nogales'), findsOneWidget);
    expect(find.text('Hermosillo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('yonke-coverage-city-3')));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yonke-save-coverage')));
    await tester.pumpAndSettle();

    expect(find.text('Cobertura de prueba guardada.'), findsOneWidget);
  });
}
