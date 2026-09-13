import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configuración global de `flutter test`.
///
/// Las imágenes de referencia en `test/goldens/` se generaron en otro sistema
/// operativo. El texto se rasteriza distinto en cada plataforma (hinting y
/// antialiasing de las fuentes), así que en Linux (CI) y macOS difieren entre
/// 1 % y 2 % de los píxeles aunque la composición sea idéntica. El comparador
/// de aquí acepta esa variación y sigue fallando ante cambios reales de
/// diseño, que mueven porcentajes mucho mayores. Para regenerar las
/// referencias: `flutter test --update-goldens`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final current = goldenFileComparator;
  if (current is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenFileComparator(
      current.basedir.resolve('flutter_test_config.dart'),
    );
  }
  await testMain();
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(super.testFile);

  /// Fracción máxima de píxeles distintos aceptada (3 %).
  static const double _maxDiffPercent = 0.03;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _maxDiffPercent;
    if (passed) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
