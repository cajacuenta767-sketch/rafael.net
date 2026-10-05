import 'package:app_yonke/app/widgets/adaptive_navigation.dart';
import 'package:app_yonke/app/widgets/responsive_scaffold.dart';
import 'package:app_yonke/features/home/presentation/client_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'navegación lateral en escritorio conserva formulario al reducir',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveScaffold(
            bottomNavigationBar: ClientBottomNavigation(currentIndex: 0),
            body: _Draft(),
          ),
        ),
      );
      expect(find.byType(SideNavigation), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Borrador conservado');
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
      expect(find.byType(SideNavigation), findsNothing);
      expect(find.text('Borrador conservado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      await tester.pumpAndSettle();
      expect(find.byType(SideNavigation), findsOneWidget);
      expect(find.text('Borrador conservado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Draft extends StatefulWidget {
  const _Draft();
  @override
  State<_Draft> createState() => _DraftState();
}

class _DraftState extends State<_Draft> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Center(child: TextField(controller: controller));
}
