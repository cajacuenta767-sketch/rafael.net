import 'package:app_yonke/app/router/app_router.dart';
import 'package:app_yonke/features/home/presentation/client_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('el botón central ofrece las dos acciones rápidas', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.bySemanticsLabel('Abrir acciones rápidas'));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué deseas hacer?'), findsOneWidget);
    expect(find.text('Nueva solicitud'), findsOneWidget);
    expect(find.text('Explorar yonkes'), findsOneWidget);

    await tester.tap(find.text('Explorar yonkes'));
    await tester.pumpAndSettle();
    expect(find.text('Pantalla de yonkes'), findsOneWidget);
  });

  testWidgets('Nueva solicitud abre la ruta de creación', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.bySemanticsLabel('Abrir acciones rápidas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva solicitud'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de nueva solicitud'), findsOneWidget);
  });
}

GoRouter _router() => GoRouter(
  initialLocation: '/prueba',
  routes: [
    GoRoute(
      path: '/prueba',
      builder: (_, _) => const Scaffold(
        body: Text('Inicio'),
        bottomNavigationBar: ClientBottomNavigation(currentIndex: 0),
      ),
    ),
    GoRoute(
      path: AppRoutes.clientNewRequest,
      builder: (_, _) => const Scaffold(
        body: Center(child: Text('Pantalla de nueva solicitud')),
      ),
    ),
    GoRoute(
      path: AppRoutes.clientYonkes,
      builder: (_, _) =>
          const Scaffold(body: Center(child: Text('Pantalla de yonkes'))),
    ),
  ],
);
