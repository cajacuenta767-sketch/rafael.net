import 'package:app_yonke/features/requests/domain/request_draft.dart';
import 'package:app_yonke/features/requests/presentation/request_review_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cliente envía una solicitud de prueba a yonkes con cobertura', (
    tester,
  ) async {
    final draft = RequestDraft()
      ..part = 'Alternador'
      ..brandId = 1
      ..brandName = 'Nissan'
      ..modelId = 1
      ..modelName = 'Altima'
      ..year = 2018
      ..cityId = 1
      ..cityName = 'Nogales, Sonora';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: RequestReviewPage(draft: draft)),
      ),
    );

    expect(find.text('Enviar solicitud'), findsOneWidget);
    await tester.tap(find.byKey(const Key('submit-client-request')));
    await tester.pumpAndSettle();

    expect(find.text('Solicitud de prueba enviada'), findsOneWidget);
    expect(
      find.textContaining('yonkes con cobertura en tu ciudad'),
      findsOneWidget,
    );
  });
}
