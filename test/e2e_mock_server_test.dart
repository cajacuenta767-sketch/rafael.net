// Prueba de extremo a extremo de la app completa contra un servidor HTTP real.
//
// Arranca `tool/api_mock_server.py` (que implementa las 56 rutas del contrato
// con estado en memoria) y levanta la app de producción: router, providers,
// repositorios, parsers y el cliente Dio real. Nada se sustituye salvo el
// almacenamiento seguro (no hay plugin nativo en pruebas) y la URL base.
//
// Recorre el ciclo de negocio pulsando los botones reales:
//   cliente: OTP → home → nueva solicitud → ciudad → revisión → enviar → lista
//   yonke:   login → bandeja → detalle → cotizar
//   cliente: OTP → cotizaciones → detalle → mensajes → orden → seguimiento →
//            cancelar orden → calificar
//
// El OTP aceptado por el simulador es 123456.
import 'dart:convert';
import 'dart:io';

import 'package:app_yonke/app/app.dart';
import 'package:app_yonke/app/router/app_router.dart';
import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/dio_api_client.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _port = 8791;
final _shotKey = GlobalKey();
const _baseUrl = 'http://127.0.0.1:$_port';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test bloquea la red por defecto; aquí se necesita HTTP real.
  HttpOverrides.global = null;

  late Process server;
  final secureStorage = <String, String>{};

  setUpAll(() async {
    server = await Process.start('python3', [
      'tool/api_mock_server.py',
      '$_port',
    ], workingDirectory: Directory.current.path);
    server.stderr.transform(utf8.decoder).listen(stderr.write);
    await _loadRealFonts();
    await _waitForServer();
  });

  tearDownAll(() {
    server.kill();
  });

  final launchedUrls = <String>[];

  setUp(() {
    secureStorage.clear();
    launchedUrls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            final args = (call.arguments as Map?) ?? const {};
            if (call.method == 'launch') {
              launchedUrls.add(args['url'] as String);
            }
            return true;
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = (call.arguments as Map?) ?? const {};
            final key = args['key'] as String?;
            switch (call.method) {
              case 'read':
                return secureStorage[key];
              case 'write':
                secureStorage[key!] = args['value'] as String;
                return null;
              case 'delete':
                secureStorage.remove(key);
                return null;
              case 'deleteAll':
                secureStorage.clear();
                return null;
              case 'readAll':
                return Map<String, String>.from(secureStorage);
              case 'containsKey':
                return secureStorage.containsKey(key);
            }
            return null;
          },
        );
  });

  testWidgets('ciclo completo cliente ↔ yonke contra el servidor simulado', (
    tester,
  ) async {
    final tokens = _MemoryTokenStore();
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        headers: const {'Accept': 'application/json'},
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          apiClientProvider.overrideWithValue(DioApiClient(tokens, dio: dio)),
        ],
        child: RepaintBoundary(key: _shotKey, child: const YonkeApp()),
      ),
    );
    await tester.pumpAndSettle();
    final t = _Driver(tester);

    // ---------------- Cliente: OTP ----------------
    await t.shot('01_inicio');
    await t.tap(find.text('Soy cliente'));
    await t.settle(find.byKey(const Key('legal_consent_dialog')));
    await t.shot('02_terminos');
    await t.tap(find.byKey(const Key('accept_all_legal')));
    await t.tap(find.byKey(const Key('confirm_legal_acceptance')));
    await t.settle(find.byKey(const Key('client_phone_field')));
    await t.shot('03_login_cliente');
    await tester.enterText(
      find.byKey(const Key('client_phone_field')),
      '5512345678',
    );
    await t.tap(find.text('Enviar código'));
    await t.settle(find.text('Iniciar sesión'));
    await t.shot('04_otp');
    await t.net(
      () =>
          tester.enterText(find.byKey(const Key('client_otp_field')), '123456'),
    );
    await t.settle(find.text('Nueva solicitud'), timeout: 15);
    await t.settle(
      find.textContaining('Aún no tienes solicitudes'),
      timeout: 15,
    );
    await t.shot('05_home_cliente');
    expect(await tokens.readAccessToken(), isNotNull);

    // ---------------- Cliente: nueva solicitud ----------------
    await t.tap(find.text('Nueva solicitud').first);
    await t.settle(find.byKey(const Key('request-part-field')));
    await t.shot('06_nueva_solicitud_pieza');
    await tester.enterText(
      find.byKey(const Key('request-part-field')),
      'Alternador prueba e2e',
    );
    await t.tap(find.byKey(const Key('request-continue-button')));
    await t.settle(find.byKey(const Key('request-brand-select')));
    await t.tap(find.byKey(const Key('request-brand-select')));
    await t.tap(find.text('Nissan').last);
    await t.tap(find.byKey(const ValueKey('request-model-select-3')));
    await t.tap(find.text('Sentra').last);
    await t.tap(find.byKey(const Key('request-year-select')));
    await t.tap(find.text('2018').last);
    await t.shot('07_nueva_solicitud_vehiculo');
    await t.tap(find.byKey(const Key('request-continue-button')));
    await t.settle(find.byKey(const ValueKey('details-step')));
    await t.tap(find.byKey(const Key('request-continue-button')));
    await t.settle(find.byKey(const ValueKey('photos-step')));
    await t.shot('08_nueva_solicitud_fotos');
    await t.tap(find.byKey(const Key('request-continue-button')));
    await t.settle(find.byKey(const Key('request-state-selector')));
    await t.tap(find.byKey(const Key('request-state-selector')));
    await t.tap(find.text('Jalisco').last);
    await t.settle(find.textContaining('Guadalajara'));
    await t.tap(find.textContaining('Guadalajara'));
    await t.shot('09_ciudad');
    await t.tap(find.text('Continuar'));
    await t.settle(find.byKey(const Key('submit-client-request')));
    await t.shot('10_revision');
    await t.tap(find.byKey(const Key('submit-client-request')));
    await t.settle(find.text('Ver mis solicitudes'), timeout: 15);
    await t.shot('11_solicitud_enviada');
    await t.tap(find.text('Ver mis solicitudes').first);
    await t.settle(find.textContaining('Alternador prueba e2e'), timeout: 15);
    await t.shot('12_mis_solicitudes');

    // ---------------- Yonke: login, bandeja, cotizar ----------------
    await t.go(AppRoutes.yonkeLogin);
    await t.settle(find.byKey(const Key('yonke-login-button')));
    await tester.enterText(
      find.byKey(const Key('yonke-email-field')),
      'yonke@prueba.local',
    );
    await tester.enterText(
      find.byKey(const Key('yonke-password-field')),
      'Secreta123',
    );
    await t.shot('13_login_yonke');
    await t.tap(find.byKey(const Key('yonke-login-button')));
    await t.settle(find.textContaining('Solicitudes'), timeout: 15);
    await t.settle(find.textContaining('Alternador prueba e2e'), timeout: 15);
    await t.shot('14_home_yonke');
    expect(await tokens.readYonkeGuidId(), isNotNull);

    await t.go(AppRoutes.yonkeRequests);
    await t.settle(find.textContaining('Alternador prueba e2e'), timeout: 15);
    await t.shot('15_bandeja_yonke');
    await t.tap(find.textContaining('Alternador prueba e2e').first);
    await t.settle(find.byKey(const Key('yonke-quote-button')), timeout: 15);
    await t.shot('16_detalle_solicitud_yonke');
    await t.tap(find.byKey(const Key('yonke-quote-button')));
    await t.settle(find.byKey(const Key('quote-price-field')));
    await tester.enterText(find.byKey(const Key('quote-price-field')), '1500');
    await t.shot('17_cotizar');
    await t.tap(find.byKey(const Key('submit-quote-button')));
    await t.settle(find.byKey(const Key('quote-success-button')), timeout: 15);
    await t.shot('18_cotizacion_enviada');
    await t.tap(find.byKey(const Key('quote-success-button')));
    await t.settle(find.textContaining('Solicitudes'), timeout: 15);

    // ---------------- Cliente: cotización, chat, orden ----------------
    await t.go(AppRoutes.clientLogin);
    await t.settle(find.byKey(const Key('client_phone_field')));
    await tester.enterText(
      find.byKey(const Key('client_phone_field')),
      '5512345678',
    );
    await t.tap(find.text('Enviar código'));
    await t.settle(find.text('Iniciar sesión'));
    await t.net(
      () =>
          tester.enterText(find.byKey(const Key('client_otp_field')), '123456'),
    );
    await t.settle(find.text('Nueva solicitud'), timeout: 15);

    await t.go(AppRoutes.clientQuotes);
    await t.settle(find.textContaining(r'$1500.50'), timeout: 15);
    await t.shot('19_cotizaciones_cliente');
    await t.tap(find.textContaining(r'$1500.50').first);
    await t.settle(find.byKey(const Key('client-create-order')), timeout: 15);
    await t.shot('20_detalle_cotizacion');

    await t.tap(find.byKey(const Key('client-open-conversation')));
    await t.settle(find.byKey(const Key('client-send-message')), timeout: 15);
    await tester.enterText(find.byType(TextField).last, 'Hola desde e2e');
    await t.tap(find.byKey(const Key('client-send-message')));
    await t.settle(find.text('Hola desde e2e'), timeout: 15);
    await t.shot('21_chat_cliente');
    await t.back();
    await t.settle(find.byKey(const Key('client-create-order')));

    await t.tap(find.byKey(const Key('client-create-order')));
    await t.settle(find.byKey(const Key('client-confirm-order')));
    await t.shot('22_confirmar_orden');
    await t.tap(find.byKey(const Key('client-confirm-order')));
    await t.settle(find.byKey(const Key('client-rate-yonke')), timeout: 15);
    await t.shot('23_orden_creada');

    // ---------------- Cliente: calificar ----------------
    await t.tap(find.byKey(const Key('client-rate-yonke')));
    await t.settle(find.byKey(const Key('client-rating-5')));
    await t.tap(find.byKey(const Key('client-rating-5')));
    await t.shot('24_calificar');
    await t.tap(find.byKey(const Key('client-submit-rating')));
    await t.settle(find.text('Ir al inicio'), timeout: 15);

    // ---------------- Cliente: seguimiento y cancelación ----------------
    await t.go(AppRoutes.clientQuotes);
    await t.settle(find.textContaining(r'$1500.50'), timeout: 15);
    await t.tap(find.textContaining(r'$1500.50').first);
    await t.settle(
      find.byKey(const Key('client-open-order-tracking')),
      timeout: 15,
    );
    await t.tap(find.byKey(const Key('client-open-order-tracking')));
    await t.settle(find.byKey(const Key('client-cancel-order')), timeout: 15);
    await t.shot('25_seguimiento_orden');

    // Pago con Stripe: checkout abre el navegador y luego se verifica.
    await t.tap(find.byKey(const Key('client-pay-order')));
    await t.settle(find.byKey(const Key('client-verify-payment')), timeout: 15);
    expect(launchedUrls, hasLength(1));
    expect(launchedUrls.single, startsWith('https://checkout.stripe.com/'));
    await t.tap(find.byKey(const Key('client-verify-payment')));
    await t.settle(find.text('Pago confirmado'), timeout: 15);
    await t.shot('26_pago_confirmado');
    expect(find.byKey(const Key('client-payment-error')), findsNothing);
    await t.tap(find.byKey(const Key('client-cancel-order')));
    await t.settle(find.byKey(const Key('client-confirm-cancel-order')));
    await t.tap(find.byKey(const Key('client-confirm-cancel-order')));
    await t.wait(1);
    await t.shot('27_orden_cancelada');
  });

  testWidgets('pantallas secundarias de yonke y cliente contra el simulador', (
    tester,
  ) async {
    final tokens = _MemoryTokenStore();
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        headers: const {'Accept': 'application/json'},
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          apiClientProvider.overrideWithValue(DioApiClient(tokens, dio: dio)),
        ],
        child: RepaintBoundary(key: _shotKey, child: const YonkeApp()),
      ),
    );
    await tester.pumpAndSettle();
    final t = _Driver(tester);
    Finder keyPrefix(String prefix) => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(prefix),
    );

    // ---------------- Yonke ----------------
    await t.go(AppRoutes.yonkeLogin);
    await t.settle(find.byKey(const Key('yonke-login-button')));
    await tester.enterText(
      find.byKey(const Key('yonke-email-field')),
      'yonke@prueba.local',
    );
    await tester.enterText(
      find.byKey(const Key('yonke-password-field')),
      'Secreta123',
    );
    await t.tap(find.byKey(const Key('yonke-login-button')));
    await t.settle(find.textContaining('Solicitudes'), timeout: 15);

    // Cobertura: marcar Zapopan y guardar.
    await t.go(AppRoutes.yonkeCoverage);
    await t.settle(
      find.byKey(const Key('yonke-coverage-city-11')),
      timeout: 15,
    );
    await t.tap(find.byKey(const Key('yonke-coverage-city-11')));
    await t.shot('28_cobertura_yonke');
    await t.tap(find.byKey(const Key('yonke-save-coverage')));
    await t.settle(find.text('Cobertura guardada.'), timeout: 15);
    await t.wait(4); // deja que el aviso desaparezca y no tape botones

    // Perfil del yonke con datos del API.
    await t.go(AppRoutes.yonkeProfile);
    await t.settle(find.textContaining('Yonke prueba'), timeout: 15);
    await t.shot('29_perfil_yonke');
    expect(find.byKey(const Key('yonke-sign-out')), findsOneWidget);

    // Mensajes: abrir la conversación existente y responder.
    await t.go(AppRoutes.yonkeMessages);
    await t.settle(keyPrefix('yonke-conversation-'), timeout: 15);
    await t.shot('30_mensajes_yonke');
    await t.tap(keyPrefix('yonke-conversation-'));
    await t.settle(find.byKey(const Key('yonke-message-input')), timeout: 15);
    await tester.enterText(
      find.byKey(const Key('yonke-message-input')),
      'Respuesta del yonke e2e',
    );
    // El botón queda bajo el borde inferior en esta altura; se envía con la
    // acción del teclado, que llama al mismo `onSend`.
    await t.net(() => tester.testTextInput.receiveAction(TextInputAction.done));
    await t.settle(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Respuesta del yonke e2e'),
      ),
      timeout: 15,
    );

    // Cotizaciones: detalle y edición del precio.
    await t.go(AppRoutes.yonkeQuotes);
    await t.settle(find.textContaining('1500'), timeout: 15);
    await t.tap(find.textContaining('1500').first);
    await t.settle(find.byKey(const Key('edit-yonke-quote')), timeout: 15);
    await t.shot('31_detalle_cotizacion_yonke');
    await t.tap(find.byKey(const Key('edit-yonke-quote')));
    await t.settle(find.byKey(const Key('edit-quote-price')));
    await tester.enterText(find.byKey(const Key('edit-quote-price')), '1400');
    await t.shot('32_editar_cotizacion');
    await t.tap(find.byKey(const Key('save-edited-quote')));
    await t.settle(
      find.text('Cotización actualizada correctamente.'),
      timeout: 15,
    );
    await t.wait(4);

    // Cerrar sesión del yonke.
    await t.go(AppRoutes.yonkeProfile);
    await t.tap(find.byKey(const Key('yonke-sign-out')));
    await t.tap(find.byKey(const Key('confirm-yonke-sign-out')));
    await t.settle(find.byKey(const Key('yonke-login-button')), timeout: 15);
    expect(await tokens.readAccessToken(), isNull);

    // ---------------- Cliente ----------------
    await t.go(AppRoutes.clientLogin);
    await t.settle(find.byKey(const Key('legal_consent_dialog')));
    await t.tap(find.byKey(const Key('accept_all_legal')));
    await t.tap(find.byKey(const Key('confirm_legal_acceptance')));
    await tester.enterText(
      find.byKey(const Key('client_phone_field')),
      '5512345678',
    );
    await t.tap(find.text('Enviar código'));
    await t.settle(find.text('Iniciar sesión'));
    await t.net(
      () =>
          tester.enterText(find.byKey(const Key('client_otp_field')), '123456'),
    );
    await t.settle(find.text('Nueva solicitud'), timeout: 15);

    // Explorar yonkes y abrir el perfil público.
    await t.go(AppRoutes.clientYonkes);
    await t.settle(keyPrefix('open-yonke-'), timeout: 15);
    await t.shot('33_explorar_yonkes');
    await t.tap(keyPrefix('open-yonke-'));
    await t.settle(find.textContaining('Yonke prueba'), timeout: 15);
    await t.shot('34_perfil_publico_yonke');

    // Notificaciones derivadas de cotizaciones y mensajes.
    await t.go(AppRoutes.clientNotifications);
    await t.settle(keyPrefix('client-notification-'), timeout: 15);
    await t.shot('35_notificaciones');

    // Bandeja de mensajes y conversación con la respuesta del yonke.
    await t.go(AppRoutes.clientMessages);
    await t.settle(keyPrefix('client-conversation-'), timeout: 15);
    await t.tap(keyPrefix('client-conversation-'));
    await t.settle(find.text('Respuesta del yonke e2e'), timeout: 15);
    await t.shot('36_chat_respuesta_yonke');

    // Cancelar la solicitud desde la lista.
    await t.go(AppRoutes.clientRequests);
    await t.settle(keyPrefix('cancel-request-card-'), timeout: 15);
    await t.shot('37_mis_solicitudes_cancelar');
    await t.tap(keyPrefix('cancel-request-card-'));
    await t.tap(find.byKey(const Key('confirm-delete-request-button')));
    await t.settle(
      find.text('Solicitud cancelada correctamente.'),
      timeout: 15,
    );

    // Perfil y cierre de sesión del cliente.
    await t.go(AppRoutes.clientProfile);
    await t.settle(find.byKey(const Key('client-sign-out')));
    await t.shot('38_perfil_cliente');
    await t.tap(find.byKey(const Key('client-sign-out')));
    await t.tap(find.byKey(const Key('confirm-client-sign-out')));
    await t.settle(find.byKey(const Key('client_phone_field')), timeout: 15);
    expect(await tokens.readAccessToken(), isNull);
  });
}

/// La fuente de pruebas de Flutter dibuja cada glifo como un cuadrado, lo que
/// provoca desbordes que no existen en el dispositivo. Se carga Roboto desde
/// la caché del SDK para medir el texto como en producción.
Future<void> _loadRealFonts() async {
  Directory? fontsDir;
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8 && fontsDir == null; i++) {
    final candidate = Directory('${dir.path}/artifacts/material_fonts');
    if (candidate.existsSync()) fontsDir = candidate;
    dir = dir.parent;
  }
  final root = Platform.environment['FLUTTER_ROOT'];
  if (fontsDir == null && root != null) {
    final candidate = Directory('$root/bin/cache/artifacts/material_fonts');
    if (candidate.existsSync()) fontsDir = candidate;
  }
  if (fontsDir == null) {
    // ignore: avoid_print
    print(
      '[e2e] no se encontraron las fuentes Roboto del SDK; se usa la fuente de pruebas',
    );
    return;
  }
  final loader = FontLoader('Roboto');
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]) {
    final file = File('${fontsDir.path}/$name');
    if (file.existsSync()) {
      loader.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
  }
  await loader.load();
  final icons = File('${fontsDir.path}/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
    await iconLoader.load();
  }
}

Future<void> _waitForServer() async {
  final client = HttpClient();
  for (var i = 0; i < 50; i++) {
    try {
      final req = await client.getUrl(
        Uri.parse('$_baseUrl/api/Utilerias/marcas'),
      );
      final res = await req.close();
      await res.drain<void>();
      if (res.statusCode == 200) {
        client.close();
        return;
      }
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError('El simulador no arrancó en $_baseUrl');
}

/// Ejecuta acciones que disparan red dentro de `runAsync` y espera con
/// tiempo real hasta que el widget esperado aparezca.
class _Driver {
  _Driver(this.tester);
  final WidgetTester tester;

  /// Guarda una captura de la pantalla actual en build/qa/<nombre>.png.
  Future<void> shot(String name) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      final boundary =
          _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/qa/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<void> net(Future<void> Function() action) async {
    await tester.runAsync(() async {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
  }

  Future<void> tap(Finder finder) async {
    await settle(finder);
    try {
      await tester.ensureVisible(finder.first);
      await tester.pump(const Duration(milliseconds: 200));
    } catch (_) {}
    await net(() => tester.tap(finder.first));
  }

  Future<void> go(String route) async {
    await net(() async => appRouter.go(route));
  }

  Future<void> back() async {
    await net(() async => appRouter.pop());
  }

  Future<void> wait(int seconds) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(seconds: seconds)),
    );
    await tester.pump();
  }

  /// Espera hasta [timeout] segundos a que [finder] encuentre algo.
  Future<void> settle(Finder finder, {int timeout = 8}) async {
    final started = DateTime.now();
    final deadline = started.add(Duration(seconds: timeout));
    var drags = 0;
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 300));
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      // Las listas perezosas no construyen lo que está fuera de pantalla:
      // tras un par de segundos sin hallazgo, desplaza hacia abajo.
      if (DateTime.now().difference(started).inSeconds >= 2 && drags < 8) {
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          await tester.drag(scrollables.last, const Offset(0, -350));
          await tester.pump(const Duration(milliseconds: 200));
          drags++;
        }
      }
    }
    final visible = find
        .byType(RichText)
        .evaluate()
        .map((e) => (e.widget as RichText).text.toPlainText())
        .where((s) => s.trim().isNotEmpty)
        .take(40)
        .join(' | ');
    final route = appRouter.routerDelegate.currentConfiguration.uri;
    fail('No apareció $finder en ${timeout}s. Ruta: $route. Textos: $visible');
  }
}

class _MemoryTokenStore implements TokenStore {
  String? _access;
  String? _refresh;
  DateTime? _expires;
  String? _yonke;

  @override
  Future<String?> readAccessToken() async => _access;
  @override
  Future<String?> readRefreshToken() async => _refresh;
  @override
  Future<DateTime?> readExpiresAt() async => _expires;
  @override
  Future<String?> readYonkeGuidId() async => _yonke;

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
    _expires = expiresAt;
    _yonke = yonkeGuidId;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _expires = null;
    _yonke = null;
  }
}
