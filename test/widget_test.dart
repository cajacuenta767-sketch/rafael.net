import 'dart:async';

import 'package:app_yonke/app/app.dart';
import 'package:app_yonke/app/router/app_router.dart';
import 'package:app_yonke/core/config/app_config.dart';
import 'package:app_yonke/core/network/api_endpoints.dart';
import 'package:app_yonke/core/network/api_envelope.dart';
import 'package:app_yonke/features/auth/presentation/client_login_page.dart';
import 'package:app_yonke/features/auth/presentation/yonke_login_page.dart';
import 'package:app_yonke/features/auth/domain/yonke_auth_repository.dart';
import 'package:app_yonke/features/home/presentation/role_home_page.dart';
import 'package:app_yonke/features/home/presentation/start_page.dart';
import 'package:app_yonke/features/quotes/domain/client_quote.dart';
import 'package:app_yonke/features/quotes/presentation/quote_detail_page.dart';
import 'package:app_yonke/features/quotes/presentation/request_quotes_page.dart';
import 'package:app_yonke/features/requests/domain/request_draft.dart';
import 'package:app_yonke/features/requests/presentation/request_city_page.dart';
import 'package:app_yonke/features/requests/presentation/my_requests_page.dart';
import 'package:app_yonke/features/requests/presentation/request_detail_page.dart';
import 'package:app_yonke/features/search/data/parts_search_repository.dart';
import 'package:app_yonke/features/search/data/search_history_repository.dart';
import 'package:app_yonke/features/search/domain/part_search.dart';
import 'package:app_yonke/features/search/presentation/parts_search_page.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_requests_repository.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_request_detail_repository.dart';
import 'package:app_yonke/features/yonke_requests/domain/yonke_request_detail.dart';
import 'package:app_yonke/features/yonke_requests/domain/yonke_request_summary.dart';
import 'package:app_yonke/features/yonke_requests/presentation/yonke_quote_page.dart';
import 'package:app_yonke/features/yonke_requests/presentation/yonke_request_detail_page.dart';
import 'package:app_yonke/features/yonke_requests/presentation/yonke_requests_page.dart';
import 'package:app_yonke/features/yonke_quotes/data/yonke_quotes_repository.dart';
import 'package:app_yonke/features/yonke_quotes/domain/yonke_quote.dart';
import 'package:app_yonke/features/yonke_quotes/presentation/yonke_quote_detail_page.dart';
import 'package:app_yonke/features/yonke_quotes/presentation/yonke_quotes_page.dart';
import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_exception.dart';
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

  testWidgets('opens the yonke login from the yonke role button', (
    tester,
  ) async {
    appRouter.go(AppRoutes.start);
    await tester.pumpWidget(const ProviderScope(child: YonkeApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Soy Yonke'));
    await tester.pumpAndSettle();

    expect(find.text('Ingreso para yonkes'), findsOneWidget);
    expect(find.byKey(const Key('yonke-email-field')), findsOneWidget);
    expect(find.byKey(const Key('yonke-password-field')), findsOneWidget);
    appRouter.go(AppRoutes.start);
  });

  testWidgets('validates yonke email and password without sending', (
    tester,
  ) async {
    final repository = _PendingYonkeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [yonkeAuthRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: YonkeLoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('yonke-login-button'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('yonke-email-field')),
      'correo-invalido',
    );
    await tester.enterText(
      find.byKey(const Key('yonke-password-field')),
      'clave',
    );
    await tester.tap(button);
    await tester.pump();

    expect(find.text('Ingresa un correo electrónico válido.'), findsOneWidget);
    expect(repository.calls, 0);
  });

  testWidgets('shows and hides the yonke password', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          yonkeAuthRepositoryProvider.overrideWithValue(
            _PendingYonkeAuthRepository(),
          ),
        ],
        child: const MaterialApp(home: YonkeLoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    EditableText passwordField() => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('yonke-password-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
  });

  testWidgets('does not invent a yonke session from an undocumented response', (
    tester,
  ) async {
    final repository = _PendingYonkeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [yonkeAuthRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: YonkeLoginPage()),
      ),
    );
    await tester.pumpAndSettle();
    await _fillYonkeLogin(tester);
    await tester.tap(find.byKey(const Key('yonke-login-button')));
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(find.textContaining('contrato de sesión del yonke'), findsOneWidget);
    expect(find.text('Ingreso para yonkes'), findsOneWidget);
  });

  testWidgets('prevents duplicate yonke login requests while loading', (
    tester,
  ) async {
    final repository = _BlockingYonkeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [yonkeAuthRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: YonkeLoginPage()),
      ),
    );
    await tester.pumpAndSettle();
    await _fillYonkeLogin(tester);
    await tester.tap(find.byKey(const Key('yonke-login-button')));
    await tester.pump();

    expect(find.text('Iniciando sesión...'), findsOneWidget);
    expect(repository.calls, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('yonke-login-button')))
          .onPressed,
      isNull,
    );
    repository.complete();
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
  });

  testWidgets('shows a generic message for invalid yonke credentials', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          yonkeAuthRepositoryProvider.overrideWithValue(
            const _FailingYonkeAuthRepository(
              ApiException(message: 'user not found', statusCode: 401),
            ),
          ),
        ],
        child: const MaterialApp(home: YonkeLoginPage()),
      ),
    );
    await tester.pumpAndSettle();
    await _fillYonkeLogin(tester);
    await tester.tap(find.byKey(const Key('yonke-login-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos iniciar sesión. Revisa tus credenciales.'),
      findsOneWidget,
    );
    expect(find.textContaining('user not found'), findsNothing);
  });

  testWidgets('debug yonke access opens only a marked test session', (
    tester,
  ) async {
    expect(AppConfig.enableMockAuth, isTrue);
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const YonkeLoginPage()),
        GoRoute(
          path: AppRoutes.yonkeHome,
          builder: (_, state) => Scaffold(
            body: Text(state.extra == true ? 'Sesión demo' : 'Sesión real'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          yonkeAuthRepositoryProvider.overrideWithValue(
            _PendingYonkeAuthRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yonke-demo-login-button')));
    await tester.pumpAndSettle();

    expect(find.text('Sesión demo'), findsOneWidget);
  }, skip: !AppConfig.enableMockAuth);

  testWidgets('the real app route opens the marked yonke demo inbox', (
    tester,
  ) async {
    expect(AppConfig.enableMockAuth, isTrue);
    appRouter.go(AppRoutes.start);
    await tester.pumpWidget(const ProviderScope(child: YonkeApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soy Yonke'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yonke-demo-login-button')));
    await tester.pumpAndSettle();

    expect(find.text('Solicitudes recibidas'), findsOneWidget);
    expect(find.textContaining('Solicitudes de prueba'), findsOneWidget);
    appRouter.go(AppRoutes.start);
  }, skip: !AppConfig.enableMockAuth);

  testWidgets('shows the yonke demo inbox with calculated summaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: YonkeRequestsPage(
            isDemoSession: true,
            repository: DemoYonkeRequestsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Solicitudes recibidas'), findsOneWidget);
    expect(find.textContaining('Solicitudes de prueba'), findsOneWidget);
    expect(find.text('3 solicitudes'), findsOneWidget);
    expect(find.text('Alternador'), findsOneWidget);
  });

  testWidgets('searches yonke requests by part, vehicle or folio', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: YonkeRequestsPage(
            isDemoSession: true,
            repository: DemoYonkeRequestsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('yonke-requests-search')),
      'DEMO-002',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('1 solicitudes'), findsOneWidget);
    expect(find.text('Faro delantero'), findsOneWidget);
    expect(find.text('Alternador'), findsNothing);
  });

  testWidgets('shows a no-results state for unmatched yonke searches', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: YonkeRequestsPage(
            isDemoSession: true,
            repository: DemoYonkeRequestsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('yonke-requests-search')),
      'pieza inexistente',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(
      find.text('No encontramos solicitudes con esos filtros'),
      findsOneWidget,
    );
    expect(find.text('Limpiar búsqueda y filtros'), findsOneWidget);
  });

  testWidgets('filters yonke requests by status', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: YonkeRequestsPage(
            isDemoSession: true,
            repository: DemoYonkeRequestsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yonke-open-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yonke-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yonke-apply-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Filtros (1)'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('1 solicitudes'), findsOneWidget);
    expect(find.text('Alternador'), findsOneWidget);
    expect(find.text('Faro delantero'), findsNothing);
  });

  testWidgets('shows the pending endpoint state outside demo mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: YonkeRequestsPage(
            isDemoSession: false,
            repository: UnavailableYonkeRequestsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bandeja pendiente de conexión'), findsOneWidget);
    expect(find.textContaining('Solicitudes de prueba'), findsNothing);
  });

  testWidgets('shows an empty assigned requests state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: YonkeRequestsPage(
            isDemoSession: false,
            repository: _EmptyYonkeRequestsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Todavía no tienes solicitudes asignadas'),
      findsOneWidget,
    );
  });

  testWidgets('shows an error and retry action for a failed yonke inbox', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: YonkeRequestsPage(
            isDemoSession: false,
            repository: _ErrorYonkeRequestsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pudimos cargar las solicitudes'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('marks a yonke request as viewed before opening its detail', (
    tester,
  ) async {
    final repository = _TrackingYonkeRequestsRepository();
    final router = GoRouter(
      initialLocation: '/inbox',
      routes: [
        GoRoute(
          path: '/inbox',
          builder: (_, _) =>
              YonkeRequestsPage(isDemoSession: false, repository: repository),
        ),
        GoRoute(
          path: '/yonke/solicitudes/:id',
          builder: (_, state) {
            final request = state.extra! as YonkeRequestSummary;
            return Scaffold(body: Text('Detalle ${request.status.label}'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcha de prueba'));
    await tester.pumpAndSettle();

    expect(repository.markedIds, ['assignment-test']);
    expect(find.text('Detalle Vista'), findsOneWidget);
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
        'yonke login is responsive at ${size.width}x${size.height} and $textScale text',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                yonkeAuthRepositoryProvider.overrideWithValue(
                  _PendingYonkeAuthRepository(),
                ),
              ],
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: const YonkeLoginPage(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Ingreso para yonkes'), findsOneWidget);
          expect(find.byKey(const Key('yonke-login-button')), findsOneWidget);
        },
      );
    }
  }

  for (final size in [...portraitSizes, ...landscapeSizes]) {
    for (final textScale in textScales) {
      testWidgets(
        'yonke inbox is responsive at ${size.width}x${size.height} and $textScale text',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: const YonkeRequestsPage(
                    isDemoSession: true,
                    repository: DemoYonkeRequestsRepository(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Solicitudes recibidas'), findsOneWidget);
          expect(find.textContaining('Solicitudes de prueba'), findsOneWidget);
        },
      );
    }
  }

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
          builder: (_, _) =>
              RequestCityPage(draft: draft, useTestCatalogs: true),
        ),
        GoRoute(
          path: AppRoutes.clientRequestReview,
          builder: (_, _) => const Scaffold(body: Text('Revisión')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

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

  testWidgets('searches demo parts and marks them as demonstration data', (
    tester,
  ) async {
    final history = MemorySearchHistoryRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [searchHistoryRepositoryProvider.overrideWithValue(history)],
        child: const MaterialApp(home: PartsSearchPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('parts-search-field')),
      'Alternador',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('1 resultados'), findsOneWidget);
    expect(find.text('Alternador'), findsNWidgets(2));
    expect(find.textContaining('Datos de demostración'), findsOneWidget);
    expect(history.entries.single.query, 'Alternador');
  });

  testWidgets('requires a part name before searching', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchHistoryRepositoryProvider.overrideWithValue(
            MemorySearchHistoryRepository(),
          ),
        ],
        child: const MaterialApp(home: PartsSearchPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pump();

    expect(find.text('Escribe el nombre de una refacción.'), findsOneWidget);
  });

  testWidgets('applies a category filter to the part search', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchHistoryRepositoryProvider.overrideWithValue(
            MemorySearchHistoryRepository(),
          ),
        ],
        child: const MaterialApp(home: PartsSearchPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-search-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-search-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eléctrico').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply-search-filters')));
    await tester.pumpAndSettle();

    expect(find.text('Filtros (1)'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Eléctrico'), findsOneWidget);
  });

  testWidgets('shows and removes a recent search', (tester) async {
    final history = MemorySearchHistoryRepository([
      const SearchHistoryEntry(query: 'Radiador', filters: PartSearchFilters()),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [searchHistoryRepositoryProvider.overrideWithValue(history)],
        child: const MaterialApp(home: PartsSearchPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Búsquedas recientes'), findsOneWidget);
    expect(find.text('Radiador'), findsOneWidget);
    await tester.tap(find.byTooltip('Eliminar Radiador'));
    await tester.pumpAndSettle();

    expect(find.text('Radiador'), findsNothing);
    expect(history.entries, isEmpty);
  });

  testWidgets('offers a manual request when no part matches', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchHistoryRepositoryProvider.overrideWithValue(
            MemorySearchHistoryRepository(),
          ),
        ],
        child: const MaterialApp(home: PartsSearchPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('parts-search-field')),
      'Pieza inexistente',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(
      find.text('No encontramos refacciones con esos datos'),
      findsOneWidget,
    );
    expect(find.text('Crear solicitud'), findsOneWidget);
  });

  testWidgets('opens a prefilled new request from a search result', (
    tester,
  ) async {
    RequestDraft? receivedDraft;
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(path: '/search', builder: (_, _) => const PartsSearchPage()),
        GoRoute(
          path: AppRoutes.clientNewRequest,
          builder: (_, state) {
            receivedDraft = state.extra! as RequestDraft;
            return const Scaffold(body: Text('Solicitud precargada'));
          },
        ),
        GoRoute(
          path: AppRoutes.clientHome,
          builder: (_, _) => const Scaffold(body: Text('Inicio')),
        ),
        GoRoute(
          path: AppRoutes.clientSearch,
          builder: (_, _) => const PartsSearchPage(),
        ),
        GoRoute(
          path: AppRoutes.clientRequests,
          builder: (_, _) => const Scaffold(body: Text('Solicitudes')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchHistoryRepositoryProvider.overrideWithValue(
            MemorySearchHistoryRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('parts-search-field')),
      'Alternador',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solicitar cotización'));
    await tester.pumpAndSettle();

    expect(find.text('Solicitud precargada'), findsOneWidget);
    expect(receivedDraft?.part, 'Alternador');
    expect(receivedDraft?.brandName, 'Nissan');
    expect(receivedDraft?.modelName, 'Sentra');
    expect(receivedDraft?.year, 2018);
  });

  testWidgets('shows retry state when search fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          partsSearchRepositoryProvider.overrideWithValue(
            const _FailingPartsSearchRepository(),
          ),
          searchHistoryRepositoryProvider.overrideWithValue(
            MemorySearchHistoryRepository(),
          ),
        ],
        child: const MaterialApp(home: PartsSearchPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('parts-search-field')),
      'Radiador',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('No pudimos realizar la búsqueda'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  const searchSizes = <Size>[
    Size(320, 640),
    Size(360, 720),
    Size(390, 844),
    Size(412, 915),
    Size(600, 960),
    Size(800, 360),
  ];
  for (final size in searchSizes) {
    for (final textScale in textScales) {
      testWidgets(
        'search is responsive at ${size.width}x${size.height} and $textScale text',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                searchHistoryRepositoryProvider.overrideWithValue(
                  MemorySearchHistoryRepository(),
                ),
              ],
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: const PartsSearchPage(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Buscar refacción'), findsOneWidget);
          expect(find.text('Buscar'), findsOneWidget);
        },
      );
    }
  }

  testWidgets('shows a request detail in mock mode', (tester) async {
    expect(AppConfig.enableMockAuth, isTrue);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RequestDetailPage(requestId: 'mock-request-alternador'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Detalle de solicitud'), findsOneWidget);
    expect(find.textContaining('Detalle de prueba'), findsOneWidget);
    expect(find.text('Alternador'), findsOneWidget);
    expect(find.text('Nogales, Sonora'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('3 cotizaciones'), findsOneWidget);
  }, skip: !AppConfig.enableMockAuth);

  testWidgets('shows and compares mock quotes for a request', (tester) async {
    expect(AppConfig.enableMockAuth, isTrue);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RequestQuotesPage(
            requestId: 'mock-request-alternador',
            requestTitle: 'Alternador Nissan Sentra 2018',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cotizaciones recibidas'), findsOneWidget);
    expect(find.text('Cotizaciones de prueba.'), findsOneWidget);
    expect(find.text('3 cotizaciones recibidas'), findsOneWidget);
    expect(find.text('Mejor precio'), findsOneWidget);
    expect(find.text('\$1700.00'), findsOneWidget);
  }, skip: !AppConfig.enableMockAuth);

  testWidgets('shows a mock quote detail without active contact', (
    tester,
  ) async {
    expect(AppConfig.enableMockAuth, isTrue);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: QuoteDetailPage(quoteId: 'mock-quote-norte')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detalle de cotización'), findsOneWidget);
    expect(find.text('Cotización de prueba.'), findsOneWidget);
    expect(find.text('Yonke de prueba Norte'), findsOneWidget);
    expect(find.text('\$1700.00'), findsOneWidget);
    final whatsapp = find.widgetWithText(
      FilledButton,
      'Contactar por WhatsApp',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(whatsapp).onPressed, isNull);
  }, skip: !AppConfig.enableMockAuth);

  testWidgets('shows order tracking instead of creating a duplicate order', (
    tester,
  ) async {
    expect(AppConfig.enableMockAuth, isTrue);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: QuoteDetailPage(quoteId: 'mock-quote-faro')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('client-open-order-tracking')), findsOneWidget);
    expect(find.byKey(const Key('client-create-order')), findsNothing);
  }, skip: !AppConfig.enableMockAuth);

  test('parses the documented quote response fields', () {
    final quote = clientQuoteFromResponse({
      'success': true,
      'data': {
        'guidId': 'quote-id',
        'precio': 1850.0,
        'disponible': true,
        'esNueva': false,
        'tieneGarantia': true,
        'diasGarantia': 30,
        'envioDisponible': true,
        'costoEnvio': 100.0,
        'activo': true,
        'solicitudCotizacionEstatus': {'descripcion': 'Enviada'},
        'solicitudYonkes': {
          'solicitudGuidId': 'request-id',
          'yonkeGuidId': 'yonke-id',
          'yonkes': {'nombre': 'Yonke API', 'telefono': '+526311234567'},
        },
        'solicitudCotizacionesImagenes': [
          {'urlImagen': 'https://example.com/photo.jpg'},
        ],
      },
    });

    expect(quote, isNotNull);
    expect(quote!.requestId, 'request-id');
    expect(quote.yonkeName, 'Yonke API');
    expect(quote.price, 1850);
    expect(quote.warranty, '30 días');
    expect(quote.imageUrls, ['https://example.com/photo.jpg']);
  });

  test('parses the documented yonke request detail and safe images', () {
    final summary = demoYonkeRequests.first;
    final detail = yonkeRequestDetailFromResponses(
      requestResponse: {
        'success': true,
        'data': {
          'guidId': 'request-api',
          'fechaCreacion': '2026-08-31T09:20:00Z',
          'marcaId': 4,
          'marca': 'Nissan',
          'modelo': 'Sentra',
          'año': 2018,
          'motor': '2.0 L',
          'transmicion': 'Automática',
          'piezaBuscada': 'Alternador',
          'numeroParte': 'ABC-123',
          'descripcion': 'Pieza completa',
          'folio': 'RF-100',
          'cerrada': false,
        },
      },
      imagesResponse: {
        'data': [
          {'urlImagen': 'https://example.com/request.jpg'},
          {'urlImagen': 'http://insecure.example.com/request.jpg'},
        ],
      },
      requestYonkeId: 'assignment-api',
      summary: summary,
    );

    expect(detail, isNotNull);
    expect(detail!.requestId, 'request-api');
    expect(detail.brandId, 4);
    expect(detail.city, summary.city);
    expect(detail.imageUrls, ['https://example.com/request.jpg']);
  });

  testWidgets('shows a complete demo request detail for the yonke', (
    tester,
  ) async {
    final summary = demoYonkeRequests.first;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: YonkeRequestDetailPage(
            requestYonkeId: summary.requestYonkeId,
            request: summary,
            repository: const DemoYonkeRequestDetailRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detalle de solicitud'), findsOneWidget);
    expect(find.text('Alternador'), findsOneWidget);
    expect(find.text('Información de la pieza'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Fotografías (4)'), findsOneWidget);
    expect(find.byKey(const Key('yonke-unavailable-button')), findsOneWidget);
    expect(find.byKey(const Key('yonke-quote-button')), findsOneWidget);
  });

  testWidgets('confirms and records an unavailable yonke response', (
    tester,
  ) async {
    final repository = _TrackingYonkeRequestDetailRepository();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: YonkeRequestDetailPage(
            requestYonkeId: repository.detail.requestYonkeId,
            request: _summaryForDetail(repository.detail),
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yonke-unavailable-button')));
    await tester.pumpAndSettle();
    expect(find.text('¿Marcar como no disponible?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-unavailable-button')));
    await tester.pumpAndSettle();

    expect(repository.unavailableIds, ['assignment-test-detail']);
    expect(find.text('No disponible'), findsOneWidget);
    expect(find.byKey(const Key('yonke-quote-button')), findsNothing);
  });

  testWidgets('validates and submits every confirmed quote field', (
    tester,
  ) async {
    final repository = _TrackingYonkeRequestDetailRepository();
    final router = GoRouter(
      initialLocation: '/quote',
      routes: [
        GoRoute(
          path: '/quote',
          builder: (_, _) => YonkeQuotePage(
            requestYonkeId: repository.detail.requestYonkeId,
            detail: repository.detail,
            repository: repository,
          ),
        ),
        GoRoute(
          path: AppRoutes.yonkeHome,
          builder: (_, _) => const Scaffold(body: Text('Bandeja yonke')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('submit-quote-button')),
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.tap(find.byKey(const Key('submit-quote-button')));
    await tester.pump();
    expect(find.text('Ingresa un precio mayor a cero.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('quote-price-field')),
      '1850.50',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('submit-quote-button')),
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.tap(find.byKey(const Key('submit-quote-button')));
    await tester.pumpAndSettle();

    expect(repository.submissions, hasLength(1));
    expect(repository.submissions.single.price, 1850.50);
    expect(repository.submissions.single.hasWarranty, isTrue);
    expect(repository.submissions.single.warrantyDays, 30);
    expect(find.text('Cotización enviada'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quote-success-button')));
    await tester.pumpAndSettle();
    expect(find.text('Bandeja yonke'), findsOneWidget);
  });

  for (final size in const [Size(320, 640), Size(390, 844), Size(800, 360)]) {
    testWidgets(
      'yonke request detail is responsive at ${size.width}x${size.height}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final summary = demoYonkeRequests.first;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: YonkeRequestDetailPage(
                  requestYonkeId: summary.requestYonkeId,
                  request: summary,
                  repository: const DemoYonkeRequestDetailRepository(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Detalle de solicitud'), findsOneWidget);
        expect(find.byKey(const Key('yonke-quote-button')), findsOneWidget);
      },
    );
  }

  test('parses a documented yonke quote nested in a dashboard list', () {
    final result = yonkeQuotesPageFromResponse({
      'success': true,
      'data': [
        {
          'guidId': 'quote-api',
          'fechaCreacion': '2026-08-31T11:25:00Z',
          'solicitudYonkeGuidId': 'assignment-api',
          'precio': 1850.0,
          'disponible': true,
          'esNueva': false,
          'tieneGarantia': true,
          'diasGarantia': 30,
          'envioDisponible': true,
          'costoEnvio': 120.0,
          'activo': true,
          'solicitudCotizacionEstatus': {'descripcion': 'Vista'},
          'solicitudYonkes': {
            'guidId': 'assignment-api',
            'solicitudGuidId': 'request-api',
            'solicitudes': {
              'piezaBuscada': 'Alternador',
              'año': 2018,
              'folio': 'RF-100',
              'marcas': {'nombre': 'Nissan'},
              'modelos': {'nombre': 'Sentra'},
            },
          },
          'solicitudCotizacionesImagenes': [
            {'urlImagen': 'https://example.com/quote.jpg'},
            {'urlImagen': 'http://insecure.example.com/quote.jpg'},
          ],
        },
      ],
    });

    expect(result, isNotNull);
    expect(result!.items, hasLength(1));
    expect(result.items.single.part, 'Alternador');
    expect(result.items.single.vehicle, 'Nissan · Sentra · 2018');
    expect(result.items.single.status, YonkeQuoteStatus.viewed);
    expect(result.items.single.imageUrls, ['https://example.com/quote.jpg']);
  });

  testWidgets('shows the yonke demo sent quotes inbox', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: YonkeQuotesPage(
            isDemoSession: true,
            repository: DemoYonkeQuotesRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cotizaciones enviadas'), findsOneWidget);
    expect(find.textContaining('Cotizaciones de prueba'), findsOneWidget);
    expect(find.text('Alternador'), findsOneWidget);
    expect(find.text('3'), findsAtLeastNWidgets(1));
  });

  testWidgets('searches yonke quotes by folio and vehicle', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: YonkeQuotesPage(
            isDemoSession: true,
            repository: DemoYonkeQuotesRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('yonke-quotes-search')),
      'DEMO-003',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Transmisión automática'), findsOneWidget);
    expect(find.text('Alternador'), findsNothing);
  });

  testWidgets('filters yonke quotes by accepted status', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: YonkeQuotesPage(
            isDemoSession: true,
            repository: DemoYonkeQuotesRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-yonke-quote-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yonke-quote-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptada').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply-yonke-quote-filters')));
    await tester.pumpAndSettle();

    expect(find.text('Transmisión automática'), findsOneWidget);
    expect(find.text('Alternador'), findsNothing);
  });

  testWidgets('shows a safe yonke quote detail with editing blocked', (
    tester,
  ) async {
    final quote = demoYonkeQuotes.first;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: YonkeQuoteDetailPage(
            quoteId: quote.id,
            isDemoSession: true,
            initialQuote: quote,
            repository: const DemoYonkeQuotesRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detalle de cotización'), findsOneWidget);
    expect(find.text('Alternador'), findsOneWidget);
    expect(find.text('\$1850.00 MXN'), findsOneWidget);
    final edit = find.widgetWithText(FilledButton, 'Modificar cotización');
    await tester.dragUntilVisible(
      edit,
      find.byType(ListView),
      const Offset(0, -500),
    );
    expect(edit, findsOneWidget);
    expect(tester.widget<FilledButton>(edit).onPressed, isNull);
    expect(find.textContaining('aún no define'), findsOneWidget);
  });

  testWidgets('shows pending contract instead of inventing quote records', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: YonkeQuotesPage(
            isDemoSession: false,
            repository: _PendingYonkeQuotesRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Contrato de lista pendiente'), findsOneWidget);
    expect(find.textContaining('datos inventados'), findsOneWidget);
  });

  for (final size in const [Size(320, 640), Size(390, 844), Size(800, 360)]) {
    testWidgets(
      'yonke quotes inbox is responsive at ${size.width}x${size.height}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: YonkeQuotesPage(
                  isDemoSession: true,
                  repository: DemoYonkeQuotesRepository(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Cotizaciones enviadas'), findsOneWidget);
        expect(find.textContaining('Cotizaciones de prueba'), findsOneWidget);
      },
    );
  }
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

class _FailingPartsSearchRepository implements PartsSearchRepository {
  const _FailingPartsSearchRepository();

  @override
  bool get usesDemoData => false;

  @override
  Future<List<PartSearchResult>> search(
    String query,
    PartSearchFilters filters,
  ) => Future.error(StateError('test error'));
}

Future<void> _fillYonkeLogin(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('yonke-email-field')),
    'yonke@ejemplo.com',
  );
  await tester.enterText(
    find.byKey(const Key('yonke-password-field')),
    'clave-segura',
  );
  await tester.pump();
}

class _PendingYonkeAuthRepository implements YonkeAuthRepository {
  int calls = 0;

  @override
  Future<YonkeLoginResult> login({
    required String email,
    required String password,
  }) async {
    calls++;
    return const YonkeLoginResult(sessionContractPending: true);
  }
}

class _BlockingYonkeAuthRepository implements YonkeAuthRepository {
  final _completer = Completer<YonkeLoginResult>();
  int calls = 0;

  @override
  Future<YonkeLoginResult> login({
    required String email,
    required String password,
  }) {
    calls++;
    return _completer.future;
  }

  void complete() {
    _completer.complete(const YonkeLoginResult(sessionContractPending: true));
  }
}

class _FailingYonkeAuthRepository implements YonkeAuthRepository {
  const _FailingYonkeAuthRepository(this.error);

  final Object error;

  @override
  Future<YonkeLoginResult> login({
    required String email,
    required String password,
  }) => Future.error(error);
}

class _EmptyYonkeRequestsRepository implements YonkeRequestsRepository {
  const _EmptyYonkeRequestsRepository();

  @override
  bool get usesDemoData => false;

  @override
  Future<YonkeRequestsPageResult> getAssignedRequests({
    required int page,
    required int pageSize,
    String? search,
    YonkeRequestFilters filters = const YonkeRequestFilters(),
  }) async => const YonkeRequestsPageResult(items: [], page: 1, hasMore: false);

  @override
  Future<void> markAsViewed(String requestYonkeId) async {}
}

class _TrackingYonkeRequestsRepository implements YonkeRequestsRepository {
  final markedIds = <String>[];

  @override
  bool get usesDemoData => false;

  @override
  Future<YonkeRequestsPageResult> getAssignedRequests({
    required int page,
    required int pageSize,
    String? search,
    YonkeRequestFilters filters = const YonkeRequestFilters(),
  }) async => YonkeRequestsPageResult(
    items: [
      YonkeRequestSummary(
        requestId: 'request-test',
        requestYonkeId: 'assignment-test',
        part: 'Marcha de prueba',
        status: YonkeRequestStatus.newRequest,
        receivedAt: DateTime(2026, 8, 31),
        isDemo: false,
      ),
    ],
    page: 1,
    hasMore: false,
  );

  @override
  Future<void> markAsViewed(String requestYonkeId) async {
    markedIds.add(requestYonkeId);
  }
}

class _ErrorYonkeRequestsRepository implements YonkeRequestsRepository {
  const _ErrorYonkeRequestsRepository();

  @override
  bool get usesDemoData => false;

  @override
  Future<YonkeRequestsPageResult> getAssignedRequests({
    required int page,
    required int pageSize,
    String? search,
    YonkeRequestFilters filters = const YonkeRequestFilters(),
  }) => Future.error(StateError('test error'));

  @override
  Future<void> markAsViewed(String requestYonkeId) async {}
}

class _TrackingYonkeRequestDetailRepository
    implements YonkeRequestDetailRepository {
  final unavailableIds = <String>[];
  final submissions = <YonkeQuoteSubmission>[];

  final detail = YonkeRequestDetail(
    requestId: 'request-test-detail',
    requestYonkeId: 'assignment-test-detail',
    part: 'Alternador de prueba',
    status: YonkeRequestStatus.viewed,
    imageUrls: const [],
    isDemo: false,
    brandId: 4,
    brand: 'Nissan',
    model: 'Sentra',
    year: 2018,
    city: 'Nogales, Sonora',
    receivedAt: DateTime(2026, 8, 31),
  );

  @override
  bool get usesDemoData => false;

  @override
  Future<YonkeRequestDetail> getDetail({
    required String requestId,
    required String requestYonkeId,
    YonkeRequestSummary? summary,
  }) async => detail;

  @override
  Future<void> markUnavailable(String requestYonkeId) async {
    unavailableIds.add(requestYonkeId);
  }

  @override
  Future<void> submitQuote(
    String requestYonkeId,
    YonkeQuoteSubmission submission,
  ) async {
    submissions.add(submission);
  }
}

YonkeRequestSummary _summaryForDetail(YonkeRequestDetail detail) =>
    YonkeRequestSummary(
      requestId: detail.requestId,
      requestYonkeId: detail.requestYonkeId,
      part: detail.part,
      status: detail.status,
      receivedAt: detail.receivedAt ?? DateTime(2026, 8, 31),
      isDemo: detail.isDemo,
      brand: detail.brand,
      model: detail.model,
      year: detail.year,
      city: detail.city,
    );

class _PendingYonkeQuotesRepository implements YonkeQuotesRepository {
  const _PendingYonkeQuotesRepository();

  @override
  bool get usesDemoData => false;

  @override
  Future<YonkeQuotesPageResult> getMyQuotes({
    required int page,
    required int pageSize,
    String? search,
    YonkeQuoteFilters filters = const YonkeQuoteFilters(),
  }) => Future.error(const YonkeQuotesContractPendingException());

  @override
  Future<YonkeQuote> getById(String quoteId) =>
      Future.error(const YonkeQuoteNotFoundException());
}
