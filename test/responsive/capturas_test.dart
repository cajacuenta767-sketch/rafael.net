// Tier "capturas": guarda un PNG de cada página en cada dispositivo en
// build/screenshots/<pagina>/<dispositivo>.png (más los dispositivos
// representativos con texto x1.3). No falla por overflow: la captura muestra
// las franjas amarillas/negras como evidencia. Nunca consulta
// hallazgosConocidos.
//
//   flutter test --tags capturas
//   flutter test --exclude-tags capturas   (para correr rápido sin capturas)
@Tags(['capturas'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/arnes_responsivo.dart';
import '../support/dispositivos_prueba.dart';
import 'paginas_responsivas.dart';

void main() {
  final combinaciones = <(DispositivoPrueba, double)>[
    for (final dispositivo in todosLosDispositivos) (dispositivo, 1),
    for (final dispositivo in dispositivosRepresentativos)
      (dispositivo, escalasTextoAccesibilidad.first),
  ];

  for (final pagina in paginasResponsivas) {
    group(pagina.id, () {
      for (final (dispositivo, escala) in combinaciones) {
        testWidgets('captura ${pagina.id} en ${dispositivo.id}'
            '${escala == 1 ? '' : ' x$escala'}', (tester) async {
          final llave = await pumpEnDispositivo(
            tester,
            dispositivo,
            pagina.construir(),
            escalaTexto: escala,
            overrides: pagina.overrides(),
          );
          // Se descarta a propósito: la captura documenta el overflow.
          tester.takeException();
          await guardarCaptura(
            tester,
            llave,
            pagina: pagina.id,
            dispositivo: dispositivo,
            escalaTexto: escala,
          );
        });
      }
    });
  }
}
