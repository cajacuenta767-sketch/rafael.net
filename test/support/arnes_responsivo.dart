import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_yonke/app/theme/app_theme.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'dispositivos_prueba.dart';

/// Carpeta donde se guardan las capturas por dispositivo.
const carpetaCapturas = 'build/screenshots';

/// Monta [pagina] con el tamaño físico, el DPR y la escala de texto de
/// [dispositivo], dentro de `ProviderScope` + `MaterialApp` con el tema real
/// de la app, y devuelve la llave del `RepaintBoundary` que envuelve la página
/// (para capturas).
///
/// La escala de texto se aplica con `MediaQuery.of(context).copyWith` desde
/// `MaterialApp.builder`, de modo que `MediaQuery.sizeOf` conserva el tamaño
/// real del dispositivo (a diferencia de envolver la página en un
/// `MediaQueryData()` nuevo, que deja el tamaño en 0×0).
Future<GlobalKey> pumpEnDispositivo(
  WidgetTester tester,
  DispositivoPrueba dispositivo,
  Widget pagina, {
  double escalaTexto = 1,
  List<Override> overrides = const [],
}) async {
  tester.view.devicePixelRatio = dispositivo.dpr;
  tester.view.physicalSize = dispositivo.tamanoFisico;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final llave = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        supportedLocales: const [Locale('es'), Locale('en')],
        locale: const Locale('es'),
        localizationsDelegates: const [
          CountryLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escalaTexto)),
          child: child!,
        ),
        home: RepaintBoundary(key: llave, child: pagina),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return llave;
}

/// Falla si el layout lanzó una excepción (por ejemplo `RenderFlex overflowed`).
void expectSinExcepciones(WidgetTester tester, DispositivoPrueba dispositivo) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'Excepción de layout en ${dispositivo.descripcion}',
  );
}

/// Falla si el primer widget que encuentra [finder] sale de la pantalla.
void expectDentroDePantalla(
  WidgetTester tester,
  Finder finder,
  DispositivoPrueba dispositivo,
) {
  expect(finder, findsWidgets);
  final rect = tester.getRect(finder.first);
  final razon = 'fuera de pantalla en ${dispositivo.descripcion}: $rect';
  expect(rect.left, greaterThanOrEqualTo(0), reason: razon);
  expect(rect.top, greaterThanOrEqualTo(0), reason: razon);
  expect(
    rect.right,
    lessThanOrEqualTo(dispositivo.ancho + 0.01),
    reason: razon,
  );
  expect(
    rect.bottom,
    lessThanOrEqualTo(dispositivo.alto + 0.01),
    reason: razon,
  );
}

/// Clave de `hallazgosConocidos` para una combinación página/dispositivo.
String claveHallazgo(
  String pagina,
  DispositivoPrueba dispositivo,
  double escalaTexto,
) => escalaTexto == 1
    ? '$pagina@${dispositivo.id}'
    : '$pagina@${dispositivo.id}@x$escalaTexto';

/// Nombre de archivo de la captura de una página en un dispositivo.
String rutaCaptura(
  String pagina,
  DispositivoPrueba dispositivo,
  double escalaTexto,
) {
  final sufijo = escalaTexto == 1 ? '' : '_x$escalaTexto';
  return '$carpetaCapturas/$pagina/${dispositivo.id}$sufijo.png';
}

/// Guarda un PNG a tamaño lógico (`pixelRatio: 1`) de la página montada por
/// [pumpEnDispositivo] en `build/screenshots/<pagina>/<dispositivo>.png`.
Future<File> guardarCaptura(
  WidgetTester tester,
  GlobalKey llave, {
  required String pagina,
  required DispositivoPrueba dispositivo,
  double escalaTexto = 1,
}) async {
  final archivo = File(rutaCaptura(pagina, dispositivo, escalaTexto));
  await tester.runAsync(() async {
    final boundary =
        llave.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await archivo.parent.create(recursive: true);
    await archivo.writeAsBytes(data!.buffer.asUint8List());
  });
  return archivo;
}
