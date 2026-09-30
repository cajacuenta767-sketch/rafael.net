// Tier "accesibilidad": dispositivos representativos con la escala de texto
// del sistema en "Grande" (1.3) y "Muy grande" (1.5).
// Ver docs/RESPONSIVE_TEST_PLAN.md.

import 'package:flutter_test/flutter_test.dart';

import '../support/arnes_responsivo.dart';
import '../support/dispositivos_prueba.dart';
import '../support/hallazgos_conocidos.dart';
import 'paginas_responsivas.dart';

void main() {
  for (final pagina in paginasResponsivas) {
    group(pagina.id, () {
      for (final dispositivo in dispositivosRepresentativos) {
        for (final escala in escalasTextoAccesibilidad) {
          testWidgets(
            '${pagina.id} se ve sin errores en ${dispositivo.descripcion} '
            'con texto x$escala',
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
