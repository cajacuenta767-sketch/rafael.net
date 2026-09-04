import 'package:app_yonke/features/yonke_notifications/presentation/yonke_notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('yonke demo puede generar un aviso de prueba', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: YonkeNotificationsPage(isDemoSession: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Avisos recientes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('yonke-demo-notification')));
    await tester.pumpAndSettle();

    expect(find.text('Nueva solicitud de prueba'), findsOneWidget);
    expect(find.text('Aviso de prueba recibido.'), findsOneWidget);
  });
}
