# Plan integral: pantallas adaptadas, API, sesión y Stripe

Fecha: 3 de octubre de 2026. Estado: **propuesta para revisión; no implementada en esta revisión**.

Este documento complementa y actualiza el alcance de [PLAN_RESPONSIVE.md](PLAN_RESPONSIVE.md). Los resultados previos de [RESPONSIVE_RESULTADOS.md](RESPONSIVE_RESULTADOS.md) no certifican que todas las pantallas estén aprobadas visualmente.

## 1. Qué se revisó y qué se puede afirmar

- Código Flutter local: navegación, contenedor responsive, acceso, nueva solicitud, perfiles, órdenes, pagos, cotizaciones, mensajes y notificaciones.
- Swagger de Azure consultado el 3 de octubre: **66 rutas y 75 operaciones**. Fuente: [OpenAPI en vivo](https://refanetwebapi-a4dhhqd0d7hseqds.westus2-01.azurewebsites.net/swagger/v1/swagger.json).
- Comparación de rutas con `docs/openapi_v1.json`: hay cuatro rutas adicionales en Azure: consulta del cliente, destinatarios, restablecimiento de contraseña y página de restablecimiento.
- No se encontraron proyectos `.csproj` ni código `.cs` del backend dentro de esta carpeta. No se verificaron configuraciones privadas de Azure, Stripe, base de datos, roles efectivos ni secretos.
- No se enviaron SMS, órdenes, cobros, webhooks ni modificaciones de datos a Azure. No se obtuvo ni generó un JWT real en esta revisión.

**Distinción necesaria:** una ruta publicada no demuestra que funcione correctamente; una respuesta sin esquema no demuestra que el servidor no devuelva datos. Los problemas históricos de `BACKEND_ISSUES.md` deben revalidarse: no se declaran vigentes automáticamente.

## 2. Qué significa que la pantalla se vea completa

Todo el contenido y todas las acciones deben ser visibles o alcanzables mediante un desplazamiento claro, con tamaños legibles. No deben quedar debajo de la navegación, cortados por el teclado ni fuera de un contenedor que no permita desplazarse.

Una conversación larga, muchos pedidos o un formulario con texto ampliado no pueden caber simultáneamente en cualquier pantalla sin hacerse ilegibles. Se mostrará completo el contenido disponible **sin perder secciones**, usando scroll cuando sea necesario. Las pantallas breves aprovecharán el espacio y mostrarán su composición completa cuando la altura lo permita.

No se aprobará una pantalla solo porque no arroje overflow, ni se ampliará toda la app proporcionalmente a los píxeles físicos. Flutter recomienda adaptar al espacio de la ventana, conservar estado y evitar estirar campos a todo el ancho de pantallas grandes. [Referencia de Flutter](https://docs.flutter.dev/ui/adaptive-responsive/best-practices).

### Problemas encontrados en el código actual

| Evidencia | Problema / tarea |
| --- | --- |
| `lib/app/widgets/responsive_scaffold.dart` | Ancho común de 1200 y cuerpo con altura forzada; en poca altura agrega scroll exterior. Revisar por tipo de página y evitar scroll anidado innecesario. |
| `lib/features/requests/presentation/new_request_page.dart` | Formulario limitado a 520 y estructura de pasos + cuerpo expandido + acción inferior. Diseñar composición amplia y verificar altura útil de cada paso. |
| `lib/features/auth/presentation/yonke_login_page.dart` | Formulario de 520 centrado, sin composición específica de escritorio. Revisar equilibrio entre logo, formulario y espacio libre. |
| `lib/features/orders/presentation/client_order_pages.dart` | Vistas de 640 con scroll; verificar resumen, acciones y estados, no asumir que todos quedan visibles por tener ListView. |
| `lib/features/messages/presentation/client_conversation_page.dart` | Conversación independiente; falta disposición lista + conversación en ventanas amplias. |
| Navegación cliente/Yonke | La barra móvil se conserva en escritorio. Definir navegación amplia equivalente, sin hamburguesa derecha y sin perder el botón central. |
| Galería de pruebas | Las 39 capturas base no cubren por sí solas editores, menús, diálogos ni todos los estados. Falta revisión visual individual completa y ejecución real en plataformas disponibles. |

### Distribuciones a implementar

Los cortes siguientes son iniciales y deben aprobarse por contenido, no por nombre del dispositivo:

| Espacio útil | Tratamiento |
| --- | --- |
| Menos de 600 de ancho lógico | Una columna; navegación inferior; tarjetas y formularios legibles. |
| 600–839 | Más margen y columnas en tarjetas/catálogos cuando caben; formularios de ancho cómodo. |
| 840–1199 | Tablet/multiventana; paneles relacionados donde aporten utilidad. |
| Desde 1200 | Navegación izquierda visible, dashboards por columnas, lista + detalle y lista + chat. Formularios centrados o con resumen lateral, no gigantes. |
| Menos de 480 de altura útil, en cualquier ancho | Priorizar tarea y campos; reducir decoración, habilitar scroll y revisar acción inferior/teclado. |
| TV | Perfil separado: lectura a distancia, foco y mando. Una ventana grande no certifica soporte nativo de TV. |

Medidas de partida: texto principal 16, ayudas 14, controles con altura aproximada de 48–56 y márgenes 16–48 según espacio. Son objetivos de diseño, no una regla de agrandar la tipografía por resolución. Respetar la ampliación elegida por el usuario.

### Inventario obligatorio de apartados

- Acceso: bienvenida, selección de rol, cliente/OTP/legal, login Yonke, registro, recuperación y restablecimiento.
- Cliente: Home, acciones centrales, solicitud en sus cuatro pasos y revisión, listados/filtros/detalles, cotizaciones/aceptación, orden/seguimiento/pago, mensajes/chat, yonkes/perfil del negocio, notificaciones, perfil/edición/foto/direcciones/ayuda/calificación.
- Yonke: Home, solicitudes/filtros/detalle, crear/editar/listar/ver cotizaciones, mensajes/chat, perfil/edición/logo, cobertura, contacto, horario/configuración/ayuda/notificaciones.
- Para cada apartado: carga, vacío, error, éxito, validaciones, contenido largo, imágenes, menús y teclado cuando correspondan. Incluir estados que hoy solo son diálogos.

### Matriz y ciclo de aceptación

1. Mantener el inventario amplio del plan responsive anterior, separando ventanas representativas y estrés.
2. Registrar ancho/alto **lógicos**, DPR, escala del sistema, texto, zona segura y espacio ocupado por navegador/teclado. No confundir resolución del panel con viewport.
3. Base representativa: celulares 320×568, 360×640, 390×844 y 430×932; tablets 600×960, 800×1280 y 1024×1366; ventanas de escritorio 1280×720, 1366×768, 1600×900 y 1920×1080. DPR y dimensiones físicas se registran por plataforma; no se deducen del nombre comercial.
4. Repetir vertical/horizontal, ventanas partidas y tamaño continuo; probar cada breakpoint a −1, exacto y +1. En monitores incluir ventana alta, ultrawide y escala del sistema.
5. Texto 100/130/150/200 %, zoom web separado, teclado, ratón, Tab/Enter/Escape y mando de TV donde esté disponible.
6. Por pantalla y perfil: captura antes → corrección → captura después → revisión visual al 100 % lógico → interacción → regresión. Capturar superior, intermedias e inferior si hay scroll, sin zonas omitidas.
7. Si falla, corregir y repetir ese caso antes de aprobar el siguiente. Hardware no disponible: **no verificado**, nunca aprobado por sustitución con PNG.
8. Aceptación: secciones y acciones alcanzables, texto cómodo, imágenes proporcionadas, foco y navegación correctos, sin espacio vacío desproporcionado ni pérdida de estado al rotar o cambiar tamaño.

## 3. Auditoría del API y pendientes reales

### Hallazgos confirmados por Swagger y código local

| Área | Ya existe | Qué falta / debe verificarse |
| --- | --- | --- |
| Sesión | Google, solicitar/verificar OTP y login Yonke; almacenamiento seguro e interceptor Bearer en Flutter. | Las respuestas de login solo documentan 200 sin esquema. Publicar DTO de sesión, expiración, usuario/rol y política de renovación. No hay ruta de refresh/logout publicada. |
| Cliente | `GET /api/ClienteAuth/{guidId}`; ya se usa como apoyo para resolver datos del cliente en conversaciones del Yonke. | El perfil editable propio sigue usando `LocalClientProfileRepository`. No aparecen operaciones de edición/foto/direcciones del cliente. Definir contrato y persistencia de servidor. |
| Solicitudes | Crear, consultar, cancelar con DELETE y body, imágenes, ciudades y envío a yonkes. | Documentar GUID real creado, relaciones, estados, límites de fotos, errores e idempotencia. Revalidar problemas históricos de GUID antes de quitar los rodeos de la app. |
| Destinatarios | `GET /api/SolicitudYonkes/solicitud/{solicitudGuidId}/destinatarios`. | Respuesta sin esquema; confirmar nombres, logo y estado de cada destinatario. La lista actual del Yonke **ya documenta marca, modelo, año, imágenes y ciudades**; no tratarlos como ausentes. |
| Catálogos | Marcas/modelos, entidades/ciudades; modelos filtrados por `marcaId`. | Las categorías/autopartes son locales; no hay catálogo de categorías publicado. Definir si siguen como ayuda local o pasan a catálogo API. No inventar una ruta. |
| Cotizaciones Yonke | Crear multipart, consultar/editar y total. | No aparece un listado específico de cotizaciones/conversaciones del Yonke; la app intenta dashboard y usa un registro local como fallback. Confirmar permisos del dashboard o agregar listados propios paginados. |
| Mensajes | Crear texto, historial, marcar leído y no leídos por cotización. | Bandeja global, contratos de estados/lectura, adjuntos y relación remitente/destinatario. El request publicado de mensaje solo admite GUID + texto; no hay subida de adjuntos de chat publicada. |
| Notificaciones | Registro de dispositivos; código push y vistas que derivan información de mensajes. | No se publica un historial general de notificaciones con leído/no leído. Definir eventos, persistencia, registro/desregistro y entrega a ambos roles; verificar SignalR/FCM. |
| Yonke | Registro, edición de datos/logo, cobertura y calificaciones. | Confirmar roles efectivos para autorregistro, lectura/escritura y que editar datos no borre autorización/configuración Stripe. Esa incidencia histórica requiere revisión del backend actual. |
| Contraseña | Forgot password, reset password y reset-password-page. | Completar/verificar experiencia de retorno a app y documentación; no declarar que reset no existe. |
| Órdenes | Crear, consultar por GUID/cotización y cancelar. | Respuestas sin esquema; catálogo de estados, autorización del cliente y reglas de aceptación/cancelación. Crear orden no equivale a pagar. |
| Pagos | Checkout, webhook, resultado y página de éxito. | Contratos de respuesta, integración de interfaz, retorno, reconciliación, permisos e idempotencia. Configuración privada no verificada. |

El OpenAPI declara Bearer como `apiKey` en Authorization y aplica seguridad global, incluso por herencia a login y webhook. Corregir su representación a HTTP Bearer y declarar excepciones apropiadas; esto es un problema de documentación, **no prueba de que el webhook actualmente exija JWT en ejecución**.

Publicar DTO pequeños de respuesta y errores 400/401/403/404/409/422/500, campos obligatorios, paginación y catálogos de estados. Separar ID entero interno, GUID de recurso y `sub` del usuario: ninguno debe sustituirse por otro por llamarse `id`.

### Contratos propuestos, no confirmados

- Sesión: `accessToken`, `expiresAt` o `expiresIn`, `userId`, `role`, `yonkeGuidId` para Yonke; `refreshToken` solo si el backend ofrece renovación.
- Orden: `ordenGuidId`, `cotizacionGuidId`, `estatus`, importes/moneda, fechas y acciones permitidas.
- Checkout: `sessionId`, `checkoutUrl`, `ordenGuidId`, caducidad y estado.
- Resultado: relación sesión/orden, `paymentStatus`, estado de orden e importes/moneda autorizados para ese usuario.

Los nombres se congelarán con el equipo del API antes de reemplazar parsers tolerantes. No se implementarán requests nuevos con rutas o JSON supuestos.

## 4. Stripe: lo que falta y cómo dejarlo preparado

### Evidencia actual

- Azure publica `POST /api/Pagos/checkout/{ordenGuidId}`, `POST /api/Pagos/stripe/webhook`, `GET /api/Pagos/resultado/{sessionId}` y `GET /pago/exitoso`.
- Ninguna de esas operaciones documenta el JSON de respuesta. El webhook tampoco declara su cuerpo/cabecera de firma en el contrato.
- Flutter tiene `PaymentsApi.createCheckout`, `PaymentsApi.getResult` y provider, pero **no se encontraron consumidores de esos métodos en las pantallas**. No hay todavía flujo completo de pago/retorno en navegación.
- La entidad Yonke publica campos de cuenta Stripe, pero no hay rutas publicadas de onboarding, estado Connect, reembolsos o liquidaciones. Podrían existir mecanismos internos: verificar antes de solicitar duplicados.

### Integración propuesta: Checkout alojado

Seguir el modelo que sugieren las rutas actuales: crear orden → solicitar checkout al backend → abrir URL HTTPS validada → regresar → consultar resultado. No introducir PaymentSheet/PaymentIntent nativo sin decidirlo con el backend.

Tareas Flutter:

- Crear modelos tipados, repositorio/controlador de pago y estados: preparando, pendiente, procesando, pagado, fallido, cancelado y sesión caducada.
- Añadir «Pagar orden» donde corresponda; mostrar precio, envío, total y moneda del servidor. Evitar doble toque y recuperar una sesión vigente según contrato.
- Abrir checkout con mecanismo compatible con web/Android/iOS; controlar bloqueo de popups y fallo de apertura.
- Definir rutas de retorno/deep links, permitir recuperar el pago tras cerrar/reabrir la app y actualizar estado al reanudarla.
- Consultar resultado y orden, con espera/reintento acotados mientras llega confirmación; no asumir pagado por volver a una URL de éxito.
- Sin configuración válida: mostrar estado explícito, no un cobro o éxito ficticio. Pruebas sintéticas solo en tests.

Tareas backend/Stripe:

- Configurar credenciales de prueba en almacenamiento seguro del servidor; confirmar moneda, importe calculado desde orden, envío, comisión y destinatario.
- Validar propiedad de orden y de sesión de pago. Reintentos e idempotencia deben impedir órdenes/cobros duplicados.
- Configurar webhook HTTPS, comprobar firma con cuerpo original y secreto del endpoint, procesar eventos repetidos de forma idempotente y persistir estado del pago/orden.
- Manejar éxito inmediato y diferido, fallo y expiración según métodos habilitados. El evento y `payment_status`, no el retorno del navegador, determinan cuándo confirmar un pago. [Stripe: confirmación y fulfillment](https://docs.stripe.com/checkout/fulfillment.md?payment-ui=stripe-hosted).
- Confirmar `success_url`, `cancel_url`, inclusión del identificador de sesión y recuperación segura del resultado por el usuario autorizado.
- Definir cancelación antes de pagar y reembolso después de pagar como operaciones distintas, según política del negocio.

### Si cada Yonke recibe dinero

Confirmar quién cobra y quién recibe el pago. Si la plataforma distribuye fondos entre yonkes, definir Stripe Connect, alta/verificación de cuentas, estado de cobros/liquidaciones, comisión y tratamiento de reembolsos. La presencia de `stripeAccountId` no demuestra que ese flujo esté completo. No se asumirá un modelo de cargos ni que la cuenta está habilitada. [Stripe: marketplaces y Connect](https://docs.stripe.com/connect/marketplace).

### No existe un único «token» que resuelva todo

| Elemento | Para qué sirve | Dónde debe estar |
| --- | --- | --- |
| JWT de cliente/Yonke | Autenticar al usuario frente a REFANET. | Emitido por backend; almacenado de forma segura en app. |
| Clave secreta Stripe `sk_…` | Backend llama a Stripe. | Solo servidor; nunca Dart, APK, navegador o repositorio. |
| Secreto webhook `whsec_…` | Verificar eventos Stripe. | Solo servidor; distinto de la clave de API. |
| Clave publicable `pk_…` | Integración cliente de Stripe si se adopta SDK/Elements. | Configuración cliente cuando corresponda; no necesaria automáticamente para abrir una URL de Checkout alojado. |
| Checkout `sessionId` | Identificar una sesión de pago. | App y servidor según contrato; no sustituye JWT ni acredita por sí solo el pago. |

Separar pruebas y producción. [Stripe: claves y entornos](https://docs.stripe.com/keys?locale=es-419). No pedir secretos por chat ni incluirlos en capturas/logs.

## 5. JWT real y acceso de prueba

- Confirmar respuesta real de login mediante cuentas autorizadas de prueba, sin exponer tokens en evidencia.
- Acordar roles y claims (`sub`, rol, expiración, identificador del Yonke), esquema Bearer, manejo de 401/403 y política de refresh o nuevo login.
- El frontend puede leer claims para presentación; el servidor valida firma, vigencia y permisos. Decodificar JWT en Dart no es validarlo criptográficamente.
- Nunca fabricar un JWT en Flutter ni poner la clave de firma en la app.
- Si se necesita entrar sin SMS: proponer endpoint **solo en entorno de desarrollo/pruebas**, con acceso limitado, cuentas/roles predeterminados y JWT real de corta duración firmado por servidor. Deshabilitado en producción y sin permitir elegir arbitrariamente identidad o rol.
- Confirmar formatos E.164 y países permitidos por backend/proveedor SMS; el selector visual no demuestra que se envíe OTP a Bolivia. No usar números ajenos.
- La app quedará preparada para consumir el contrato acordado, pero la emisión de JWT y los permisos exigen backend funcionando. No se prometerá que basta pegar un token.

## 6. Orden de ejecución y puertas de aceptación

| Fase | Trabajo | Para pasar a la siguiente |
| --- | --- | --- |
| 0. Contratos y entorno | Actualizar copia/versionado de Swagger; identificar backend desplegado, cuentas y entorno de prueba. Validar DTO/roles/estados/pagos; actualizar documentos antiguos. | Contratos críticos explícitos o bloqueos documentados; no inventar los faltantes. |
| 1. Sistema adaptativo | Revisar Scaffold/altura/insets/scroll; navegación por ancho y componentes compartidos. | Acceso, Home y formulario piloto aprobados en compacto, horizontal, tablet y escritorio. |
| 2. Todos los apartados | Inventario completo, layouts por función, menú/diálogos/estados; revisión antes/después. | Cada pantalla y perfil tiene evidencia visual e interacción; fallos corregidos. |
| 3. Cliente ↔ Yonke | Sesión, solicitud, destinatarios, cotización, aceptación/orden y mensajes/lectura. | Un flujo real en entorno de prueba mantiene mismos GUID, datos y estados en ambos roles. |
| 4. Stripe | Modelos, pantalla de pago, checkout, retorno y consulta; coordinación webhook/Connect si aplica. | Pago de prueba confirmado por backend, sin doble cobro y sin éxito ficticio. |
| 5. Regresión y entrega | Repetir tamaños/estados, análisis/build, sesiones caducadas, fallos de red y reinicios. | Informe separa probado, pendiente y no disponible; configuración pendiente enumerada. |

Se puede preparar infraestructura aislada con interfaces y fixtures de test durante un bloqueo del backend, pero no declarar la integración real terminada hasta resolverlo. Esta propuesta no autoriza publicar GitHub, desplegar Azure, modificar datos reales ni hacer cobros.

## 7. Pruebas funcionales obligatorias

- Crear solicitud sin fotos y con fotos propias; cancelar selección; imágenes cargadas/error; todos los pasos conservan valores al volver/rotar.
- Solicitud enviada a yonkes con cobertura correcta; comprobar GUID de solicitud, asignación al Yonke y cotización sin mezclarlos.
- Enviar/editar cotización desde Yonke; cliente ve precio, garantía, envío y fotos actualizados; aceptación crea una única orden.
- Mensaje en ambos sentidos; lectura reduce no leídos y persiste al recargar/reiniciar; llegada nueva no roba foco ni desplaza historial leído.
- Cambiar perfil/logo refleja resultado en los lugares relacionados; no sustituir persistencia remota por caché local. Dos cuentas no comparten caché privada.
- Pago exitoso, cancelado, rechazado, caducado, autenticación adicional y éxito diferido cuando aplique; reintentos, app cerrada, webhook repetido/retrasado y token caducado.
- Recuperación: confirmar resultado sin depender de datos pasados por `extra` en GoRouter; recargar página/deep link debe poder recuperar contexto permitido del servidor.
- Datos de prueba vinculados en ambos roles, exclusivamente en tests o entorno de prueba. Los totales pueden diferir legítimamente por cobertura, filtros y usuarios; no forzar números idénticos cuando representan cosas distintas.

## 8. Entregables y definición de «listo para conectar»

1. Registro por pantalla/perfil/estado: captura antes/después, geometría, revisión visual, interacción y limitaciones.
2. Código adaptativo por función y navegación coherente, sin cambios cosméticos que oculten funciones pendientes.
3. Matriz endpoint → pantalla → DTO → permisos → prueba, con estado confirmado/propuesto/bloqueado.
4. Cliente de sesión/pagos y pantallas conectados a contratos verificados; pruebas con red simulada y con entorno de prueba cuando esté disponible.
5. Plantilla de configuración con nombres y placeholders, sin secretos; instrucciones de API/JWT, retorno, Stripe, webhook y entornos.
6. Lista final de lo que debe aportar/configurar el backend: DTO, correcciones, credenciales seguras, URLs y cuentas. No reducir esa lista a «falta token» si hay funcionalidades ausentes.

«Listo para conectar» significa que el código y contrato están implementados y probados, y que solo faltan configuraciones identificadas. Si falta implementar un endpoint, webhook o política de pagos, el estado será **integración incompleta**, no «solo conectar».

## 9. Decisiones necesarias antes de habilitar pagos reales

- Quién cobra: REFANET, cada Yonke o plataforma con distribución; comisión y responsabilidad de devoluciones.
- Moneda y cálculo de envío/impuestos/totales desde servidor.
- Checkout alojado como base, o cambio explícito a pago nativo.
- Entorno backend de prueba disponible y acceso a su código desplegado.
- Disponibilidad de cuentas cliente/Yonke autorizadas; OTP internacional o acceso de desarrollo controlado.
- URLs definitivas de retorno y dominios de app links; configuración Stripe y cuentas habilitadas, gestionadas fuera del chat.

Estas decisiones no bloquean planificar ni corregir el responsive. Sí bloquean certificar una integración de cobros reales.

- [x] Revisión inicial de código local y OpenAPI de Azure.
- [x] Plan integral y hallazgos documentados.
- [ ] Aprobación de esta propuesta ampliada.
- [ ] Implementación y validación de las fases 0–5.

## 10. Ampliación de auditoría: API, seguridad y aplicación (3 de octubre de 2026)

Este apartado es un análisis estático y de contratos públicos, no una certificación de seguridad ni un pentest ejecutado. No se realizaron cobros, ataques, cambios en Azure, fuerza bruta, suplantación de usuarios ni consultas de información privada. «Confirmado» significa observado en código o documentación; «pendiente» significa que hace falta comprobar el servidor y no que exista una vulnerabilidad demostrada. P0 bloquea cobros o publicación segura; P1 bloquea una función fiable; P2 mejora mantenibilidad/experiencia. Las prioridades no equivalen a una puntuación CVSS.

### 10.1 Evidencias y límites de acceso

- Código revisado: carpeta local de la aplicación; contiene cambios sin publicar de múltiples funciones. No se debe tratar el último commit como representación completa de lo que está ejecutándose.
- Contrato público de Azure: 66 rutas y 75 operaciones observadas en `/swagger/v1/swagger.json`. Un endpoint documentado no acredita su implementación, autorización ni persistencia correcta.
- No existe proyecto .NET en esta carpeta. La consulta Git al repositorio indicado `ngamez84/YonkeWebApi` no logró autenticarse; no se pudo contrastar su código actual con el despliegue. No se extraerán credenciales de Chrome para resolverlo.
- `docs/BACKEND_ISSUES.md` contiene informes anteriores basados en otro repositorio/versión. Son pistas de revisión, no pruebas de que Azure conserve esos defectos.
- Los directorios locales de Antigravity `friendly-shannon` y `wise-kepler` no ofrecen actualmente archivos de aplicación en su checkout. Su estado Git indica `master`; esto no permite conocer las tareas o cambios de su sesión. No se asume que estén sincronizados con esta carpeta.
- Hay diferencias entre el inventario antiguo y Azure: ya existe consulta de cliente y un DTO de solicitudes con datos del vehículo. No seguir declarando esas dos capacidades como totalmente ausentes.

### 10.2 Hallazgos comprobados en la aplicación y el contrato

| ID / prioridad | Evidencia y problema | Solución prevista / criterio de cierre |
|---|---|---|
| APP-01 / P1 | `lib/core/storage/secure_token_store.dart`: `writeTokens` solo escribe refresh, expiración e identidad Yonke cuando llegan; no elimina los valores anteriores cuando faltan. Los login de cliente y Yonke lo llaman sin limpiar primero. Una nueva sesión puede heredar metadatos de otra. | Reemplazar la sesión como unidad; borrar opcionales ausentes, aislar identidad/rol y limpiar proveedores. Prueba: entrar como Yonke y después cliente sin refresh; no quedan identidad ni expiración anteriores. No se ha demostrado escalada de permisos del servidor. |
| APP-02 / P1 | `lib/features/messages/data/client_messages_repository.dart`: la excepción de `markMessagesRead` se captura y oculta. Haber mostrado el historial no garantiza que el servidor haya registrado su lectura. | Estado separado de sincronización, reintento limitado y actualización de contadores después de confirmación. Prueba con 401, 403, fallo de red y reapertura; el estado remoto debe persistir y no marcar mensajes de la otra persona. |
| APP-03 / P1 | `lib/features/yonke_messages/data/quote_client_resolver.dart`: caché estática por cotización, sin mecanismo explícito de limpieza en ese resolver. | Invalidación al cerrar/cambiar sesión y claves con identidad/entorno. Probar dos cuentas en la misma ejecución y cambios de perfil. Riesgo de datos obsoletos; no prueba de IDOR. |
| APP-04 / P1 | `yonke_quote_registry.dart`: registro local limitado a 200 IDs y recuperación de 30 por defecto; errores individuales se omiten. | Listado paginado del servidor como fuente de verdad, recuperación multiplataforma y errores visibles. Prueba con más de 30 cotizaciones, instalación limpia y dos dispositivos. El registro local solo será caché. |
| APP-05 / P0 antes de habilitar cobros | `PaymentsApi` y su proveedor existen, pero no tienen consumidores de pago en las pantallas revisadas. Crear una orden no completa Checkout ni verifica el cobro. | Conectar selección → orden → Checkout → retorno → consulta remota del estado. No mostrar «pagado» por crear orden o volver del navegador. Aplicar los criterios de la sección 4. |
| APP-06 / P1 | Perfil del cliente conservado localmente, aunque Azure publica GET de cliente. No se publica contrato de edición equivalente. | Integrar lectura remota y definir PUT/foto/direcciones con backend. No prometer sincronización de cambios locales entre dispositivos. Resolver conflictos e identificar campos solo locales. |
| APP-07 / P1 | Notificaciones se reconstruyen parcialmente desde mensajes/push; no hay contrato publicado de historial completo, lectura y paginación. | Definir persistencia de notificaciones y distinguir mensajes, cotizaciones y eventos de solicitudes. Totales y preferencias deben tener alcance por usuario. |
| APP-08 / P1 | Contrato publicado de mensajes admite texto; no publica envío de adjuntos de chat. | Definir carga/descarga autorizada, límites y DTO o deshabilitar claramente adjuntos; no simular envío exitoso de imágenes. |
| REL-01 / P0 de publicación | `android/app/build.gradle.kts`: release usa `signingConfigs.getByName("debug")`. | Firma de distribución fuera del repositorio, configuración de CI y prueba de artefacto release. No borrar ni reemplazar la clave de una app publicada sin plan de continuidad. |
| REL-02 / P1 | Manifest Android sin filtro de App Links; Info.plist revisado sin esquemas de retorno OAuth y Release.entitlements sin dominios asociados. | Configurar retornos Google/pagos según plataforma y verificar manifest/entitlements finales. Comprobar Apple y push por separado: no asumir que un botón implica integración. |
| API-01 / P1 | Swagger declara Bearer como `apiKey` y seguridad global sin excepciones documentadas de login/webhook. | Esquema HTTP bearer, respuestas y permisos por operación. Webhook utiliza firma Stripe, no sesión del cliente. Esto es una inconsistencia documental, no prueba de autorización real incorrecta. |
| API-02 / P1 | Órdenes, pagos y varias consultas solo publican 200 sin DTO suficientemente definido. | DTO estables, ejemplos anonimizados, errores 400/401/403/404/409/422/429 según operación, correlationId y contrato generado/probado. |
| API-03 / P1 | Mezcla de GUIDs, IDs internos y respuestas toleradas por parsers; cancelación DELETE documenta cuerpo de actualización de estado. | Especificar qué identifica cliente, Yonke, solicitud, asignación, cotización y orden. UUID validado y cancelación con contrato explícito, motivo y conflictos. Ningún cliente debe cancelar una cotización usando ID de solicitud. |
| API-04 / P1 | OpenAPI no publica renovación/revocación de sesión ni contrato completo de logout. | Acordar vida del JWT, expiración, revocación y refresh si corresponde. No inventar un endpoint ni tratar un token decodificado como validado. |

Buenas prácticas observadas que deben preservarse: URL de API HTTPS, Android `allowBackup=false`, almacenamiento de tokens encapsulado y ausencia de bypass TLS encontrado en el código revisado. Esto no certifica toda la aplicación. Una Activity launcher exportada no es por sí sola un fallo; un ID OAuth o `stripeAccountId` no es una clave secreta.

### 10.3 Revisión pendiente del backend: matriz de seguridad obligatoria

Realizar las pruebas siguientes en staging con autorización del propietario y cuentas controladas cliente A/B y Yonke A/B. No ejecutar contra producción usando cuentas ajenas. Registrar solicitud sanitizada, respuesta, identidad y resultado esperado; nunca publicar JWT, teléfonos, correos reales o archivos privados.

| Control / prioridad | Qué verificar y corregir | Prueba de aceptación |
|---|---|---|
| SEC-01 / P0 | JWT: firma y algoritmos permitidos, issuer/audience/lifetime, claves protegidas/rotación, claims de identidad y roles emitidos por servidor. | Rechazar tokens expirados, manipulados, de otra audiencia/entorno; no aceptar un JWT fabricado por la app. |
| SEC-02 / P0 | Autorización por objeto en solicitud, asignación, cotización, mensajes, orden, pago, imágenes, perfil y dispositivos. Obtener propietario desde sesión, no desde parámetros confiados. | A no puede leer/escribir recursos de B; Yonke solo recibe solicitudes asignadas o autorizadas. Todas las rutas relacionadas aplican la misma política. |
| SEC-03 / P0 | Autorización por función: catálogos CRUD, soporte, alta/aprobación Yonke y desactivaciones. No aceptar cambios de rol, estado de aprobación, cuenta Stripe o dueño mediante actualización de perfil. | Usuario común rechazado en operaciones administrativas; campos de solo servidor ignorados o rechazados. |
| SEC-04 / P0 | OTP/login/reset: TTL, uso único, límite por cuenta/IP/dispositivo, intentos fallidos, respuestas sin enumeración y protección frente a consumo de SMS. Política internacional explícita. | Código consumido no funciona dos veces; rate limit verificable sin pruebas masivas; no confirmar teléfono antes de validarlo. Bolivia requiere soporte real del proveedor o cuenta de staging, no un número mexicano inventado. |
| SEC-05 / P0 | Google: backend valida firma, `aud`, `iss`, expiración y usa `sub` estable; no confiar en email/ID enviado por la app. Credenciales de GitHub/Google no sustituyen JWT de REFANET. | Token válido para otro cliente OAuth o vencido no inicia sesión. Cuenta colaboradora GitHub no recibe privilegios de la API automáticamente. |
| SEC-06 / P0 pagos | Totales/precio/envío/moneda recalculados en servidor; dueño de orden; idempotencia; estados y transiciones transaccionales. | Reintentos no crean órdenes/cobros duplicados. Cotización rechazada/cancelada no se paga; importe del navegador no altera el total. |
| SEC-07 / P0 pagos | Webhook con cuerpo original, firma y secreto específico; eventos idempotentes, asociación orden/sesión y reconciliación. | Firma inválida no cambia estado; evento repetido/concurrente no duplica efectos; retorno exitoso sin confirmación no marca pagado. |
| SEC-08 / P1 | Archivos/logo: tamaño, tipo real, cantidad, permisos, nombre generado y almacenamiento no ejecutable; evitar confianza en extensión y rutas remotas arbitrarias. | Archivo inválido o privado ajeno rechazado; cambio de logo persistente y cache-busting sin borrar foto anterior antes de confirmar nueva. |
| SEC-09 / P1 | CORS restringido por entorno, TLS, cookies si existen, CSRF cuando corresponda; navegador no comparte garantías de Keychain/Keystore. | Origen no permitido no accede con credenciales; no guardar secretos Stripe/JWT de firma en Flutter/web. Evaluar XSS y estrategia de sesión web. |
| SEC-10 / P1 | SignalR: autorización de conexión/grupo, validación del JWT, reasignación de grupos al reconectar y caducidad. | Sesión ajena no se une a una cotización; desconexión/cambio de cuenta no deja grupos o contadores antiguos. Si el SDK usa token en URL, redactarlo en logs. |
| SEC-11 / P1 | Logs/errores/telemetría sin contraseñas, OTP, tokens, cuerpos privados o datos de tarjeta; trazabilidad sin exposición. | 500 sanitizado al usuario, correlationId utilizable por soporte y retención/acceso de logs definidos. |
| SEC-12 / P1 | Dependencias/SBOM, análisis de secretos en historia Git, mínimo privilegio Azure/GitHub/Google y separación test/live. | CI bloquea secretos y dependencias críticas con proceso de excepciones; claves filtradas se revocan, no solo se eliminan del último commit. |
| SEC-13 / P1 | Borrado/retención, dispositivos push por identidad, preferencias y descarga de datos. | Logout invalida asociación push cuando corresponde; no enviar mensajes privados a la cuenta anterior. Documentar borrado de cuenta y obligaciones comerciales. |

Estos controles siguen el enfoque de [OWASP API Security Top 10](https://api-security.owasp.org/editions/2023/en/0x00-header/). Comprobar un JWT no sustituye la [autorización por objeto](https://api-security.owasp.org/editions/2023/en/0xa1-broken-object-level-authorization/). Google describe la [validación del ID token en backend](https://developers.google.com/identity/sign-in/web/backend-auth); Stripe exige verificar el webhook con [cuerpo original y firma](https://docs.stripe.com/webhooks/signature).

### 10.4 Informes históricos a revalidar, no fallos actuales demostrados

Antes de cerrar backend revisar los informes antiguos sobre: creación de GUID; lógica de login/aprobación Yonke; actualización que reemplaza la entidad y puede perder configuración; cookie auth devolviendo 302 en API; posibles claves de firma expuestas; CRUD de utilidades sin permisos; propiedad de objetos; emisor de mensajes y destinatarios push; grupos SignalR; límites OTP; comparación de dueño al crear orden; asociación webhook/orden. Para cada informe: identificar commit original, comparar implementación actual, comprobar en staging y clasificar como corregido, vigente, no reproducible o no aplicable. Si se confirma una clave expuesta, rotar e invalidar sesiones afectadas y documentar el incidente de manera privada.

No publicar material explotable o secretos en GitHub. El plan contiene controles y referencias a archivos, no claves ni instrucciones para abusar de cuentas.

### 10.5 Qué falta terminar por función y qué debe aportar la API

| Función | Trabajo de aplicación | Trabajo de backend / configuración | Cierre exigido |
|---|---|---|---|
| Acceso cliente/Yonke | Manejo real de expiración, estados, logout y recuperación; separar demo de sesión real. | Contrato JWT y roles, OTP autorizado, Google, reset y aprobación Yonke. | Entrar/reabrir/cambiar cuenta sin herencia de datos; 401/403 distinguibles. |
| Solicitudes | Pasos conservan datos, fotos propias opcionales, catálogos dependientes, destinatarios y cancelar con confirmación. | IDs claros, cobertura, validación y estados de solicitud/asignación. | Pedido real del cliente aparece solo en Yonkes correspondientes; no insertar imágenes demo en pedidos del usuario. |
| Cotizaciones | Crear/editar/ver/aceptar con versiones, envío, garantía y fotos; listas paginadas completas. | Validar propietario, unicidad y edición según estado; historial de precio. | Cliente recibe cambios y aceptación produce una orden válida, no cotización desaparecida por una caché. |
| Órdenes/pagos | Lista, detalle, Checkout, retorno y reintento seguros; mensajes de pendiente/cancelado/pagado. | DTO, webhook, conciliación, política de cancelación, reembolso y distribución si aplica. | Flujo Stripe test completo, incluida app cerrada y evento repetido. |
| Mensajes | Historial, paginación, lectura confirmada, no leídos sincronizados, reconexión; adjuntos solo si soportados. | Propiedad, emisor real, orden de mensajes y persistencia de lectura; contrato de adjuntos pendiente. | Lectura permanece después de reinicio en ambos roles; no sumar mensajes propios como pendientes. |
| Perfil cliente | Lectura remota, edición/direcciones cuando exista contrato y aviso de campos locales. | Completar endpoints de actualización/fotos/direcciones y reglas de privacidad. | Misma información en otro dispositivo; ningún éxito ficticio cuando solo se guardó localmente. |
| Perfil Yonke | Validar edición y refrescar logo en perfil/listas/cotizaciones. | Respuesta actualizada, almacenamiento, cache-control y protección de campos financieros. | Reiniciar y comprobar logo/datos remotos; no modificar estado Stripe desde perfil. |
| Notificaciones | Historial real, lectura, preferencias y navegación al recurso autorizado. | Registro persistente, dispositivos, evento/tipo, paginación y lectura. | Contadores coherentes tras nueva sesión; no depender solo de memoria push. |
| Publicación | Firma release, enlaces, accesibilidad, teclado, escalado de texto y verificación de plataformas. | Dominios de retorno, configuración OAuth/Firebase/Stripe, salud y versión desplegada. | Artefactos Android/iOS/web verificados, sin accesos demo en producción. |

«No publicado en OpenAPI» no implica automáticamente «inexistente en backend»: pedir contrato o revisar implementación antes de desarrollar sustitutos. Stripe Connect, reembolsos y liquidaciones se implementan según modelo comercial elegido, no porque el DTO incluya campos Stripe. La clave secreta y el secreto webhook viven en backend; un token de usuario no reemplaza ninguno.

### 10.6 Responsive: corrección de la evidencia y de la aplicación

La pantalla debe adaptarse al espacio útil, no convertirse en una captura de teléfono reducida dentro de un lienzo enorme. No prometer que toda una lista extensa sea visible sin desplazamiento: lo exigible es contenido legible, navegación y acciones alcanzables, sin recortes ni espacios injustificados.

- Diferenciar resolución física, tamaño lógico, DPR, zoom y miniatura del visor. Un PNG 2880×5120 mostrado en una tarjeta pequeña no representa el tamaño de los controles en el dispositivo.
- Validar el ejecutable real, además de tests de widgets. Cada evidencia indica ventana lógica, DPR, orientación, texto, teclado, pantalla, estado y versión de app. No aprobar por cantidad de capturas.
- Móvil: una columna, campos cómodos y botones accesibles. Horizontal/ventana baja: scroll y teclado sin ocultar confirmación. Tablet/escritorio: redistribuir secciones, listas y detalles, no multiplicar el tamaño de fuente proporcionalmente a píxeles físicos.
- Pantallas amplias: contenido útil en columnas y anchura razonable para formularios; eliminar grandes áreas vacías accidentales. TV: validar distancia de lectura y foco por control remoto si se decide soportarla; tamaño de viewport por sí solo no demuestra soporte TV.
- Por pantalla verificar carga, vacío real, error, datos cortos/largos, más de una página, imagen ausente, texto al 200 %, navegación por teclado y cambio de orientación con borrador intacto.
- Si falla una combinación, detener su aprobación, corregir, recapturar y hacer regresión de tamaños vecinos. Registrar cobertura realmente revisada; las capturas históricas no inspeccionadas no cuentan como aprobadas.

### 10.7 Coordinación con Antigravity, Google y GitHub

1. Identificar una única fuente de contrato: OpenAPI exportado de la versión desplegada con fecha, hash y commit del backend. Registrar desviaciones, no actualizar silenciosamente mocks para ocultarlas.
2. Asignar propietario por bloque: sesión, API/DTO, pagos, responsive, mensajes, perfiles y pruebas. Antigravity y este trabajo no deben editar simultáneamente el mismo archivo sin acuerdo. Usar ramas y commits pequeños; conservar cambios locales ajenos.
3. Separar cuentas de colaboración GitHub, configuración Google OAuth y usuarios de REFANET. Definir permisos mínimos y propietarios de Google Cloud/Azure/Stripe; no reutilizar credenciales ni copiarlas a prompts.
4. Compartir un registro de decisiones: endpoint/DTO, evidencia, responsable, dependencias, commit, pruebas y estado. Revisar cambios del otro entorno antes de fusionar, sin asumir que otro agente terminó una función.
5. Añadir CI: analyze, tests de contratos y repositorios, pruebas visuales representativas, revisión de secretos y build release sin publicar. Pagos y seguridad requieren staging autorizado; los mocks no prueban backend.
6. Publicar solamente esta documentación en una rama de planificación del remoto `origin` (`cajacuenta767-sketch/rafael.net`). `upstream` es otro repositorio: no enviar cambios allí por asumir que una cuenta colaboradora autoriza ambos. No subir los múltiples cambios pendientes de app ni secretos de otros trabajos.
7. Después de aprobar, implementar por bloques con PR y evidencia. Subir un plan no significa desplegar backend ni habilitar pagos. Vulnerabilidades confirmadas sensibles se tramitan por canal privado del propietario.

### 10.8 Orden de ejecución y puertas de aceptación

- **A. Inventario/contrato:** versión Azure/backend, matriz completa de las 75 operaciones y responsable; revisar documentos antiguos. Salida: contratos y ausencias confirmadas, no inferidas.
- **B. Sesión/permisos:** APP-01, limpieza de caches, SEC-01 a SEC-05 y cuenta staging. Salida: dos roles y dos cuentas aisladas, pruebas negativas autorizadas y sin JWT ficticio.
- **C. Flujo comercial:** solicitudes → cotizaciones → aceptación → orden, estados y destinatarios. Salida: persistencia real entre cliente/Yonke y entre dispositivos.
- **D. Mensajes/perfiles/notificaciones:** lectura persistente, paginación, foto actualizada y contratos faltantes. Salida: reinicio y cambio de cuenta no rompen coherencia.
- **E. Stripe:** dueño/importe, Checkout, webhook, reconciliación y retorno; Connect solo si aplica. Salida: casos de test de éxito/fallo/duplicado/asincronía aprobados; nunca usar tarjetas reales en auditoría.
- **F. Responsive y release:** iterar todas las pantallas/estados con evidencia correcta, corregir firma/configuración. Se puede trabajar visualmente en paralelo, pero no certificar flujo E2E sin las puertas anteriores.

Cada hallazgo tendrá ticket con responsable, evidencia sin secretos, dependencia, cambio propuesto, prueba esperada y enlace al commit/PR. Una casilla se marca completada solo con evidencia de ejecución; «pendiente de configuración» debe indicar exactamente cuál. No hay aprobación final de seguridad, pagos ni responsive en esta revisión.

### 10.9 Configuración y decisiones que siguen pendientes

- Acceso autorizado al código .NET actual y confirmación del commit desplegado; entorno staging y cuentas de prueba de ambos roles.
- Modelo comercial, moneda, comisión, envío, cancelaciones, garantía, reembolso y responsables de atención.
- Configuración JWT del servidor y política OTP/Google; definir acceso boliviano o desarrollo aislado, sin bypass publicado.
- Stripe test, secreto webhook, URLs retorno y reconciliación; determinar necesidad de Connect y onboarding de Yonkes.
- OAuth por plataforma/dominio, firma Android de distribución, capacidades iOS y dispositivos push.
- Alcance real de TV/escritorio y criterios de accesibilidad. No confundir una captura sintética con certificación de dispositivo.
- Revisión de permisos de colaboradores y custodios de secretos, con autenticación ya autorizada; no solicitar contraseñas ni copiarlas desde Chrome.

## 11. Complemento de ejecución: contratos, reglas y pruebas concretas

Esta ampliación conserva íntegro el contenido anterior. No añade nuevos fallos comprobados: convierte los pendientes existentes en entregables verificables. Las propuestas de contratos deben acordarse con el backend actual antes de implementarlas.

### 11.1 Matriz completa de operaciones de la API

Crear una fila por cada operación del inventario verificado, no solamente por área funcional. Las 75 operaciones son la referencia de la revisión del 3 de octubre; actualizar el número si cambia el contrato desplegado.

Campos obligatorios: ID de operación, método/ruta, versión de contrato, pantalla o consumidor, rol permitido, regla de propiedad, parámetros, DTO de entrada/salida, campos obligatorios/nulos, errores, paginación, efecto sobre datos, prueba y resultado. Clasificar cada fila como documentada, implementada en app, probada con mock, probada en staging, bloqueada o no aplicable, registrando evidencia y responsable.

Cierre: ninguna operación utilizada por la app carece de contrato o prueba identificada; los endpoints no utilizados también se registran con motivo. Un resultado con mock no se presenta como verificación de Azure.

### 11.2 Mapa de identidades y relaciones

Documentar cliente → solicitud → asignación a Yonke → cotización → orden → sesión/pago, y la relación de conversación/mensajes con la cotización según el contrato real. No asumir cardinalidades ni que todos estos recursos comparten GUID.

Para cada entidad registrar: ID interno, GUID público, dueño, claves relacionadas, fuente de identidad y operaciones que aceptan ese identificador. Diferenciar `sub` del usuario, GUID del cliente y GUID del negocio. Mostrar ejemplos sintéticos consistentes, sin datos de personas reales.

Cierre: una solicitud creada puede rastrearse hasta su cotización, orden y conversación en ambos roles. Investigar recursos aparentemente desaparecidos comparando relaciones y estados del servidor, filtros y caché; no atribuirlos automáticamente a un fallo de backend.

### 11.3 Estados y acciones permitidas

Crear tablas independientes para solicitud, asignación, cotización, orden y pago. Cada transición indicará estado inicial/final, actor permitido, condición, endpoint, efecto en recursos relacionados, evento y respuesta de conflicto. Los nombres definitivos proceden del backend; los estados propuestos del plan no son un catálogo confirmado.

Definir explícitamente: edición de cotización después de aceptación, aceptación de una o varias ofertas, vigencia de precio, cancelación de solicitud con ofertas/orden, cancelación antes de pagar y reembolso después de pagar. Precisar qué ve cada rol y cómo se recalculan los contadores. La app muestra acciones permitidas, pero el servidor siempre vuelve a validarlas.

Cierre: toda acción visible tiene una transición autorizada; estados desconocidos se muestran como no reconocidos y no se convierten silenciosamente en «pendiente de pago».

### 11.4 Concurrencia y conflictos

Especificar el comportamiento al aceptar mientras se edita el precio, cancelar mientras se confirma un pago, aceptar desde dos dispositivos y recibir eventos duplicados o fuera de orden. Acordar versiones de recurso, comprobación transaccional o mecanismo equivalente; no imponer ETag sin confirmar soporte.

El servidor decide el resultado único, conserva la integridad comercial y devuelve un conflicto comprensible cuando corresponde. La app recarga la versión vigente, explica qué cambió y solicita una nueva decisión si cambia el total; no reenvía automáticamente una aceptación con condiciones distintas.

Cierre: pruebas concurrentes controladas demuestran que no hay órdenes duplicadas, cobros dobles ni sobrescritura silenciosa de condiciones aceptadas.

### 11.5 Recuperación de operaciones incompletas

Para crear solicitud, enviar mensaje, aceptar cotización, crear orden y abrir pago definir cómo recuperar una operación cuando el servidor pudo guardarla, pero la respuesta se perdió. Documentar claves de idempotencia, identificador de operación o consulta de recuperación cuando existan; si no existen, registrar la carencia del contrato.

Separar estados locales «enviando», «resultado desconocido», «confirmado» y «fallido». No tratar un timeout como prueba de que nada se guardó. Reintentar escrituras solo con garantías acordadas; conservar borradores y permitir consultar el estado al reabrir la app. Delimitar qué se permite sin conexión: no declarar aceptaciones o pagos completados de manera offline.

Cierre: interrumpir la respuesta después de persistir en staging y recuperar el mismo recurso sin duplicarlo. Los mensajes pendientes no se confunden con mensajes enviados.

### 11.6 Permisos por operación y por campo

Completar una tabla cliente/Yonke/soporte/administrador para cada endpoint, incluyendo acceso anónimo únicamente donde proceda. Añadir reglas por objeto y por campo: propietario, rol, aprobación, estados financieros, identidad de remitente, importes y configuración Stripe.

Las actualizaciones deben aceptar una lista explícita de campos editables. Documentar campos privados, de solo lectura y exclusivamente internos; evitar devolver entidades completas cuando exponen relaciones innecesarias. No considerar que un campo Stripe público es una clave secreta por su nombre.

Cierre: pruebas negativas autorizadas con dos cuentas por rol verifican tanto lectura como escritura. Ocultar un botón no cuenta como control de acceso.

### 11.7 Contrato de sincronización y coherencia

Por evento —solicitud creada, cotización editada/aceptada, mensaje recibido/leído, pago confirmado, perfil/logo modificado— registrar origen, destinatarios, recurso afectado, versión, listas/contadores que se invalidan y consulta de respaldo. Confirmar qué cubren SignalR, push y consultas HTTP; no asumir entrega garantizada.

Definir deduplicación, recuperación al reconectar, consulta al reanudar la app y limpieza de suscripciones/cachés al cambiar de cuenta. La información persistida en servidor prevalece sobre un contador optimista. Para logos/fotos, definir versión o URL actualizada y reglas de caché sin reemplazar datos remotos por imágenes demo.

Cierre: ambos roles convergen tras perder una notificación, reconectar o reiniciar; no se exige igualdad entre contadores que representan conjuntos distintos.

### 11.8 Ficha de adaptación por pantalla

Crear una ficha para cada pantalla, editor, diálogo y menú del inventario. Incluir ruta, rol, propósito, secciones obligatorias, acción principal, distribución compacta/intermedia/amplia, altura baja, vertical/horizontal, scroll y comportamiento con teclado abierto.

Especificar qué se redistribuye en columnas, qué conserva ancho de lectura, dónde permanece la navegación y cómo se accede a todas las acciones. Añadir contenido largo, carga, vacío, error, texto ampliado y cambio de tamaño con estado conservado. No resolver una pantalla grande reduciendo toda la interfaz a una miniatura.

Cada ficha registra viewport lógico, DPR, versión, estado probado, captura antes/después e interacción. Vertical y horizontal ya están contemplados y ahora deben concretarse por apartado. Hardware no disponible queda «no verificado».

Cierre: todas las fichas tienen evidencia legible y acciones alcanzables, no solamente una captura de la parte superior ni ausencia de overflow.

### 11.9 Escenarios reproducibles cliente ↔ Yonke

Preparar un conjunto de datos exclusivamente de staging/tests: clientes A/B, Yonkes A/B, coberturas distintas, solicitud con y sin fotos propias, ofertas con envío/garantía diferentes y conversación asociada. Registrar identificadores sintéticos, preparación, pasos, resultado esperado por rol y limpieza autorizada.

Escenario base: cliente A crea solicitud → reciben los Yonkes con cobertura → Yonke A cotiza → cliente consulta y acepta → se crea una única orden → pago Stripe test → estado confirmado por backend → mensajes y lectura persistente. Añadir edición, cancelación, pérdida de red, sesión caducada y segundo dispositivo.

Para cada paso definir tarjetas visibles, estados, importe, contadores y notificaciones esperadas. Cliente B y Yonke no asignado no acceden a recursos privados. Las imágenes demo solo pertenecen a fixtures, nunca se insertan automáticamente en solicitudes reales.

Cierre: el escenario se puede repetir desde una preparación conocida; toda discrepancia queda vinculada a un ID de hallazgo y evidencia, no se corrige maquillando los totales.

### 11.10 Secuencia única, responsables y seguimiento

Las secciones 6 y 10.8 se conservan como antecedentes. Para ejecutar se utilizará esta secuencia unificada:

1. Inventario, versión desplegada, staging y contratos; matriz de operaciones, IDs, permisos y estados.
2. Sesión, aislamiento de cuentas y seguridad crítica; cuentas de prueba y recuperación de operaciones.
3. Flujo solicitudes → asignaciones → cotizaciones → aceptación → orden, con conflictos y persistencia.
4. Mensajes, lectura, perfiles, logos, notificaciones y sincronización entre dispositivos.
5. Stripe: Checkout, retorno, webhook, reconciliación y política comercial; Connect solo cuando corresponda.
6. Validación integrada, responsive completo y release. El sistema adaptativo y las fichas visuales pueden trabajarse desde el inicio, sin esperar a pagos, pero no se aprobará una pantalla funcional únicamente con mocks.

Cada tarea tendrá responsable por confirmar, prioridad, dependencias, archivos/endpoint, criterio de aceptación, prueba, estado y commit/PR. No inventar asignaciones a colaboradores. Consolidar tareas repetidas manteniendo referencias a todas las secciones originales.

La frase de la sección 6 que no autoriza publicación describe el alcance de aquella propuesta inicial. La solicitud posterior del usuario sí autorizó publicar documentación en GitHub; no autorizó automáticamente desplegar Azure, cobrar o publicar todos los cambios de aplicación. El intento de publicación documental falló por autenticación y no se considera entregado en remoto.

## 12. Antigravity: coordinación pendiente y límites operativos

El usuario indica que Antigravity está instalado en su PC. Antes de proponer activarlo, comprobar mediante mecanismos permitidos si existe un ejecutable/CLI accesible, si está abierto y si ofrece una interfaz documentada para recibir tareas o compartir resultados. Abrir el programa no equivale a controlar su agente, utilizar su cuenta o combinar las cuotas de ambos productos.

Comprobación local de esta ampliación: se detectaron procesos `Antigravity` en ejecución, por lo que el programa ya está abierto. `Get-Command antigravity` no devolvió un comando disponible en PATH. Esto no descarta una CLI en otra ubicación ni demuestra una interfaz de control; la conexión automatizada sigue sin verificar.

- Si existe integración documentada y autorizada: acordar carpeta/rama, asignar un bloque acotado y revisar diff, contratos y pruebas antes de integrar. No permitir ediciones simultáneas del mismo archivo ni ejecución automática de cambios de producción.
- Si solo puede abrirse la aplicación: distinguir apertura de automatización. No afirmar que existe comunicación entre agentes porque el programa esté ejecutándose.
- Si no existe interfaz accesible desde esta sesión: preparar un encargo que el usuario pueda pegar en Antigravity y recibir el resultado mediante commits o documentación compartida; sin copiar credenciales ni conversaciones privadas.
- No acceder a contraseñas de Chrome, perfiles de autenticación ni mecanismos internos para reutilizar tokens. El inicio de sesión de Antigravity no autentica GitHub, Azure ni REFANET por sí solo.
- Registrar resultado de la comprobación y capacidades disponibles antes de marcar esta coordinación como activa. Esta sección no habilita por sí sola ninguna conexión ni modifica la aplicación.

## 13. Registro de ejecución

Ampliación del 4 de octubre de 2026: el backend ya fue recibido en ZIP. El [PLAN_CIERRE_BACKEND_APP.md](PLAN_CIERRE_BACKEND_APP.md) detalla la secuencia de compilación, compatibilidad, seguridad, flujo real, Stripe, adaptación y entrega, conservando este documento como antecedente. No representa trabajo implementado ni autorización automática de producción.

Ejecución iniciada el 3 de octubre de 2026. Consultar [PLAN_EJECUCION_ESTADO.md](PLAN_EJECUCION_ESTADO.md) para cambios implementados, resultados de pruebas y dependencias pendientes, y [MATRIZ_API_EJECUCION.md](MATRIZ_API_EJECUCION.md) para el inventario inicial. Esta anotación no marca el plan completo como terminado.
