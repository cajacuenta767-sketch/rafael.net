// Tier "humo": todas las páginas del catálogo en todos los dispositivos de la
// matriz, con escala de texto 1. Detecta overflow/excepciones de layout y
// widgets clave ausentes. Ver docs/RESPONSIVE_TEST_PLAN.md.

import 'package:flutter_test/flutter_test.dart';

import '../support/arnes_responsivo.dart';
import '../support/dispositivos_prueba.dart';
import '../support/hallazgos_conocidos.dart';
import 'paginas_responsivas.dart';

void main() {
  for (final pagina in paginasResponsivas) {
    group(pagina.id, () {
      for (final dispositivo in todosLosDispositivos) {
        for (final escala in escalasTextoHumo) {
          testWidgets(
            '${pagina.id} se ve sin errores en ${dispositivo.descripcion}',
            skip: hallazgosConocidos.containsKey(
              claveHallazgo(pagina.id, dispositivo, escala),
            ),
            (tester) async {
              await verificarPaginaEnDispositivo(
                tester,
                pagina,
                dispositivo,
                escalaTexto: escala,
              );
            },
          );
        }
      }
    });
  }
}
