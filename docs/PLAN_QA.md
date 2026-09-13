# Plan de QA — refaNet (cliente y yonke)

Revisión del 13 de septiembre de 2026 sobre `main` (16925e6) más las
correcciones de la rama `claude/detect-repo-changes-22mej3`. Cubre estado del
código, errores encontrados, funciones faltantes, plan de pruebas numerado y lo
que hace falta del propietario para ejecutarlo contra el servidor real.

## 1. Estado en una mirada

| Comprobación | Resultado |
|---|---|
| `flutter analyze` | Sin problemas |
| `flutter test` | 290 pasan, 3 fallan (comparación visual por fuentes de Windows vs Linux) |
| CI en GitHub | Rojo desde el 8 de septiembre por esas 3 pruebas; el PR #2 lo corrige |
| Endpoints del contrato | 56, de los cuales la app usa 34 |
| Pantallas registradas | 36 (23 cliente, 13 yonke) |
| Prueba total del API en vivo | No ejecutada: el servidor no es alcanzable desde este entorno |

## 2. Errores encontrados, por gravedad

### Críticos (afectan a usuarios reales)

- **E1. Botón "Ingresar en modo prueba" visible en release.** `client_login_page.dart:899` no está protegido por `kDebugMode`. En release escribe un token falso de 30 días y la app queda "logueada" golpeando el API real con ese token. Las solicitudes creadas en modo prueba viven en memoria y nunca llegan a ningún yonke. El PR #2 elimina el modo prueba completo.
- **E2. Cotizar muestra "¡Cotización enviada!" aunque el servidor rechace.** `yonke_quote_page.dart:186-219` captura el error y muestra el diálogo de éxito igual. El yonke cree que cotizó y el cliente nunca recibe nada.
- **E3. Cancelar solicitud siempre dice "cancelada correctamente".** `my_requests_page.dart:110` y `request_detail_page.dart:196` tienen el `catch` vacío. Si el DELETE falla, la solicitud sigue viva en el servidor.
- **E4. Datos de sesión mostrados como si fueran del servidor.** `SessionSyncStore` sirve de respaldo en 8 pantallas (solicitudes, cotizaciones, bandejas de ambos roles). Cuando el API falla, el usuario ve datos viejos sin ningún aviso. Oculta fallos reales del backend durante QA.

### Altos (flujo de negocio incompleto)

- **E5. No existe pantalla de pago.** El contrato tiene checkout de Stripe y resultado de pago; la app crea la orden y termina ahí. `PaymentsApi` existe pero nadie lo usa.
- **E6. "Eliminar cotización" (3 lugares) solo borra en memoria.** No hay endpoint. La cotización reaparece al recargar.
- **E7. Menú lateral del yonke con datos ficticios.** `yonke_drawer.dart:60,79` muestra "Yonke El Profe · 4.8 (120) · ACTIVO" fijos en código. Además el archivo no se importa desde ningún sitio.
- **E8. Home del yonke traga todos los errores.** `yonke_home_page.dart:59` muestra la home vacía cuando el API falla, sin distinguir "sin datos" de "error".
- **E9. Filtros que no coinciden con la paginación.** Estado, ciudad y fechas en bandeja y cotizaciones del yonke se filtran en memoria sobre una página, porque el API solo acepta `Page`, `Search` y `CantidadRegistrosPorPagina`. Los resultados cambian según la página cargada.

### Medios

- **E10.** Solo se envía una ciudad por solicitud aunque el API acepta varias, y no se pueden editar después.
- **E11.** La pantalla de revisión bloquea el reintento tras un error de envío.
- **E12.** Confirmación de orden y calificación solo avisan errores con SnackBar, sin estado de error ni reintento.
- **E13.** `tipoRemitenteId = 1` para el cliente es un supuesto no confirmado por el backend; si es otro valor, los mensajes propios se muestran como ajenos.
- **E14.** "No disponible" del yonke se simula con una cotización de precio 0 porque no existe endpoint de rechazo. El cliente puede ver una cotización de $0.
- **E15.** Las capturas de prueba escribían en una ruta absoluta de Windows. Corregido en esta rama.

## 3. Funciones que faltan o están pendientes

| Función | Rol | Estado |
|---|---|---|
| Pago con Stripe | Cliente | Sin pantalla |
| Login con Apple | Cliente | Botón muestra "pendiente" |
| Eliminar cuenta | Cliente | No existe ni UI ni endpoint |
| Perfil, direcciones, métodos de pago | Cliente | Solo almacenamiento local; el API no publica perfil de cliente |
| Buscador de refacciones (`/cliente/buscar`) | Cliente | Sin endpoint; la pantalla no está enlazada en la navegación |
| Notificaciones push | Ambos | Sin Firebase; `registrar-dispositivo` y `YonkesDispositivos` nunca se llaman |
| Calificaciones recibidas | Yonke | Endpoint disponible, sin pantalla |
| Baja del yonke | Yonke | Endpoint disponible, sin botón |
| Horario de atención, ayuda y soporte | Yonke | Mensajes "pendiente" |
| Adjuntos en el chat | Ambos | El API solo acepta texto |
| Lista de yonkes destinatarios de una solicitud | Cliente | El API no la devuelve |

## 4. Plan de pruebas

Cada caso tiene un identificador para reportar resultados. Precondición general:
servidor de producción o staging accesible, un teléfono mexicano que reciba SMS
y un yonke de prueba autorizado con cobertura en la ciudad usada.

### Fase 0. Automatizado (sin datos del propietario)

- **QA-00.1** `flutter analyze` sin errores.
- **QA-00.2** `flutter test` completo en verde (requiere fusionar PR #2).
- **QA-00.3** `python tool/api_full_test.py` contra el simulador local: 67 pasos OK.
- **QA-00.4** Compilación release Android (`flutter build apk --release`) y confirmar que el botón de modo prueba no aparece.

### Fase 1. Contrato del API en vivo

- **QA-01.1** `python tool/api_full_test.py --phone=<num> --create-yonke` contra el servidor. Guardar `api_full_test_report.json`.
- **QA-01.2** Verificar que el login OTP devuelve un JWT con `sub` o `nameid` y expiración.
- **QA-01.3** Verificar que el login de yonke devuelve `yonkeGuidId`.
- **QA-01.4** Verificar que `mis-solicitudes` del yonke devuelve filas con `guidId`, `solicitudGuidId` y `solicitudes` anidado. Si no, la bandeja muestra "pendiente de conexión".
- **QA-01.5** Verificar que el checkout de Stripe devuelve una URL abrible y un `sessionId`.
- **QA-01.6** Confirmar con el backend el valor de `tipoRemitenteId` para cliente y yonke.
- **QA-01.7** Confirmar catálogo de estatus de solicitud, solicitud-yonke, cotización y orden.

### Fase 2. Cliente, camino feliz

- **QA-02.1** Inicio → "Soy cliente" → OTP → aceptar términos → home.
- **QA-02.2** Login con Google (requiere SHA-1 registrado en Google Cloud).
- **QA-02.3** Nueva solicitud: marca, modelo, año, pieza, 3 fotos (límite), ciudad, revisión, enviar. Verificar en el servidor que existe con imágenes y ciudad, y que se envió a yonkes.
- **QA-02.4** Mis solicitudes muestra la nueva; detalle carga fotos y ciudades; pull-to-refresh.
- **QA-02.5** Tras cotizar el yonke (fase 3), ver la cotización en "Cotizaciones" y en el detalle de la solicitud; ordenar por precio y garantía.
- **QA-02.6** Detalle de cotización: reputación del yonke, WhatsApp, llamada, mensajes.
- **QA-02.7** Chat: enviar mensaje, ver respuesta del yonke, no leídos, marcar leídos.
- **QA-02.8** Aceptar cotización → crear orden → éxito → seguimiento → cancelar orden.
- **QA-02.9** Calificar al yonke con 5 estrellas y comentario; verificar en perfil público del yonke.
- **QA-02.10** Explorar yonkes: búsqueda, filtro por ciudad, paginación, perfil público.
- **QA-02.11** Notificaciones: aparece "Nueva cotización" y "Mensaje nuevo".
- **QA-02.12** Cancelar solicitud desde lista y desde detalle; verificar que desaparece del servidor.
- **QA-02.13** Cerrar sesión y confirmar que el token se borra y las pantallas piden login.

### Fase 3. Yonke, camino feliz

- **QA-03.1** Registro de yonke con logo, estado y ciudad. Verificar si requiere autorización manual.
- **QA-03.2** Login; verificar que el home muestra métricas reales.
- **QA-03.3** Cobertura: seleccionar ciudades y guardar; recargar y confirmar.
- **QA-03.4** Bandeja: aparece la solicitud del cliente; pestañas Nuevas / En revisión / Cotizadas; búsqueda.
- **QA-03.5** Detalle: fotos, marcar vista, "No disponible" y "Cotizar".
- **QA-03.6** Cotizar con garantía, envío y una foto. Confirmar que llega al cliente.
- **QA-03.7** Editar cotización (precio, días); confirmar en el cliente.
- **QA-03.8** Mensajes: responder al cliente; pestaña no leídos.
- **QA-03.9** Perfil: editar datos y logo; verificar persistencia.
- **QA-03.10** Cerrar sesión desde perfil y desde menú lateral.

### Fase 4. Errores y casos límite

- **QA-04.1** OTP incorrecto, OTP vencido, reenvío con contador.
- **QA-04.2** Sin red durante envío de solicitud: debe mostrar error y permitir reintentar (hoy falla, E11).
- **QA-04.3** Servidor rechaza cotización (precio inválido): debe mostrar error, no éxito (hoy falla, E2).
- **QA-04.4** Servidor rechaza cancelación: debe mostrar error (hoy falla, E3).
- **QA-04.5** Token vencido: cualquier pantalla debe cerrar sesión y volver al login.
- **QA-04.6** Bandeja del yonke sin cobertura: mensaje claro, no "pendiente de conexión".
- **QA-04.7** Filtros del yonke con más de una página de resultados (E9).
- **QA-04.8** Imagen mayor al límite del servidor; formatos no PNG/JPG.
- **QA-04.9** Crear orden dos veces sobre la misma cotización.
- **QA-04.10** Modo avión al abrir la app con sesión guardada.

### Fase 5. Dispositivos y release

- **QA-05.1** Android físico: cámara, galería, WhatsApp, llamada, enlaces legales.
- **QA-05.2** iOS físico (requiere Mac y cuenta Apple).
- **QA-05.3** Tamaños 320×640 hasta 412×915 y escala de texto 1.3 (ya cubierto por pruebas automáticas del login).
- **QA-05.4** Build release firmada y verificación de que no hay logs de red.

## 5. Software sobrante y arquitectura

Borrar o mover:

- `lib/features/yonke_requests/presentation/widgets/yonke_drawer.dart`: no se importa en ningún sitio y contiene datos ficticios.
- `lib/features/payments/`: sin consumidores. Conservar solo si se implementa el pago.
- `cupertino_icons` en `pubspec.yaml`: cero referencias.
- `assets/images/refanet_logo.png`: no declarado ni usado.
- `assets/images/demo_*.png` (4 archivos, 9 MB): solo sirven al modo prueba y se empaquetan en producción.
- `lib/core/network/development_api_client.dart` (747 líneas) y `lib/core/storage/session_sync_store.dart`: modo prueba en memoria. El PR #2 los elimina.
- `linux/`, `macos/`, `windows/`, `web/`: la app es solo móvil y CI no compila esas plataformas.
- `tool/api_probe.dart` queda cubierto por `tool/api_full_test.py`; mantener uno.

Deuda estructural:

- Nueve copias del helper `_text()` y tres de `_isSafeImageUrl()` (una validación de seguridad) en distintos archivos. Mover a `lib/core/`.
- El mismo DTO de cotización se parsea de dos formas incompatibles (`client_quote.dart` lee `anio`, `yonke_quote.dart` lee `año`). Un cambio de contrato rompe un solo lado sin aviso.
- Controladores de perfil de cliente y yonke son clones de 45 líneas.
- `lib/core/di/api_providers.dart` importa 26 archivos de features: el núcleo depende de todo.
- `client_profile_page.dart` contiene cuatro páginas navegables en un archivo de 812 líneas.
- `catalogs`, `dashboard` y `payments` son APIs sueltas dentro de `features/` sin dominio ni presentación.
- `docs/` está congelado al 6 de septiembre y no refleja los últimos cambios.

## 6. Lo que necesito del propietario

Para ejecutar las fases 1 a 5 contra el servidor real:

1. **Acceso de red**: permitir el dominio `refanetwebapi-a4dhhqd0d7hseqds.westus2-01.azurewebsites.net` en el entorno de Claude Code en la web, o correr el script desde tu máquina y pegarme el informe.
2. **Un teléfono mexicano de prueba** que reciba SMS (para el OTP). Los códigos se piden por consola; no necesito el número por adelantado si lo corres tú.
3. **Credenciales de un yonke de prueba** ya autorizado, o confirmación de que el alta por API queda autorizada automáticamente.
4. **Respuestas del backend** a QA-01.6 y QA-01.7 (catálogos de `tipoRemitenteId` y de estatus).
5. **Stripe**: claves de prueba en el servidor y la URL de retorno / deep link que el backend usará para volver a la app. Sin esto no se puede construir la pantalla de pago.
6. **Google**: SHA-1 del keystore de debug y de release registrados en el proyecto de Google Cloud con el `serverClientId` que ya está en `app_config.dart`.
7. **Decisiones de producto**: identificador definitivo del paquete (hoy `com.example.app_yonke`), keystore de producción, cuenta Apple, icono final. Sin ellas no hay build de tienda.
8. **Confirmación de alcance**: ¿solo Android e iOS? Si sí, se eliminan las carpetas de escritorio y web.

## 7. Orden sugerido

1. Fusionar PR #2 y esta rama. Deja CI en verde, elimina el modo prueba y arregla las capturas.
2. Corregir E2 y E3 (falso éxito). Son dos `catch` y media hora de trabajo.
3. Retirar `SessionSyncStore` como respaldo silencioso (E4) o mostrar un aviso "datos sin actualizar".
4. Ejecutar fase 1 con el script y cerrar con el backend los puntos del contrato.
5. Construir la pantalla de pago (E5) cuando Stripe esté definido.
6. Limpieza de la sección 5 en un solo commit.
7. Fases 2 a 5 con dispositivos físicos.
