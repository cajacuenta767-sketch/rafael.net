import 'package:app_yonke/app/app.dart';
import 'package:app_yonke/app/router/app_router.dart';
import 'package:app_yonke/core/config/app_config.dart';
import 'package:app_yonke/core/network/api_endpoints.dart';
import 'package:app_yonke/core/network/api_envelope.dart';
import 'package:app_yonke/features/auth/presentation/client_login_page.dart';
import 'package:app_yonke/features/home/presentation/role_home_page.dart';
import 'package:app_yonke/features/home/presentation/start_page.dart';
import 'package:app_yonke/features/requests/domain/request_draft.dart';
import 'package:app_yonke/features/requests/presentation/request_city_page.dart';
import 'package:app_yonke/features/requests/presentation/my_requests_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('shows both application roles', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: YonkeApp()));
    await tester.pumpAndSettle();

    expect(find.byType(RichText), findsAtLeastNWidgets(1));
    expect(find.text('Soy cliente'), findsOneWidget);
    expect(find.text('Soy Yonke'), findsOneWidget);
  });

  testWidgets('opens the client login from the client role button', (
    tester,
  ) async {
    appRouter.go(AppRoutes.start);
    await tester.pumpWidget(const ProviderScope(child: YonkeApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Soy cliente'));
    await tester.pumpAndSettle();

    expect(find.text('INGRESO PARA CLIENTES'), findsOneWidget);
    appRouter.go(AppRoutes.start);
  });

  testWidgets('mock Google access opens the client home', (tester) async {
    expect(AppConfig.enableMockAuth, isTrue);
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => const ClientLoginPage(initialLegalAccepted: true),
        ),
        GoRoute(
          path: AppRoutes.clientHome,
          builder: (_, _) => const RoleHomePage.client(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, cliente'), findsOneWidget);
  }, skip: !AppConfig.enableMockAuth);

  const portraitSizes = <Size>[
    Size(320, 640),
    Size(360, 720),
    Size(360, 800),
    Size(375, 667),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
    Size(600, 960),
    Size(800, 1280),
  ];
  const landscapeSizes = <Size>[Size(800, 360), Size(932, 430)];
  const textScales = <double>[1, 1.15, 1.3];

  for (final size in [...portraitSizes, ...landscapeSizes]) {
    for (final textScale in textScales) {
      testWidgets(
        'welcome is responsive at ${size.width}x${size.height} and $textScale text',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(_responsiveHarness(textScale));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(SingleChildScrollView), findsNothing);
          expect(find.bySemanticsLabel('Página 1 de 3'), findsNothing);
          expect(find.text('Soy cliente'), findsOneWidget);
          expect(find.text('Soy Yonke'), findsOneWidget);

          final clientRect = tester.getRect(find.text('Soy cliente'));
          final yonkeRect = tester.getRect(find.text('Soy Yonke'));
          expect(clientRect.top, greaterThanOrEqualTo(0));
          expect(yonkeRect.bottom, lessThanOrEqualTo(size.height));

          if (size.height >= size.width) {
            final buttonRect = tester.getRect(find.byType(InkWell).first);
            expect(
              (buttonRect.left - (size.width - buttonRect.right)).abs(),
              lessThan(0.1),
            );
          }
        },
      );
    }
  }

  test('builds endpoint paths without duplicating URL logic', () {
    expect(
      ApiEndpoints.requestCity('request-id', 42),
      '/api/SolicitudCiudades/request-id/ciudad/42',
    );
    expect(
      ApiEndpoints.paymentResult('session-id'),
      '/api/Pagos/resultado/session-id',
    );
  });

  test('parses the documented global response envelope', () {
    final result = ApiEnvelope<String>.fromJson({
      'success': true,
      'message': 'ok',
      'data': 'value',
      'statusCode': 200,
      'errors': null,
    }, (data) => data! as String);

    expect(result.success, isTrue);
    expect(result.data, 'value');
    expect(result.statusCode, 200);
  });

  testWidgets('requires a city before continuing with a request', (
    tester,
  ) async {
    final draft = RequestDraft();
    final router = GoRouter(
      initialLocation: '/city',
      routes: [
        GoRoute(
          path: '/city',
          builder: (_, _) => RequestCityPage(draft: draft),
        ),
        GoRoute(
          path: AppRoutes.clientRequestReview,
          builder: (_, _) => const Scaffold(body: Text('Revisión')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    final continueButton = find.widgetWithText(FilledButton, 'Continuar');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.tap(find.text('Nogales, Sonora'));
    await tester.pump();

    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(draft.cityId, 1);
    expect(draft.cityName, 'Nogales, Sonora');
    expect(find.text('Revisión'), findsOneWidget);
  });

  testWidgets('shows clearly marked test requests in mock mode', (
    tester,
  ) async {
    expect(AppConfig.enableMockAuth, isTrue);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MyRequestsPage())),
    );
    await tester.pump();

    expect(find.text('Mis solicitudes'), findsOneWidget);
    expect(find.textContaining('Solicitudes de prueba'), findsOneWidget);
    expect(find.text('Alternador\nNissan Sentra 2018'), findsOneWidget);
  }, skip: !AppConfig.enableMockAuth);
}

Widget _responsiveHarness(double textScale) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
    },
    home: const StartPage(),
  );
}
