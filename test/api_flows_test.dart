import 'package:app_yonke/app/router/app_router.dart';
import 'package:app_yonke/core/config/app_config.dart';
import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/features/quotes/presentation/quote_detail_page.dart';
import 'package:app_yonke/features/quotes/presentation/request_quotes_page.dart';
import 'package:app_yonke/features/requests/domain/request_draft.dart';
import 'package:app_yonke/features/requests/presentation/request_city_page.dart';
import 'package:app_yonke/features/search/data/parts_search_repository.dart';
import 'package:app_yonke/features/search/data/search_history_repository.dart';
import 'package:app_yonke/features/search/presentation/parts_search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Pruebas del cableado real de ciudad, búsqueda y cotizaciones.
///
/// Cada pantalla llega a la API a través de `apiClientProvider`, así que aquí
/// se sustituye únicamente el cliente HTTP por uno simulado que responde con
/// el sobre `ApiResponseGlobal` y los nombres de campo que la app interpreta.
/// Providers, clases `*Api`, parsers y widgets son el código de producción.
///
/// Si el servidor publica otros nombres, `tool/api_probe.dart` lo reporta al
/// ejecutarse contra la API real.
void main() {
  group('Ciudad de la solicitud (Utilerias)', () {
    testWidgets('carga estados y ciudades del catálogo y continúa con la '
        'ciudad elegida', (tester) async {
      final api = _FakeApiClient(_catalogRoutes());
      final draft = RequestDraft();
      final router = GoRouter(
        initialLocation: '/ciudad',
        routes: [
          GoRoute(
            path: '/ciudad',
            builder: (_, _) => RequestCityPage(draft: draft),
          ),
          GoRoute(
            path: AppRoutes.clientRequestReview,
            builder: (_, _) => const Scaffold(body: Text('Revisión')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.callsTo('/api/Utilerias/entidades'), hasLength(1));
      expect(api.callsTo('/api/Utilerias/entidad/26/ciudades'), hasLength(1));
      expect(
        find.text('Ciudades obtenidas del catálogo de la API.'),
        findsOneWidget,
      );
      expect(find.text('Nogales, Sonora'), findsOneWidget);
      expect(find.text('Hermosillo, Sonora'), findsOneWidget);

      final continueButton = find.widgetWithText(FilledButton, 'Continuar');
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
      await tester.tap(find.text('Nogales, Sonora'));
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(draft.cityId, 1);
      expect(draft.cityName, 'Nogales, Sonora');
      expect(find.text('Revisión'), findsOneWidget);
    });

    testWidgets('al cambiar de estado consulta las ciudades de ese estado', (
      tester,
    ) async {
      final api = _FakeApiClient(_catalogRoutes());
      await tester.pumpWidget(
        _app(api, home: RequestCityPage(draft: RequestDraft())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('request-state-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Baja California').last);
      await tester.pumpAndSettle();

      expect(api.callsTo('/api/Utilerias/entidad/2/ciudades'), hasLength(1));
      // Sin `entidade` en el registro, el nombre del estado sale del catálogo
      // de estados ya cargado.
      expect(find.text('Mexicali, Baja California'), findsOneWidget);
      expect(find.text('Nogales, Sonora'), findsNothing);
    });

    testWidgets('ofrece reintentar cuando el catálogo de estados falla', (
      tester,
    ) async {
      final api = _FakeApiClient(const {});
      await tester.pumpWidget(
        _app(api, home: RequestCityPage(draft: RequestDraft())),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudieron cargar los estados. Inténtalo nuevamente.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      // En modo demo la pantalla usa el catálogo local en lugar del error.
    }, skip: AppConfig.enableMockAuth);
  });

  // La búsqueda lee `AppConfig.enableMockAuth` dentro de la pantalla: con el
  // modo demo encendido usa marcas locales. Estas pruebas verifican la ruta
  // real, así que solo corren con el modo demo apagado.
  group('Búsqueda de refacciones (Utilerias marcas y modelos)', () {
    testWidgets('usa marcas y modelos de la API en los filtros y los lleva a '
        'la solicitud', (tester) async {
      final api = _FakeApiClient(_catalogRoutes());
      RequestDraft? draft;
      final router = GoRouter(
        initialLocation: '/buscar',
        routes: [
          GoRoute(path: '/buscar', builder: (_, _) => const PartsSearchPage()),
          GoRoute(
            path: AppRoutes.clientNewRequest,
            builder: (_, state) {
              draft = state.extra! as RequestDraft;
              return const Scaffold(body: Text('Nueva solicitud'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _searchApp(api, child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      expect(api.callsTo('/api/Utilerias/marcas'), hasLength(1));

      await tester.tap(find.byKey(const Key('open-search-filters')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<int>, 'Marca'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nissan').last);
      await tester.pumpAndSettle();
      expect(api.callsTo('/api/Utilerias/modelos').single.query, {
        'marcaId': 1,
      });

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<int>, 'Modelo'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sentra').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('apply-search-filters')));
      await tester.pumpAndSettle();
      expect(find.text('Filtros (2)'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('parts-search-field')),
        'Alternador',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // La API no publica un buscador de refacciones: la pantalla lo dice y
      // ofrece crear la solicitud con lo capturado.
      expect(find.text('Búsqueda pendiente de conexión'), findsOneWidget);
      await tester.ensureVisible(find.text('Crear solicitud'));
      await tester.tap(find.text('Crear solicitud'));
      await tester.pumpAndSettle();

      expect(find.text('Nueva solicitud'), findsOneWidget);
      expect(draft?.part, 'Alternador');
      expect(draft?.brandId, 1);
      expect(draft?.brandName, 'Nissan');
      expect(draft?.modelId, 7);
      expect(draft?.modelName, 'Sentra');
    }, skip: AppConfig.enableMockAuth);

    testWidgets('avisa cuando el catálogo de marcas no responde', (
      tester,
    ) async {
      final api = _FakeApiClient(const {});
      await tester.pumpWidget(
        _searchApp(api, child: const MaterialApp(home: PartsSearchPage())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-search-filters')));
      await tester.pumpAndSettle();

      expect(find.text('No se pudieron cargar las marcas.'), findsOneWidget);
    }, skip: AppConfig.enableMockAuth);
  });

  // Las pantallas de cotizaciones usan datos locales con el modo demo
  // encendido; la ruta real solo se ejercita con el modo demo apagado.
  group(
    'Cotizaciones del cliente (DashboardSuscriptores y CotizacionYonke)',
    () {
      testWidgets('lista solo las cotizaciones de la solicitud consultada', (
        tester,
      ) async {
        final api = _FakeApiClient(_quoteRoutes());
        await tester.pumpWidget(
          _app(api, home: const RequestQuotesPage(requestId: 'request-api')),
        );
        await tester.pumpAndSettle();

        expect(
          api.callsTo('/api/DashboardSuscriptores/mis-cotizaciones'),
          hasLength(1),
        );
        expect(find.text('1 cotización recibida'), findsOneWidget);
        expect(find.text('Yonke API'), findsOneWidget);
        expect(find.text('Yonke Otro'), findsNothing);
        expect(find.text(r'$1850.00'), findsOneWidget);
        expect(find.text('Cotizaciones de prueba.'), findsNothing);
      }, skip: AppConfig.enableMockAuth);

      testWidgets(
        'muestra el detalle real y permite elegir la cotización si no '
        'hay orden',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(800, 1600);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);

          final api = _FakeApiClient(_quoteRoutes());
          await tester.pumpWidget(
            _app(api, home: const QuoteDetailPage(quoteId: 'quote-api')),
          );
          await tester.pumpAndSettle();

          expect(api.callsTo('/api/CotizacionYonke/quote-api'), hasLength(1));
          expect(api.callsTo('/api/Orden/cotizacion/quote-api'), hasLength(1));
          expect(find.text('Yonke API'), findsOneWidget);
          expect(find.text(r'$1850.00'), findsOneWidget);
          expect(find.text('30 días'), findsOneWidget);
          expect(find.text('Cotización de prueba.'), findsNothing);

          // Sin orden previa (404 en Orden/cotizacion) se puede elegir la
          // cotización.
          final button = find.byKey(const Key('client-create-order'));
          expect(button, findsOneWidget);
          expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        },
        skip: AppConfig.enableMockAuth,
      );

      testWidgets('ofrece reintentar si la API de cotizaciones falla', (
        tester,
      ) async {
        final api = _FakeApiClient(const {});
        await tester.pumpWidget(
          _app(api, home: const RequestQuotesPage(requestId: 'request-api')),
        );
        await tester.pumpAndSettle();

        expect(find.text('No pudimos cargar las cotizaciones'), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
      }, skip: AppConfig.enableMockAuth);
    },
  );
}

// --- utilidades -------------------------------------------------------------

Widget _app(_FakeApiClient api, {required Widget home}) => ProviderScope(
  overrides: [apiClientProvider.overrideWithValue(api)],
  child: MaterialApp(home: home),
);

/// La búsqueda necesita además el repositorio real (sin buscador) y un
/// historial en memoria; se fijan aquí para no depender del valor de MOCK_AUTH.
Widget _searchApp(_FakeApiClient api, {required Widget child}) => ProviderScope(
  overrides: [
    apiClientProvider.overrideWithValue(api),
    partsSearchRepositoryProvider.overrideWithValue(
      const UnavailablePartsSearchRepository(),
    ),
    searchHistoryRepositoryProvider.overrideWithValue(
      MemorySearchHistoryRepository(),
    ),
  ],
  child: child,
);

typedef _Call = ({String method, String path, Map<String, dynamic>? query});

typedef _Handler = Object? Function(Map<String, dynamic>? query);

/// Cliente HTTP simulado. Responde según `'MÉTODO ruta'`; si el manejador
/// devuelve una [ApiException], la lanza, igual que haría `DioApiClient`.
class _FakeApiClient implements ApiClient {
  _FakeApiClient(this._routes);

  final Map<String, _Handler> _routes;
  final calls = <_Call>[];

  Iterable<_Call> callsTo(String path) =>
      calls.where((call) => call.path == path);

  Future<dynamic> _handle(
    String method,
    String path,
    Map<String, dynamic>? query,
  ) async {
    calls.add((method: method, path: path, query: query));
    final handler = _routes['$method $path'];
    if (handler == null) {
      throw ApiException(
        message: 'Sin respuesta simulada para $method $path',
        statusCode: 404,
      );
    }
    final result = handler(query);
    if (result is ApiException) throw result;
    return result;
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _handle('GET', path, queryParameters);

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _handle('POST', path, queryParameters);

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _handle('PUT', path, queryParameters);

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _handle('DELETE', path, queryParameters);

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) => _handle(method, path, queryParameters);
}

/// Sobre `ApiResponseGlobal` documentado en el OpenAPI.
Map<String, dynamic> _ok(Object? data) => {
  'success': true,
  'message': 'OK',
  'data': data,
  'statusCode': 200,
  'errors': null,
};

const _states = [
  {'id': 26, 'entidad': 'Sonora', 'activo': true},
  {'id': 2, 'entidad': 'Baja California', 'activo': true},
];

const _sonoraCities = [
  {'id': 1, 'ciudad': 'Nogales', 'entidadId': 26, 'entidade': 'Sonora'},
  {'id': 2, 'ciudad': 'Hermosillo', 'entidadId': 26, 'entidade': 'Sonora'},
];

const _bajaCities = [
  {'id': 5, 'ciudad': 'Mexicali', 'entidadId': 2},
];

const _brands = [
  {'id': 1, 'marca': 'Nissan', 'activo': true},
  {'id': 2, 'marca': 'Toyota', 'activo': true},
];

const _nissanModels = [
  {'id': 7, 'modelo': 'Sentra', 'marcaId': 1},
  {'id': 8, 'modelo': 'Versa', 'marcaId': 1},
];

Map<String, _Handler> _catalogRoutes() => {
  'GET /api/Utilerias/entidades': (_) => _ok(_states),
  'GET /api/Utilerias/entidad/26/ciudades': (_) => _ok(_sonoraCities),
  'GET /api/Utilerias/entidad/2/ciudades': (_) => _ok(_bajaCities),
  'GET /api/Utilerias/marcas': (_) => _ok(_brands),
  'GET /api/Utilerias/modelos': (query) =>
      query?['marcaId'] == 1 ? _ok(_nissanModels) : _ok(const []),
};

Map<String, dynamic> _quoteRecord({
  required String id,
  required String requestId,
  required String yonkeName,
  required double price,
}) => {
  'guidId': id,
  'fechaCreacion': '2026-09-01T10:00:00Z',
  'precio': price,
  'disponible': true,
  'esNueva': false,
  'tieneGarantia': true,
  'diasGarantia': 30,
  'envioDisponible': true,
  'costoEnvio': 120.0,
  'tiempoEntregaDias': 2,
  'comentarios': 'Pieza probada.',
  'activo': true,
  'solicitudCotizacionEstatus': {'descripcion': 'Enviada'},
  'solicitudYonkes': {
    'guidId': 'assignment-$id',
    'solicitudGuidId': requestId,
    'yonkeGuidId': 'yonke-$id',
    'yonkes': {'nombre': yonkeName, 'telefono': '+526311234567'},
  },
  'solicitudCotizacionesImagenes': const <Map<String, dynamic>>[],
};

Map<String, _Handler> _quoteRoutes() => {
  'GET /api/DashboardSuscriptores/mis-cotizaciones': (_) => _ok([
    _quoteRecord(
      id: 'quote-api',
      requestId: 'request-api',
      yonkeName: 'Yonke API',
      price: 1850,
    ),
    _quoteRecord(
      id: 'quote-other',
      requestId: 'request-other',
      yonkeName: 'Yonke Otro',
      price: 900,
    ),
  ]),
  'GET /api/CotizacionYonke/quote-api': (_) => _ok(
    _quoteRecord(
      id: 'quote-api',
      requestId: 'request-api',
      yonkeName: 'Yonke API',
      price: 1850,
    ),
  ),
  // Sin orden previa para esta cotización.
  'GET /api/Orden/cotizacion/quote-api': (_) =>
      const ApiException(message: 'Sin orden', statusCode: 404),
  'GET /api/YonkesCalificaciones/yonke-quote-api': (_) => _ok(const []),
};
