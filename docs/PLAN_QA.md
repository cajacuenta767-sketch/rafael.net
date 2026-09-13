# Plan de QA — refaNet (cliente y yonke)

Revisión del 13 de septiembre de 2026 sobre `main` (16925e6) más las
correcciones de la rama `claude/detect-repo-changes-22mej3`. Cubre estado del
código, errores encontrados, funciones faltantes, plan de pruebas numerado y lo
que hace falta del propietario para ejecutarlo contra el servidor real.

## 1. Estado en una mirada

| Comprobación | Resultado |
|---|---|
| `flutter analyze` | Sin problemas |
| `flutter test` | 323 pasan, 0 fallan |
| CI en GitHub | Verde en esta rama; main sigue rojo hasta fusionarla |
| Endpoints del contrato | 56, de los cuales la app usa 34 |
| Pantallas registradas | 36 (23 cliente, 13 yonke) |
| Prueba total del API en vivo | No ejecutada: el servidor no es alcanzable desde este entorno |

## 1b. Resultado de la prueba de extremo a extremo (13 de septiembre)

`test/e2e_mock_server_test.dart` arranca la app de producción completa
(router, providers, repositorios, parsers y el cliente Dio real) contra
`tool/api_mock_server.py` por HTTP real, con fuentes Roboto reales y una
pantalla de 432×912 dp, y pulsa los botones de verdad. Resultado: **pasa**.

Recorrido verificado:

| Paso | Rol | Endpoints ejercidos | Resultado |
|---|---|---|---|
| Aceptar términos, pedir OTP, verificar 123456 | Cliente | solicitar-otp, verificar-otp | OK, token guardado |
| Nueva solicitud (pieza, marca, modelo, año, fotos, ciudad, revisión, enviar) | Cliente | marcas, modelos, entidades, ciudades, POST Solicitudes, SolicitudYonkes/enviar | OK, aparece en Mis solicitudes |
| Login, home con métricas, bandeja, detalle, cotizar $1500 | Yonke | YonkeAuth/login, mis-solicitudes, Solicitudes/{id}, vista, POST CotizacionYonke | OK, diálogo de éxito |
| Ver cotización, abrir chat y enviar mensaje | Cliente | mis-cotizaciones, CotizacionYonke/{id}, YonkesCalificaciones, mensajes, leer | OK, mensaje visible |
| Aceptar cotización, crear orden, calificar 5 estrellas | Cliente | POST Orden, POST YonkesCalificaciones | OK |
| Seguimiento y cancelar orden | Cliente | Orden/cotizacion/{id}, Orden/{id}, cancelar | OK, estado "Cancelada" |

Segunda prueba en el mismo archivo, pantallas secundarias (también pasa):

| Paso | Rol | Endpoints ejercidos | Resultado |
|---|---|---|---|
| Cobertura: marcar ciudad y guardar | Yonke | entidades, ciudades, YonkesCoberturas/guid, PUT YonkesCoberturas | OK, "Cobertura guardada" |
| Perfil con datos del API | Yonke | Yonkes/{guid} | OK |
| Bandeja de mensajes, abrir conversación, responder | Yonke | mis-cotizaciones, mensajes, POST mensaje | OK |
| Lista de cotizaciones, detalle, editar precio | Yonke | mis-cotizaciones, CotizacionYonke/{id}, PUT | OK, "Cotización actualizada" |
| Cerrar sesión | Yonke | local | OK, token borrado |
| Explorar yonkes y perfil público | Cliente | Yonkes/byPage, Yonkes/{id}, calificaciones, coberturas | OK |
| Notificaciones y bandeja de mensajes con la respuesta del yonke | Cliente | mis-cotizaciones, mensajes, no-leidos | OK |
| Cancelar solicitud desde la lista | Cliente | DELETE Solicitudes/{id} | OK, "Solicitud cancelada" |
| Perfil y cerrar sesión | Cliente | local | OK, vuelve al login |

Hallazgos que salieron de esta ejecución:

- **Botón "Enviar mensaje" del yonke no recibe el toque** en una pantalla de 432×912 dp: el centro del botón cae sobre el borde del compositor y la prueba tuvo que enviar con la acción del teclado. Verificar en dispositivo real (`yonke_messages_page.dart:529`).
- La conversación del yonke muestra "Pieza sin nombre" cuando la cotización no trae la solicitud anidada.

- **E4 confirmado en vivo.** La lista de cotizaciones del cliente mostró dos entradas para una sola cotización: la real del servidor ("Yonke prueba, $1500.50") y una duplicada "Yonke Test, Enviada" generada por `SessionSyncStore`.
- **E14 visible.** La pantalla de seguimiento muestra "La orden fue aceptada, pero la API aún no documenta todos sus datos" porque el contrato de orden sigue indefinido.
- **Desbordes de diseño solo con la fuente de pruebas.** Con la fuente cuadrada de flutter_test aparecen 6 desbordes (home del cliente, home del yonke, login, nueva solicitud). Con Roboto real desaparecen. No son errores de producción, pero esas filas no usan `Expanded`, así que con textos largos o escala de texto 1.3 podrían desbordar: `role_home_page.dart:234,306,468`, `yonke_home_page.dart:288`, `client_login_page.dart:143`, `new_request_page.dart:468`.
- El detalle de solicitud fija "Nogales, Sonora" como ciudad de respaldo (`request_detail_page.dart:102`) cuando el API no devuelve ciudades.

Lo que esta prueba no cubre porque depende del servidor real: formato exacto de las respuestas de Azure, OTP por SMS, autorización de yonkes, Stripe y notificaciones.

## 1b-bis. QA visual

La prueba de extremo a extremo guarda una captura de cada pantalla en
`build/qa/NN_nombre.png` (38 capturas, fuentes Roboto y Material Icons
reales). Para regenerarlas: `flutter test test/e2e_mock_server_test.dart`.
El informe con las imágenes y el veredicto por pantalla está publicado en
https://claude.ai/code/artifact/9a725459-6e31-4a90-973a-f42f94f7a1ab
(32 pantallas sin observaciones, 6 con observación de producto o contrato).

## 1c. Correcciones aplicadas en esta rama (13 de septiembre)

- **PR #2 integrado**: se elimina el modo prueba en memoria (`DevelopmentApiClient`, `SessionSyncStore`, botón "Ingresar en modo prueba"), todas las pantallas consultan solo el API real, cotizar y cancelar muestran el error real del servidor, los assets demo se retiran y las comparaciones visuales toleran el rasterizado entre plataformas. Cierra E1, E2, E3, E4, E6 y E7.
- **Pago con Stripe conectado (E5)**: nueva sección "Pago de la orden" en el seguimiento. "Pagar con Stripe" llama a `POST /api/Pagos/checkout/{orden}`, abre la URL devuelta en el navegador y "Ya pagué, verificar pago" consulta `GET /api/Pagos/resultado/{sessionId}`. El parser acepta varios nombres de campo porque Swagger no documenta el cuerpo, y muestra un error claro si el servidor no devuelve la URL. Archivos: `lib/features/payments/`, `client_order_pages.dart`.
- Ciudad fija "Nogales, Sonora" y menú lateral con datos ficticios ya no existen.
- Prueba de extremo a extremo actualizada con el flujo de pago; simulador devuelve el estado de cotización según el contrato.
- **Varias ciudades por solicitud (E10)**: la pantalla de ciudad admite selección múltiple; la primera es la principal y todas viajan en `ciudadesIds` y se aseguran en `SolicitudCiudades`.
- **Reintento sin duplicar (E11)**: si el envío falla después de crear la solicitud, "Reintentar" reanuda desde fotos o envío a yonkes con el `requestId` existente (`RequestSubmissionRepository.resume`).
- **Folio en el seguimiento**: se muestra el folio de la solicitud cuando el API lo devuelve; si no, un identificador abreviado en lugar del GUID completo.
- **Bloqueo de cancelación tras el pago**: con el pago confirmado desaparece "Cancelar orden" y se indica acordar el reembolso con el yonke.
- **"Pedir cotización" desde el perfil público del yonke**: abre la nueva solicitud.

Pendiente del backend para que el pago funcione en producción: claves de Stripe en el servidor, cuerpo documentado de checkout (URL y sessionId) y de resultado, y la URL de retorno que Stripe abrirá al terminar.

## 1d. Verificado contra el servidor real (Swagger, 13 de septiembre)

Respuestas reales obtenidas por el propietario desde Swagger:

- `GET /api/Utilerias/entidades`: solo existe **Sonora (id 1)**. Ciudades: 1 Nogales, 2 Hermosillo, 3 Agua Prieta, 4 San Luis Río Colorado. La app funciona; si se opera en otros estados hay que cargarlos en el servidor.
- `POST /api/Yonkes`: funciona; responde `data: "El yonke se creó correctamente."` (texto, sin guid). El servidor exige **LogoUrl** (máximo 2 MB, jpg/jpeg/png/pdf) aunque el contrato lo marca opcional. La app ya envía un logo por defecto y ahora valida tamaño y tipo al elegirlo.
- Formato de errores: validación como `errors: {campo: [..]}` (ProblemDetails) y errores de negocio como `error: [{status,title,detail}]`. La app interpreta ambos.
- `POST /api/ClienteAuth/solicitar-otp` con número no mexicano o con espacios: **500** "Ocurrió un error al procesar la solicitud" en vez de 400 con el motivo. Pendiente del backend.
- `POST /api/YonkeAuth/login` con credenciales inexistentes: 400 "Correo o contraseña incorrectos". Correcto.
- `POST /api/YonkeAuth/login` correcto: `{ token, yonkeGuidId, nombre, correo }` en la raíz; el JWT trae `sub`, `YonkeGuidId`, rol "Asociado" y caducidad de 30 días. El yonke recién registrado entra sin autorización manual. `correo` llega vacío (pendiente del backend, no afecta).
- `GET /api/YonkesCoberturas/guid/{id}`: `data: null` sin cobertura; con cobertura `data.yunkeHeader.yunkeCoberturas[]`. La app lo interpreta bien.
- `PUT /api/YonkesCoberturas`: funciona; devuelve `{ yonkeGuidId, ciudadesIds }`.
- **Bandeja del yonke** (`mis-solicitudes` con token de yonke): devuelve la solicitud plana (`Solicitud_Busqueda_DTO`: guidId, folio, marca, modelo, año, estatusSolicitud "Pendiente", totalCotizaciones, cerrada), no el registro `SolicitudYonkes`. La app la interpreta: usa `guidId` de la solicitud como identificador y "Pendiente" se muestra como "Nueva". Ya se confirmó que `PUT SolicitudYonkes/{id}/vista` y `POST CotizacionYonke?solicitudYonkeGuidId=` **no** aceptan ni ese guid ni el `guidId` de la fila (ver prueba decisiva). El simulador devuelve esta forma.
- **BLOQUEO CONFIRMADO (backend): el yonke no puede cotizar.** `PUT SolicitudYonkes/{id}/vista` responde 500 y `POST CotizacionYonke?solicitudYonkeGuidId=` responde 400 "La solicitud enviada al yonke no existe" cuando se usa el guid de la solicitud, y ningún endpoint accesible al yonke devuelve el guid del registro `SolicitudYonkes` (`mis-solicitudes` trae la solicitud plana; `Solicitudes/{guid}` igual; `AllPaged` exige `userId`; `resumen` solo trae `{ totalSolicitudes, totalCotizaciones }`). La app ya lee `solicitudYonkeGuidId` si llega y muestra un aviso claro mientras tanto. **Petición al backend**: en `GET /api/DashboardSuscriptores/mis-solicitudes` con token de yonke, incluir en cada fila `solicitudYonkeGuidId` (guid de SolicitudYonkes de ese yonke), o devolver los registros SolicitudYonkes con `solicitudes` anidada como indica el contrato.
- **Prueba decisiva sin celular (13 de septiembre, token de yonke en Swagger).** Se creó la solicitud `e3316a72-…` (SOL-00007/2026) *después* de que el yonke tuviera cobertura en Nogales, para descartar que el bloqueo fuera solo por SOL-00005 (despachada antes de existir el yonke). Resultados:
  - `POST /api/Solicitudes` con token de yonke: 200, `data` = guid como cadena. Exige `motor`, `transmicion`, `numeroParte` y `descripcion` no vacíos (la app ya los envía; `descripcion` ahora lleva "Sin descripción" por defecto). Sin token también responde 200, pero la solicitud queda sin dueño.
  - La solicitud aparece en `mis-solicitudes` **en el mismo instante de crearla** (`fechaCreacion` igual a la de creación): el despacho a yonkes con cobertura es automático al crear.
  - `POST /api/SolicitudYonkes/{guid}/enviar`: **500 sin cuerpo**, con y sin token, con solicitud recién creada. Segundo error de backend.
  - `GET /api/Solicitudes/{guid}`: 404 "No se encontró la solicitud" con token de yonke (busca por usuario cliente; no es bloqueo, solo rol).
  - `mis-solicitudes` devuelve en la fila un `guidId` (`d846c250-…`) **distinto** del guid de la solicitud (`e3316a72-…`). No es el guid de la solicitud.
  - `POST /api/CotizacionYonke?solicitudYonkeGuidId=d846c250-…` (el guid de la fila): **400 "La solicitud enviada al yonke no existe"**. Con el guid de la solicitud: mismo 400. `GET CotizacionYonke/vista/{guid}`: 500.
  - Conclusión: ninguno de los dos guids que el yonke puede obtener es aceptado por `CotizacionYonke`. El bloqueo es del backend y queda comprobado con una solicitud nueva y cobertura previa. Salvedad: la solicitud se creó con token de yonke (`usuarioId: "Test"`); el backend debe repetir la prueba con un cliente real y `enviar` para confirmar que no es un efecto del rol.
- **Listas paginadas** (`mis-solicitudes`, `Yonkes/byPage`, `AllPaged`): `data: { data: [...], meta: { page, take, itemCount, pageCount } }`. Se añadió `lib/core/network/paged_response.dart` y se unificaron los parsers; la bandeja del yonke usa `meta.pageCount` para saber si hay más páginas. El simulador devuelve esta forma.

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
- **QA-00.5** `flutter test test/e2e_mock_server_test.dart`: ciclo completo cliente ↔ yonke y pantallas secundarias por HTTP real contra el simulador. Pasan las dos pruebas.
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
