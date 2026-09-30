/// Fallos conocidos de la matriz responsive (`test/responsive/`).
///
/// Clave: `pagina@dispositivo` o `pagina@dispositivo@x1.3` (ver
/// `claveHallazgo` en `arnes_responsivo.dart`). Valor: razón del salto, que
/// debe empezar con el ID del hallazgo registrado en la tabla "Hallazgos
/// conocidos" de `docs/RESPONSIVE_TEST_PLAN.md`.
///
/// Reglas:
/// 1. Solo se agrega una entrada después de ver fallar el test y de anotar el
///    hallazgo en el documento. Nunca de forma preventiva.
/// 2. Una entrada por combinación página/dispositivo; no se saltan páginas o
///    dispositivos completos.
/// 3. Al corregir el layout se elimina la entrada y el test vuelve a correr.
/// 4. El tier de capturas (`capturas_test.dart`) nunca consulta esta lista:
///    la captura del problema se genera igual como evidencia.
const hallazgosConocidos = <String, String>{
  // inicio: RESP-13 (inicio no cabe con texto x1.5)
  'inicio@ipad-mini@x1.5': 'RESP-13',
  // cliente-login: RESP-14 (ingreso fijo no cabe con texto x1.5)
  'cliente-login@android-320@x1.5': 'RESP-14',
  // cliente-home: RESP-10 (filas sin Flexible en inicio de cliente)
  'cliente-home@android-320': 'RESP-10',
  'cliente-home@galaxy-s8': 'RESP-10',
  'cliente-home@iphone-14': 'RESP-10',
  'cliente-home@iphone-15-pro-max': 'RESP-10',
  'cliente-home@iphone-se': 'RESP-10',
  'cliente-home@pixel-7': 'RESP-10',
  'cliente-home@plegable-cerrado': 'RESP-10',
  'cliente-home@android-320@x1.3': 'RESP-10',
  'cliente-home@android-320@x1.5': 'RESP-10',
  'cliente-home@ipad-mini@x1.3': 'RESP-10',
  'cliente-home@ipad-mini@x1.5': 'RESP-10',
  'cliente-home@iphone-14@x1.3': 'RESP-10',
  'cliente-home@iphone-14@x1.5': 'RESP-10',
  'cliente-home@laptop-hd@x1.3': 'RESP-10',
  'cliente-home@laptop-hd@x1.5': 'RESP-10',
  // cliente-yonkes: RESP-12 (fila de tarjeta de yonke (menos de 1 px))
  'cliente-yonkes@android-320@x1.3': 'RESP-12',
  'cliente-yonkes@android-320@x1.5': 'RESP-12',
  // yonke-registro: RESP-11 (fila del formulario de registro)
  'yonke-registro@android-320': 'RESP-11',
  'yonke-registro@galaxy-s8': 'RESP-11',
  'yonke-registro@iphone-14': 'RESP-11',
  'yonke-registro@iphone-15-pro-max': 'RESP-11',
  'yonke-registro@iphone-se': 'RESP-11',
  'yonke-registro@pixel-7': 'RESP-11',
  'yonke-registro@plegable-cerrado': 'RESP-11',
  'yonke-registro@android-320@x1.3': 'RESP-11',
  'yonke-registro@android-320@x1.5': 'RESP-11',
  'yonke-registro@ipad-mini@x1.5': 'RESP-11',
  'yonke-registro@iphone-14@x1.3': 'RESP-11',
  'yonke-registro@iphone-14@x1.5': 'RESP-11',
  'yonke-registro@laptop-hd@x1.5': 'RESP-11',
  // yonke-home: RESP-06 (métricas de inicio de yonke)
  'yonke-home@android-320': 'RESP-06',
  'yonke-home@galaxy-s8': 'RESP-06',
  'yonke-home@iphone-14': 'RESP-06',
  'yonke-home@iphone-15-pro-max': 'RESP-06',
  'yonke-home@iphone-se': 'RESP-06',
  'yonke-home@pixel-7': 'RESP-06',
  'yonke-home@plegable-cerrado': 'RESP-06',
  'yonke-home@android-320@x1.3': 'RESP-06',
  'yonke-home@android-320@x1.5': 'RESP-06',
  'yonke-home@ipad-mini@x1.3': 'RESP-06',
  'yonke-home@ipad-mini@x1.5': 'RESP-06',
  'yonke-home@iphone-14@x1.3': 'RESP-06',
  'yonke-home@iphone-14@x1.5': 'RESP-06',
  'yonke-home@laptop-hd@x1.3': 'RESP-06',
  'yonke-home@laptop-hd@x1.5': 'RESP-06',
  // yonke-mensajes: RESP-15 (fila de bandeja de mensajes con texto x1.5)
  'yonke-mensajes@android-320@x1.5': 'RESP-15',
  'yonke-mensajes@ipad-mini@x1.5': 'RESP-15',
  'yonke-mensajes@iphone-14@x1.5': 'RESP-15',
  'yonke-mensajes@laptop-hd@x1.5': 'RESP-15',
};
