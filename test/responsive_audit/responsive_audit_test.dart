// Auditoría responsive: abre cada pantalla de la app en cada dispositivo de
// devices.dart, guarda una captura y anota lo que se ve mal.
//
// Solo corre cuando existe la variable AUDIT_OUT (el flujo
// .github/workflows/auditoria-responsive.yml la define). En `flutter test`
// normal se omite.
//
//   AUDIT_OUT=build/auditoria flutter test test/responsive_audit
//
// Por cada captura escribe una línea en resultados.jsonl con:
// - desbordamientos (las franjas amarillas y negras de Flutter) y el archivo
//   y la línea del widget que los causa;
// - otros errores de acomodo o de ejecución;
// - textos cortados con "…" o por maxLines;
// - elementos que se salen de la pantalla sin estar en un scroll horizontal;
// - botones y campos estirados en pantallas anchas;
// - líneas de texto demasiado largas y letra demasiado chica;
// - llamadas al API sin respuesta simulada.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:app_yonke/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'devices.dart';
import 'fake_backend.dart';

final String? _outDir = Platform.environment['AUDIT_OUT'];
final Set<String>? _onlyScreens = _idList('AUDIT_SCREENS');
final Set<String>? _onlyDevices = _idList('AUDIT_DEVICES');

Set<String>? _idList(String name) {
  final ids = (Platform.environment[name] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  return ids.isEmpty ? null : ids;
}

/// Dispositivo en el que además se revisan las guías de accesibilidad.
const _referenceDevice = 'iphone-15';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final outDir = _outDir;
  final onlyScreens = _onlyScreens;
  final onlyDevices = _onlyDevices;
  if (outDir == null || outDir.isEmpty) {
    test('auditoría responsive (define AUDIT_OUT para correrla)', () {},
        skip: 'Solo corre con AUDIT_OUT');
    return;
  }

  final out = Directory(outDir);
  final images = Directory('${out.path}/capturas')..createSync(recursive: true);
  final results = File('${out.path}/resultados.jsonl');
  if (results.existsSync()) results.deleteSync();

  setUpAll(() async {
    await _loadFonts();
    File('${out.path}/dispositivos.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert([
        for (final d in auditDevices)
          {
            'id': d.id,
            'name': d.name,
            'category': d.category.name,
            'width': d.width,
            'height': d.height,
            'pixelRatio': d.pixelRatio,
            'textScale': d.textScale,
            'keyboardHeight': d.keyboardHeight,
            'note': d.note,
          },
      ]),
    );
    File('${out.path}/pantallas.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert([
        for (final s in auditScreens())
          {'id': s.id, 'title': s.title, 'role': s.role.name, 'route': s.route},
      ]),
    );
  });

  for (final screen in auditScreens()) {
    if (onlyScreens != null && !onlyScreens.contains(screen.id)) continue;
    testWidgets('${screen.id}: ${screen.title}', (tester) async {
      for (final device in auditDevices) {
        if (onlyDevices != null && !onlyDevices.contains(device.id)) {
          continue;
        }
        final record = await _capture(tester, screen, device, images);
        results.writeAsStringSync(
          '${jsonEncode(record)}\n',
          mode: FileMode.append,
          flush: true,
        );
      }
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}

Future<Map<String, Object?>> _capture(
  WidgetTester tester,
  AuditScreen screen,
  AuditDevice device,
  Directory images,
) async {
  final started = DateTime.now();
  final errors = <FlutterErrorDetails>[];
  final originalOnError = FlutterError.onError;
  FlutterError.onError = errors.add;

  tester.view.physicalSize = Size(
    device.width * device.pixelRatio,
    device.height * device.pixelRatio,
  );
  tester.view.devicePixelRatio = device.pixelRatio;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  tester.view.viewInsets = FakeViewPadding(
    bottom: device.keyboardHeight * device.pixelRatio,
  );
  tester.platformDispatcher.textScaleFactorTestValue = device.textScale;

  auditPrepareGlobals();
  final api = AuditApiClient(screen.role);
  final boundaryKey = GlobalKey();
  final record = <String, Object?>{
    'screen': screen.id,
    'title': screen.title,
    'role': screen.role.name,
    'route': screen.route,
    'device': device.id,
  };

  final findings = _Findings();
  String? topImage;
  String? bottomImage;
  var scrollable = 0.0;
  String? finalRoute;

  try {
    appRouter.go(screen.route, extra: screen.extra?.call());
    await tester.pumpWidget(
      RepaintBoundary(key: boundaryKey, child: auditApp(screen.role, api)),
    );
    await _settle(tester);
    await _precacheImages(tester);
    await _settle(tester);

    finalRoute = appRouter.routerDelegate.currentConfiguration.uri.toString();
    _inspect(tester, device, findings);

    final base = '${screen.id}__${device.id}';
    topImage = 'capturas/$base.png';
    await _saveImage(tester, boundaryKey, device, '${images.parent.path}/$topImage');

    // Recorre la página hasta abajo para que se construya y se revise todo.
    final scroll = _mainScrollable(tester);
    if (scroll != null) {
      final position = scroll.position;
      scrollable = position.maxScrollExtent;
      if (position.maxScrollExtent > 0) {
        final step = math.max(position.viewportDimension * 0.8, 100.0);
        var offset = position.pixels;
        while (offset < position.maxScrollExtent) {
          offset = math.min(offset + step, position.maxScrollExtent);
          position.jumpTo(offset);
          await tester.pump(const Duration(milliseconds: 50));
          _inspect(tester, device, findings);
        }
        await _settle(tester);
        await _precacheImages(tester);
        await tester.pump();
        _inspect(tester, device, findings);
        if (position.maxScrollExtent > position.viewportDimension * 0.25) {
          bottomImage = 'capturas/${base}__abajo.png';
          await _saveImage(
            tester,
            boundaryKey,
            device,
            '${images.parent.path}/$bottomImage',
          );
        }
      }
    }

    if (device.id == _referenceDevice) {
      scroll?.position.jumpTo(0);
      await tester.pump();
      record['accesibilidad'] = await _accessibility(tester);
    }
  } catch (error, stack) {
    findings.crash = '$error\n${_shortStack(stack)}';
  } finally {
    // Desmonta la app para cancelar temporizadores y sondeos.
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    } catch (_) {}
    FlutterError.onError = originalOnError;
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }

  for (final details in errors) {
    findings.addError(details);
  }

  record.addAll({
    'finalRoute': finalRoute,
    'image': topImage,
    'imageBottom': bottomImage,
    'scrollExtent': scrollable.round(),
    ...findings.toJson(),
    'missingApi': api.missing.toSet().toList(),
    'ms': DateTime.now().difference(started).inMilliseconds,
  });
  return record;
}

// --- Revisión del árbol ------------------------------------------------------

class _Findings {
  final overflows = <String, Map<String, Object?>>{};
  final layoutErrors = <String>{};
  final runtimeErrors = <String>{};
  final truncated = <String>{};
  final offscreen = <String, Map<String, Object?>>{};
  final stretched = <String, double>{};
  final longLines = <String, double>{};
  double? minFont;
  String? minFontText;
  String? crash;

  static final _overflowPattern = RegExp(
    r'overflowed by ([\d.]+) pixels on the (\w+)',
  );
  static final _location = RegExp(
    r'lib/(?:features|app|core)/[\w/]+\.dart:\d+:\d+',
  );

  void addError(FlutterErrorDetails details) {
    final message = details.exceptionAsString().split('\n').first.trim();
    String info;
    try {
      info = details.toString();
    } catch (_) {
      info = '';
    }
    String? location = _location.firstMatch(info)?.group(0);
    try {
      for (final node in details.informationCollector?.call() ??
          const <DiagnosticsNode>[]) {
        final value = node.value;
        if (value is DebugCreator) {
          location ??= _appLocation(value.element);
        }
      }
    } catch (_) {}
    final overflow = _overflowPattern.firstMatch(message);
    if (overflow != null) {
      final key = '${location ?? message}|${overflow.group(2)}';
      final pixels = double.tryParse(overflow.group(1)!) ?? 0;
      final existing = overflows[key];
      if (existing == null || (existing['pixels'] as double) < pixels) {
        overflows[key] = {
          'message': message,
          'pixels': pixels,
          'side': overflow.group(2),
          'location': location,
          'widget': RegExp(r'A (\w+) overflowed').firstMatch(message)?.group(1),
        };
      }
      return;
    }
    final stack = details.stack == null
        ? ''
        : '\n${details.stack.toString().split('\n').where((l) => l.contains('package:app_yonke') || l.contains('lib/')).take(4).join('\n')}';
    final text =
        '${location == null ? message : '$message ($location)'}$stack';
    final isLayout =
        message.contains('RenderBox was not laid out') ||
        message.contains('constraints') ||
        message.contains('unbounded') ||
        message.contains('infinite') ||
        message.contains('Incorrect use of ParentDataWidget');
    final isImage =
        message.contains('HTTP request failed') ||
        message.contains('image') ||
        message.contains('Image') ||
        message.contains('NetworkImage');
    if (isImage) return; // Las imágenes remotas no cargan en la prueba.
    (isLayout ? layoutErrors : runtimeErrors).add(text);
  }

  Map<String, Object?> toJson() => {
    'overflows': overflows.values.toList(),
    'layoutErrors': layoutErrors.toList(),
    'runtimeErrors': runtimeErrors.toList(),
    'truncated': truncated.take(12).toList(),
    'truncatedCount': truncated.length,
    'offscreen': offscreen.values.take(8).toList(),
    'stretched': [
      for (final e in stretched.entries) {'widget': e.key, 'width': e.value},
    ],
    'longLines': [
      for (final e in longLines.entries.take(6))
        {'text': e.key, 'width': e.value},
    ],
    'minFont': minFont,
    'minFontText': minFontText,
    'crash': crash,
  };
}

void _inspect(WidgetTester tester, AuditDevice device, _Findings findings) {
  final screenWidth = device.width;
  final reportedOffscreen = <Element>{};

  for (final element in collectAllElementsFrom(
    tester.binding.rootElement!,
    skipOffstage: true,
  )) {
    final render = element.renderObject;
    if (render is! RenderBox || !render.attached || !render.hasSize) continue;
    if (element is! RenderObjectElement) continue;

    Rect rect;
    try {
      rect = MatrixUtils.transformRect(
        render.getTransformTo(null),
        Offset.zero & render.size,
      );
    } catch (_) {
      continue;
    }

    if (render is RenderParagraph) {
      final text = render.text.toPlainText().replaceAll('\n', ' ').trim();
      if (text.isEmpty) continue;
      if (render.didExceedMaxLines) findings.truncated.add(_clip(text, 90));
      final fontSize = render.text.style?.fontSize;
      if (fontSize != null) {
        final effective = render.textScaler.scale(fontSize);
        if (findings.minFont == null || effective < findings.minFont!) {
          findings.minFont = effective;
          findings.minFontText = _clip(text, 40);
        }
      }
      if (rect.width > 820 && text.length > 110) {
        findings.longLines[_clip(text, 60)] = rect.width.roundToDouble();
      }
    }

    final widget = element.widget;
    if (screenWidth >= 700 &&
        (widget is ButtonStyleButton || widget is InputDecorator) &&
        rect.width > 640) {
      final name = widget.runtimeType.toString().split('<').first;
      final current = findings.stretched[name] ?? 0;
      if (rect.width > current) findings.stretched[name] = rect.width.roundToDouble();
    }

    final outRight = rect.right - screenWidth;
    final outLeft = -rect.left;
    if ((outRight > 2 || outLeft > 2) && rect.width > 1 && rect.height > 1) {
      if (_insideHorizontalScroll(element)) continue;
      var nested = false;
      element.visitAncestorElements((ancestor) {
        if (reportedOffscreen.contains(ancestor)) {
          nested = true;
          return false;
        }
        return true;
      });
      if (nested) continue;
      reportedOffscreen.add(element);
      final name = widget.runtimeType.toString();
      final key = '$name@${_creationLocation(element) ?? ''}';
      findings.offscreen.putIfAbsent(
        key,
        () => {
          'widget': name,
          'pixels': math.max(outRight, outLeft).roundToDouble(),
          'location': _creationLocation(element),
          'text': _firstText(element),
        },
      );
    }
  }
}

bool _insideHorizontalScroll(Element element) {
  var inside = false;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Scrollable &&
        (widget.axisDirection == AxisDirection.left ||
            widget.axisDirection == AxisDirection.right)) {
      inside = true;
      return false;
    }
    // Rutas que entran o salen con animación, y el contenido recortado a
    // propósito, no cuentan.
    if (widget is ClipRect || widget is ClipRRect || widget is Overlay) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}

String? _creationLocation(Element element) => _appLocation(element);

/// Archivo y línea del código de la app que creó el widget (o su ancestro
/// más cercano creado en lib/).
String? _appLocation(Element element) {
  String? found;
  Element? current = element;
  var depth = 0;
  while (current != null && depth < 40 && found == null) {
    try {
      final location = developer.CreationLocation.of(current.widget);
      final file = location?.file ?? '';
      final index = file.lastIndexOf('/lib/');
      if (index >= 0 &&
          !file.contains('/packages/flutter') &&
          !file.contains('.pub-cache') &&
          !file.contains('/test/')) {
        found = '${file.substring(index + 1)}:${location!.line}';
      }
    } catch (_) {}
    Element? parent;
    current.visitAncestorElements((a) {
      parent = a;
      return false;
    });
    current = parent;
    depth++;
  }
  return found;
}

String? _firstText(Element element) {
  String? text;
  void visit(Element e) {
    if (text != null) return;
    final render = e.renderObject;
    if (render is RenderParagraph) {
      final value = render.text.toPlainText().trim();
      if (value.isNotEmpty) text = _clip(value, 50);
      return;
    }
    e.visitChildren(visit);
  }

  visit(element);
  return text;
}

ScrollableState? _mainScrollable(WidgetTester tester) {
  ScrollableState? best;
  var bestArea = 0.0;
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = (element as StatefulElement).state;
    if (state is! ScrollableState) continue;
    final axis = axisDirectionToAxis(state.axisDirection);
    if (axis != Axis.vertical) continue;
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    final area = box.size.width * box.size.height;
    if (area > bestArea && state.position.hasContentDimensions) {
      bestArea = area;
      best = state;
    }
  }
  return best;
}

Future<Map<String, Object?>> _accessibility(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  final result = <String, Object?>{};
  try {
    for (final entry in {
      'tapTargets': androidTapTargetGuideline,
      'labeledTapTargets': labeledTapTargetGuideline,
      'textContrast': textContrastGuideline,
    }.entries) {
      try {
        final evaluation = await entry.value.evaluate(tester);
        result[entry.key] = {
          'passed': evaluation.passed,
          'reason': evaluation.reason == null
              ? null
              : _clip(evaluation.reason!, 1500),
        };
      } catch (error) {
        result[entry.key] = {'passed': null, 'reason': 'No evaluado: $error'};
      }
    }
  } finally {
    handle.dispose();
  }
  return result;
}

// --- Utilidades --------------------------------------------------------------

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) break;
  }
}

Future<void> _precacheImages(WidgetTester tester) async {
  final elements = find.byType(Image).evaluate().toList();
  if (elements.isEmpty) return;
  await tester.runAsync(() async {
    for (final element in elements) {
      final image = (element.widget as Image).image;
      try {
        await precacheImage(image, element).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
  });
  await tester.pump();
}

Future<void> _saveImage(
  WidgetTester tester,
  GlobalKey key,
  AuditDevice device,
  String path,
) async {
  // Celulares a 1.5x para que el texto se lea; lo demás a 1x.
  final ratio = device.width < 600 ? 1.5 : 1.0;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes != null) {
      File(path).writeAsBytesSync(bytes.buffer.asUint8List());
    }
  });
}

Future<void> _loadFonts() async {
  final root =
      Platform.environment['AUDIT_FLUTTER_ROOT'] ??
      Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final roboto = FontLoader('Roboto');
  final icons = FontLoader('MaterialIcons');
  final loaded = <String>[];
  for (final file in dir.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last.toLowerCase();
    loaded.add(name);
    final data = Future.value(
      ByteData.view(file.readAsBytesSync().buffer),
    );
    if (name.startsWith('roboto-') && name.endsWith('.ttf')) {
      roboto.addFont(data);
    } else if (name.startsWith('materialicons')) {
      icons.addFont(data);
    }
  }
  await roboto.load();
  await icons.load();
  File('$_outDir/fuentes.txt').writeAsStringSync(loaded.join('\n'));
}

String _clip(String text, int max) =>
    text.length <= max ? text : '${text.substring(0, max - 1)}…';

String _shortStack(StackTrace stack) =>
    stack.toString().split('\n').take(8).join('\n');
