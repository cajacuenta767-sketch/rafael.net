import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_yonke/app/widgets/responsive_scaffold.dart';

void main() {
  testWidgets(
    'floating action stays beside bounded content on a wide monitor',
    (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveScaffold(
            body: const SizedBox(key: Key('content')),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );
      final content = tester.getRect(find.byKey(const Key('content')));
      final action = tester.getRect(find.byType(FloatingActionButton));
      expect(action.right, lessThanOrEqualTo(content.right));
      expect(action.left, greaterThanOrEqualTo(content.left));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reflow preserves labels inside sized containers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveScaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: AdaptiveInline(
                children: [
                  SizedBox(width: 100, child: Text('Garantía')),
                  Expanded(child: Text('30 días')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Garantía'), findsOneWidget);
    expect(find.text('30 días'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 480),
    const Size(480, 320),
    const Size(768, 1024),
    const Size(1366, 768),
    const Size(5120, 1440),
  ]) {
    testWidgets('content remains bounded at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveScaffold(body: SizedBox(key: Key('content'))),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('content'))).width,
        lessThanOrEqualTo(1200),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('cards reflow without shrinking enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ResponsiveScaffold(
            body: ResponsiveRow(
              children: [
                for (final label in [
                  'Solicitudes nuevas',
                  'Cotizaciones enviadas',
                  'Mensajes sin leer',
                ])
                  Text(label),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Wrap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
