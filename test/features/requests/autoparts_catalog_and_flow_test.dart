import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/features/requests/domain/autoparts_catalog.dart';
import 'package:app_yonke/features/requests/domain/request_draft.dart';
import 'package:app_yonke/features/requests/presentation/new_request_page.dart';
import 'package:app_yonke/features/requests/presentation/request_review_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Autoparts Catalog & Search Utilities', () {
    test('normalizeText remueve diacríticos y normaliza a minúsculas', () {
      expect(normalizeText('Transmisión'), 'transmision');
      expect(normalizeText('Cigüeñal'), 'ciguenal');
      expect(normalizeText('Árbol de levas'), 'arbol de levas');
      expect(normalizeText('  Faro Delantero  '), 'faro delantero');
    });

    test('searchAutoparts encuentra piezas por nombre directo y sin acentos', () {
      final results = searchAutoparts('transmision');
      final transmision = results.firstWhere((item) => item.name.contains('Transmisión'));
      expect(transmision.category, 'Transmisión');
    });

    test('searchAutoparts encuentra piezas por alias populares de yonke', () {
      final capot = searchAutoparts('capo');
      expect(capot.any((item) => item.name == 'Cofre'), isTrue);

      final starter = searchAutoparts('starter');
      expect(starter.any((item) => item.name == 'Marcha'), isTrue);

      final optica = searchAutoparts('optica');
      expect(optica.any((item) => item.name == 'Faro delantero'), isTrue);
    });

    test('las piezas aplicables definen hasSides correctamente', () {
      final faro = autopartsCatalog.firstWhere((p) => p.name == 'Faro delantero');
      expect(faro.hasSides, isTrue);

      final motor = autopartsCatalog.firstWhere((p) => p.name == 'Motor completo');
      expect(motor.hasSides, isFalse);

      final espejo = autopartsCatalog.firstWhere((p) => p.name == 'Espejo lateral');
      expect(espejo.hasSides, isTrue);
    });

    test('popularAutopartChips contiene las piezas más cotizadas', () {
      expect(popularAutopartChips, contains('Faro delantero'));
      expect(popularAutopartChips, contains('Motor'));
      expect(popularAutopartChips, contains('Transmisión'));
      expect(popularAutopartChips, contains('Puerta'));
    });

    test('filtrado estricto por letra: "F" incluye Faro y Facia pero excluye Cofre y Diferencial', () {
      final results = searchAutoparts('F');
      expect(results.any((item) => item.name.startsWith('Faro')), isTrue);
      expect(results.any((item) => item.name.startsWith('Facia')), isTrue);
      expect(results.any((item) => item.name == 'Cofre'), isFalse);
      expect(results.any((item) => item.name == 'Diferencial'), isFalse);
      expect(results.any((item) => item.name.contains('MAF')), isFalse);
    });

    test('consulta vacía retorna todo el catálogo ordenado alfabéticamente para explorar deslizando', () {
      final all = searchAutoparts('');
      expect(all.length, greaterThanOrEqualTo(85));
      for (var i = 0; i < all.length - 1; i++) {
        expect(normalizeText(all[i].name).compareTo(normalizeText(all[i + 1].name)), lessThanOrEqualTo(0));
      }
    });
  });

  group('NewRequestPage & Interactive Step Flow', () {
    testWidgets('Zero-Flicker: muestra dropdown de marca inmediatamente sin pantalla de carga central', (
      tester,
    ) async {
      final api = _CatalogTestApiClient({
        'GET /api/Utilerias/marcas': (_) => [
          {'id': 1, 'marca': 'Toyota'},
        ],
        'GET /api/Utilerias/modelos': (_) => [
          {'id': 10, 'marcaId': 1, 'modelo': 'Corolla'},
        ],
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: const MaterialApp(home: NewRequestPage()),
        ),
      );

      // Inmediatamente el dropdown existe en pantalla (no un spinner central)
      expect(find.byKey(const Key('request-brand-select')), findsOneWidget);
      expect(find.text('¿Qué autoparte buscas?'), findsOneWidget);
      expect(find.text('Datos de tu vehículo'), findsOneWidget);

      await tester.pumpAndSettle();

      // Al terminar de cargar marcas, el dropdown sigue en su sitio
      expect(find.text('Selecciona una marca'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Chips populares colocan el texto en el buscador', (
      tester,
    ) async {
      final api = _CatalogTestApiClient({
        'GET /api/Utilerias/marcas': (_) => [
          {'id': 1, 'marca': 'Honda'},
        ],
        'GET /api/Utilerias/modelos': (_) => [],
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: const MaterialApp(home: NewRequestPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Búsquedas frecuentes:'), findsOneWidget);
      expect(find.text('Faro delantero'), findsOneWidget);

      await tester.tap(find.text('Faro delantero'));
      await tester.pumpAndSettle();

      final partField = tester.widget<TextFormField>(
        find.byKey(const Key('request-part-field')),
      );
      expect(partField.controller?.text, 'Faro delantero');
      // Debe aparecer el selector de lado
      expect(find.text('Lado o posición de la pieza (opcional):'), findsOneWidget);
      expect(find.text('Izquierdo (Piloto)'), findsOneWidget);
      expect(find.text('Derecho (Copiloto)'), findsOneWidget);
      expect(find.text('Ambos / Par'), findsOneWidget);
    });

    testWidgets('Paso 2 incluye Número de parte OEM, Motor, Transmisión y descripción', (
      tester,
    ) async {
      final api = _CatalogTestApiClient({
        'GET /api/Utilerias/marcas': (_) => [
          {'id': 1, 'marca': 'Ford'},
        ],
        'GET /api/Utilerias/modelos': (_) => [
          {'id': 5, 'marcaId': 1, 'modelo': 'Focus'},
        ],
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: const MaterialApp(home: NewRequestPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('request-part-field')), 'Alternador');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('request-brand-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ford').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('request-model-select-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Focus').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('request-year-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${DateTime.now().year}').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('request-continue-button')));
      await tester.pumpAndSettle();

      // Estamos en Paso 2: Detalles
      expect(find.text('Agrega más detalles'), findsOneWidget);
      expect(find.byKey(const Key('request-part-number-field')), findsOneWidget);
      expect(find.byKey(const Key('request-engine-field')), findsOneWidget);
      expect(find.byKey(const Key('request-transmission-field')), findsOneWidget);
      expect(find.byKey(const Key('request-description-field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('request-part-number-field')),
        'OEM-9921',
      );
      await tester.enterText(
        find.byKey(const Key('request-engine-field')),
        '2.0L Duratec',
      );
      await tester.enterText(
        find.byKey(const Key('request-description-field')),
        'En buen estado probado',
      );
      await tester.pumpAndSettle();

      // Navegación hacia atrás y adelante preserva los datos
      await tester.tap(find.byTooltip('Regresar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Qué autoparte buscas?'), findsOneWidget);
      final partField = tester.widget<TextFormField>(
        find.byKey(const Key('request-part-field')),
      );
      expect(partField.controller?.text, 'Alternador');

      // Avanzar de nuevo
      await tester.tap(find.byKey(const Key('request-continue-button')));
      await tester.pumpAndSettle();

      expect(find.text('Agrega más detalles'), findsOneWidget);
      final partNumField = tester.widget<TextFormField>(
        find.byKey(const Key('request-part-number-field')),
      );
      expect(partNumField.controller?.text, 'OEM-9921');
    });

    testWidgets('Pantalla de revisión muestra todos los datos y permite editar paso a paso', (
      tester,
    ) async {
      final draft = RequestDraft()
        ..part = 'Faro delantero'
        ..partSide = 'Izquierdo (Piloto)'
        ..brandName = 'Mazda'
        ..modelName = 'Mazda 3'
        ..year = 2021
        ..partNumber = 'BBN2-51-041'
        ..engine = '2.5L Turbo'
        ..transmission = 'Automática'
        ..description = 'Con lupa LED'
        ..cityName = 'Tijuana, Baja California';

      int? editedStep;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    editedStep = await Navigator.push<int>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestReviewPage(draft: draft),
                      ),
                    );
                  },
                  child: const Text('Abrir Revisión'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Revisión'));
      await tester.pumpAndSettle();

      expect(find.text('Revisa tu solicitud'), findsOneWidget);
      expect(find.text('Faro delantero (Izquierdo (Piloto))'), findsOneWidget);
      expect(find.text('Mazda'), findsOneWidget);
      expect(find.text('Mazda 3'), findsOneWidget);
      expect(find.text('BBN2-51-041'), findsOneWidget);
      expect(find.text('2.5L Turbo'), findsOneWidget);
      expect(find.text('Automática'), findsOneWidget);
      expect(find.text('Con lupa LED'), findsOneWidget);
      expect(find.text('Tijuana, Baja California'), findsOneWidget);

      // Tocar editar en la tarjeta de detalles (Paso 1)
      final editButtons = find.text('Editar');
      expect(editButtons, findsNWidgets(4));

      await tester.ensureVisible(editButtons.at(1));
      await tester.pumpAndSettle();
      await tester.tap(editButtons.at(1));
      await tester.pumpAndSettle();

      expect(editedStep, 1);
    });

    testWidgets('Buscador: teclear "F" muestra lista filtrada en vivo sin Cofre y permite seleccionar', (
      tester,
    ) async {
      final api = _CatalogTestApiClient({
        'GET /api/Utilerias/marcas': (_) => [],
        'GET /api/Utilerias/modelos': (_) => [],
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: const MaterialApp(home: NewRequestPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('request-part-field')), 'F');
      await tester.pumpAndSettle();

      // Muestra coincidencias con cabecera
      expect(find.textContaining('COINCIDENCIAS'), findsOneWidget);
      expect(find.byKey(const Key('autopart-suggestion-Faro delantero')), findsOneWidget);
      expect(find.text('Cofre'), findsNothing);

      // Tocar Faro delantero
      await tester.tap(find.byKey(const Key('autopart-suggestion-Faro delantero')));
      await tester.pumpAndSettle();

      final partField = tester.widget<TextFormField>(
        find.byKey(const Key('request-part-field')),
      );
      expect(partField.controller?.text, 'Faro delantero');
      expect(find.text('Lado o posición de la pieza (opcional):'), findsOneWidget);
    });

    testWidgets('Buscador: escribir "espejo" despliega selector de lados de inmediato', (
      tester,
    ) async {
      final api = _CatalogTestApiClient({
        'GET /api/Utilerias/marcas': (_) => [],
        'GET /api/Utilerias/modelos': (_) => [],
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: const MaterialApp(home: NewRequestPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('request-part-field')), 'espejo');
      await tester.pumpAndSettle();

      // Debe aparecer selector de lados de inmediato para espejo
      expect(find.text('Lado o posición de la pieza (opcional):'), findsOneWidget);
      expect(find.text('Izquierdo (Piloto)'), findsOneWidget);
      expect(find.text('Derecho (Copiloto)'), findsOneWidget);

      // Seleccionar Izquierdo
      await tester.tap(find.text('Izquierdo (Piloto)'));
      await tester.pumpAndSettle();

      // Botón limpiar borra el texto y resetea lado
      await tester.tap(find.byTooltip('Limpiar'));
      await tester.pumpAndSettle();

      final partField = tester.widget<TextFormField>(
        find.byKey(const Key('request-part-field')),
      );
      expect(partField.controller?.text, '');
      expect(find.text('Lado o posición de la pieza (opcional):'), findsNothing);
    });

    testWidgets('Explorar catálogo sin escribir: hacer tap en buscador vacío muestra todo el catálogo scrollable', (
      tester,
    ) async {
      final api = _CatalogTestApiClient({
        'GET /api/Utilerias/marcas': (_) => [],
        'GET /api/Utilerias/modelos': (_) => [],
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: const MaterialApp(home: NewRequestPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Tocar el campo de búsqueda vacío
      await tester.tap(find.byKey(const Key('request-part-field')));
      await tester.pumpAndSettle();

      // Debe mostrar cabecera del catálogo completo
      expect(find.textContaining('CATÁLOGO DE AUTOPARTES'), findsOneWidget);
      expect(find.text('↕ Desliza para explorar'), findsOneWidget);

      // Verificar que podemos scrollear en la lista
      expect(find.byType(Scrollbar), findsOneWidget);
    });
  });
}

class _CatalogTestApiClient implements ApiClient {
  _CatalogTestApiClient(this._routes);

  final Map<String, Object? Function(Map<String, dynamic>? query)> _routes;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final key = 'GET $path';
    final handler = _routes[key];
    if (handler != null) {
      return handler(queryParameters);
    }
    return [];
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => throw UnimplementedError();

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => throw UnimplementedError();

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => throw UnimplementedError();

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) async => throw UnimplementedError();
}
