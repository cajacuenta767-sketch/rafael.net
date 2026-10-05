# Plan de cierre backend .NET + aplicación REFANET

Fecha: 4 de octubre de 2026. Estado: propuesto para ejecución. Complementa los planes existentes; no los borra ni declara finalizados.

## Prioridad de seguridad — regla para toda la ejecución

La seguridad bloquea la entrega: no se habilitan cobros ni se publica release como terminado si quedan fallos críticos de permisos, transiciones financieras o secretos. La compilación inicial sirve para preparar pruebas; después se atienden los controles críticos antes de cambios estéticos. Orden de prioridad: **pertenencia/roles y órdenes/pagos → sesión/OTP/archivos → recuperación y coherencia → adaptación visual → publicación**.

Cada mejora se registra como propuesta, implementada localmente, verificada localmente o verificada en staging. No llamar «corregido en Azure» a un cambio local. Consultar [MAPA_CAMBIOS_SEGURIDAD_CLIENTE.md](MAPA_CAMBIOS_SEGURIDAD_CLIENTE.md) para relación riesgo → componente → cambio → prueba y explicación para el cliente.

## 1. Objetivo y límites

Terminar un flujo coherente cliente → yonke → cotización → orden → pago → conversación, conservando la estructura del proyecto y verificando funcionalidad, seguridad y presentación. Cada corrección debe tener evidencia antes/después y una prueba que impida su regresión.

Backend disponible: `C:/Users/PC/Documents/YonkeWebApi_audit_20261004/YonkeWebApi-master`. App: `C:/Users/PC/Documents/app_yonke`.

La copia ZIP permite análisis y cambios locales, pero no contiene historial Git ni demuestra qué versión está en Azure. No se desplegará, ejecutarán migraciones sobre producción, enviarán SMS reales ni efectuarán cobros sin un paso específico autorizado y preparado. No leer contraseñas de Chrome ni incluir secretos en informes.

## 2. Arquitectura que se conservará

Backend: controlador ASP.NET Core → servicio de negocio en Core → interfaces/Unit of Work → repositorios y contexto en Infra. Mantener convenciones existentes de nombres, inyección, asincronía y CancellationToken. No realizar una reescritura arquitectónica como parte de correcciones puntuales.

App: pantallas y modelos por funcionalidad → repositorios → clases API → ApiClient/Dio, con Riverpod para dependencias y GoRouter para navegación.

- Controladores: autenticación, entrada/salida y códigos HTTP; evitar reglas financieras duplicadas.
- Servicios: pertenencia, reglas de negocio y transiciones de estado.
- Infra: persistencia, índices, transacciones y concurrencia.
- DTO: lista explícita de campos permitidos; no devolver entidades y relaciones innecesarias.
- App: representación, validación orientativa y recuperación; nunca autoridad final sobre roles, importes o pagos.

## 3. Secuencia de trabajo y aprobación

| Etapa | Prioridad | Entrega | Puerta de aprobación |
|---|---|---|---|
| A. Línea base | P0 | Compilación, arquitectura y configuración aislada | Errores previos identificados; sin conexión a producción |
| B. Contratos | P0 | Matriz backend/app/Azure y reglas de estados | Diferencias conocidas y IDs trazables |
| C. Seguridad crítica | P0 | Autorización y órdenes/pagos protegidos | Pruebas negativas y de concurrencia pasan |
| D. Flujo principal | P1 | Solicitud/cotización/orden persistentes | Ambos roles ven los recursos que les corresponden |
| E. Comunicación/perfiles | P1 | Historial, lectura, logos y notificaciones | Persisten y convergen tras reinicio/reconexión |
| F. Stripe test | P0 antes de cobros | Checkout/webhook/resultado/Connect verificados | Pago solo confirmado por servidor y eventos seguros |
| G. Adaptación visual | P1 | Revisión por pantalla y estado | Legibilidad e interacción aprobadas, no solo overflow |
| H. Release y entrega | P0 antes de publicar | CI, firma, cambios revisados y recuperación | Pruebas finales y despliegue staging aprobados |

Las tareas visuales pueden avanzar en paralelo a la revisión de contratos, sin afirmar que sus mocks prueban el servidor. No saltar una puerta crítica para marcar el plan como completo.

## 4. A — Preparación y línea base

- [ ] Inventariar solución, proyectos, referencias, migraciones, configuración y pruebas existentes.
- [ ] Registrar versión/hash de la copia y obtener posteriormente el commit remoto correspondiente; identificar commit/build desplegado en Azure.
- [ ] Revisar diferencias locales de Flutter y separar cambios del usuario de correcciones propias; no restablecer archivos ni publicar todo el directorio indiscriminadamente.
- [ ] Restaurar paquetes y compilar backend sin iniciarlo ni ejecutar código de inicialización contra bases reales. Registrar errores y advertencias relevantes antes de editar.
- [ ] Revisar paquetes y framework contra documentación/avisos oficiales vigentes al ejecutar; actualizar únicamente con justificación y pruebas de compatibilidad.
- [ ] Preparar configuración local/staging privada: base aislada, almacenamiento aislado y sustitutos de SMS/correo/push. Desactivar envíos reales en pruebas.
- [ ] Crear proyecto de pruebas .NET si no existe: unitarias de servicios y pruebas de integración HTTP/persistencia. No usar proveedor en memoria como única prueba de índices/transacciones SQL.
- [ ] Obtener línea base Flutter y backend, diferenciando fallos previos de regresiones nuevas.

Aceptación: compilación reproducible o bloqueos documentados, sin modificar datos remotos. Entrega: registro de comandos, versiones y resultados sin secretos.

## 5. B — Contratos, IDs y estados

- [ ] Comparar rutas, verbos, parámetros, DTO y respuestas de fuentes .NET, OpenAPI publicado y clases API Flutter. Actualizar matriz existente, no asumir que las 75 operaciones históricas siguen siendo las actuales.
- [ ] Mapear por separado UserId, YonkeGuidId, solicitud, asignación de solicitud a yonke, cotización, orden, pago, mensaje y sessionId Stripe. No intercambiar ID numérico, GUID, folio visible y referencia Stripe.
- [ ] Documentar qué rol crea/consulta/modifica cada objeto y la relación que acredita pertenencia.
- [ ] Confirmar IDs reales de estados con entidades, semillas y migraciones; reemplazar reglas ambiguas sin inventar nuevos IDs.
- [ ] Definir transiciones válidas de solicitud, cotización, orden y pago, incluyendo cancelación, caducidad, aceptación, reembolso y eventos tardíos.
- [ ] Acordar errores 400/401/403/404/409/429 y respuestas de negocio consistentes; no mostrar stack traces, SQL ni mensajes internos al usuario.
- [ ] DTO de perfil cliente, órdenes, Checkout y resultado: confirmar qué ya existe y completar solo brechas reales. La presencia de ClientePerfilDTO por sí sola no acredita endpoints funcionales.

Aceptación: pruebas de contrato cubren rutas utilizadas por la app, respuestas vacías/malformadas y errores. Cambios incompatibles requieren migración/versionado, no solo cambiar Flutter.

## 6. C — Seguridad crítica y fallos encontrados

### C1. Cancelación y transiciones de orden

Archivos iniciales: `Core/Services/Ordens/OrdenService.cs`, `YonkeWebApi/Controllers/Stripe/OrdenController.cs`.

- [ ] Impedir cancelación directa de orden pagada/completada/reembolsada según política aprobada; devolución es un flujo diferente.
- [ ] Validar propietario y estado en servicio y persistencia, no únicamente en botones Flutter.
- [ ] Definir comportamiento de cancelación repetida y solicitudes simultáneas.
- [ ] Proteger carrera cancelación/webhook: operación atómica o control de concurrencia; un pago válido no desaparece por una actualización tardía.

Pruebas: propietario válido, tercero, estado permitido/prohibido, cancelación duplicada y pago/cancelación concurrentes. Una transición rechazada no altera orden, pago ni inventario.

### C2. Retorno Stripe y consulta de resultado

Archivos: `PagosController.cs`, `StripePaymentService.cs`.

- [ ] Corregir retorno `/pago/exitoso`: visitar una URL no confirma pago; mostrar estado real, sin identificar innecesariamente PaymentIntent.
- [ ] Mantener autorización por propietario en resultado autenticado. Evaluar retorno anónimo mínimo, no eliminarlo a ciegas si forma parte de la redirección de Stripe.
- [ ] Eliminar comparación ineficaz `usuarioId != usuarioId`, conservando y probando el control posterior `pago.UsuarioId`.
- [ ] Mapear fallos de firma/validación/configuración a respuestas seguras; revisar qué errores deben provocar reintento del webhook.

### C3. Autenticación y autorización

- [ ] Revisar JwtBearer, Identity, esquemas por endpoint y middleware; comprobar que roles y UserId provienen de claims validados.
- [ ] JWT: firma, algoritmo permitido, emisor, audiencia, vigencia, gestión de claves y política de cierre/renovación/revocación.
- [ ] Google/Apple: validación de token externo, audiencia, emisor y nonce cuando corresponda. No aceptar identidad enviada como texto por Flutter.
- [ ] OTP y recuperación: límite por usuario/IP, uso único, expiración, intentos, cooldown y respuestas que eviten enumeración de cuentas.
- [ ] Pruebas locales/staging con clientes A/B y yonkes A/B: no acceder ni modificar recursos ajenos cambiando IDs; revisar soporte/admin por separado.
- [ ] Impedir actualización masiva de campos internos: rol, aprobación, propietario, StripeAccount, importes, estado financiero y remitente.
- [ ] Resolver aislamiento de sesiones y cachés, incluida exclusión mutua al escribir/borrar credenciales en Flutter.

### C4. Red, datos y archivos

- [ ] Restringir orígenes web necesarios en CORS, sin considerarlo sustituto de permisos.
- [ ] Exigir HTTPS en release y evitar que Dio adjunte Authorization a destinos externos.
- [ ] Revisar SignalR: permisos al entrar en grupos, token en URL/logs, reconexión y cambio de cuenta.
- [ ] Auditar secretos sin imprimir valores; rotar los realmente expuestos mediante procedimiento autorizado y configurar variables/almacén privado del servidor.
- [ ] Archivos: firma real, tamaño, extensión, nombre normalizado, permisos de lectura y almacenamiento seguro; rechazar contenidos inesperados en servidor.
- [ ] Límites de solicitudes, cuerpos, búsquedas, paginación y errores; pruebas de robustez acotadas en staging, nunca cargas agresivas en producción.

Aceptación C: hallazgos críticos cerrados con pruebas; riesgos residuales identificados. No prometer invulnerabilidad ni certificado de seguridad por pasar tests.

## 7. D — Flujo de negocio cliente ↔ yonke

- [ ] Catálogos reales de categoría/marca/modelo/año; validar relaciones en .NET y conservar IDs en Flutter.
- [ ] Solicitud con y sin fotos elegidas por usuario: ninguna imagen de prueba se agrega automáticamente.
- [ ] Asignación según cobertura y reglas reales; los contadores reflejan conjuntos distintos, no se igualan artificialmente.
- [ ] Cotización inicial y edición: pertenencia, precio positivo, envío/garantía, disponibilidad y restricción tras aceptación/pago.
- [ ] Aceptación crea una única orden; definir si varias cotizaciones de una misma solicitud pueden aceptarse o no y aplicarlo transaccionalmente.
- [ ] Evitar duplicados en reintento/concurrencia mediante índices e idempotencia apropiados; no basta consultar antes de insertar.
- [ ] Consultas paginadas de solicitudes/cotizaciones/órdenes sin registro local como única fuente; recuperación desde otro dispositivo.
- [ ] Cancelación de solicitud y efectos sobre asignaciones/cotizaciones/órdenes existentes, según reglas de negocio.

Aceptación: escenario reproducible con IDs registrados, reinicio de app y segunda sesión; los estados se recuperan desde servidor. Datos de prueba solo en entorno aislado y limpieza de recursos concretos autorizada.

## 8. E — Mensajes, perfiles y sincronización

- [ ] Historial ordenado y paginado; identidad de remitente derivada del token; autorización por conversación.
- [ ] Envío sin duplicación al reintentar, adjuntos autorizados y persistencia comprobada.
- [ ] Lectura persistida por destinatario; fallo visible/reintentable y contador correcto al recargar/reiniciar.
- [ ] SignalR/push como aviso, HTTP como recuperación; no asumir entrega garantizada. Recuperar tras desconexión y evitar suscripciones de otra cuenta.
- [ ] Registro Yonke, perfil editable, responsable/teléfono/dirección/logo y coberturas, validando campos permitidos y unicidad.
- [ ] Logo: confirmar guardado y nueva versión/URL o política de caché; probar al volver, reiniciar y usar segundo dispositivo.
- [ ] Perfil cliente: revisar servicios existentes, completar API necesaria y migrar datos locales con reglas explícitas, sin mezclar cuentas.
- [ ] Notificaciones y preferencias de lectura persistentes; no mostrar acciones inexistentes como exitosas.

Aceptación: ambos roles convergen a datos del servidor tras recargar; lectura y perfil no dependen solo del estado de un widget.

## 9. F — Stripe y Connect, exclusivamente test inicialmente

Stripe ya está implementado. Primero auditar y corregir, después integrar/completar la app; no duplicar servicio de pagos.

- [ ] Revisar política comercial: moneda MXN, comisión, base de cálculo, envío, redondeo, reembolsos y responsabilidad de cargos. Confirmar reglas antes de cambiar el 10 % existente.
- [ ] Claves test/webhook privadas en backend; configuración pública mínima en cliente. Una clave JWT no sirve como clave Stripe.
- [ ] Checkout: orden autorizada, estado permitido, importe calculado en servidor e idempotencia estable; gestionar sesión vigente, expirada y reintentos.
- [ ] Connect: revisar onboarding existente, capacidades y estado efectivo de cuenta con Stripe; un booleano en la base no garantiza habilitación para recibir fondos.
- [ ] Webhook: firma del cuerpo original, persistencia de eventos, duplicación, transacción, eventos fuera de orden y no degradar un pago confirmado con un fallo antiguo.
- [ ] Validar importe, moneda y vínculo orden/pago/sesión antes de confirmar; revisar pagos asíncronos, reembolso parcial/total y disputas según el alcance comercial.
- [ ] Flutter: abrir destino HTTPS esperado, manejar retorno/cancelación y consultar resultado autorizado. No confirmar por query string ni por pantalla de éxito.
- [ ] Reconciliación y recuperación tras caídas: evento recibido antes/después de guardar Checkout, consulta periódica segura y trazabilidad sin secretos.

Pruebas mínimas: exitoso, rechazado, abandonado, pendiente, webhook inválido, duplicado, tardío, caída de red, creación simultánea, Connect no habilitado y reembolso. Sin tarjeta real ni cobro de producción.

Aceptación: única orden/pago esperado, importes coherentes y estado persistido por servidor; resultado accesible solo por usuarios autorizados según política.

## 10. G — Adaptación y revisión visual por pantalla

- [ ] Aplicar inventario/fichas del plan responsive a todas las pantallas cliente y Yonke, diálogos y formularios.
- [ ] Probar tamaños lógicos, DPR y escala de texto por separado; no confundir píxeles físicos con área útil.
- [ ] Vertical/horizontal, altura corta, teclado abierto, safe areas, cambio de tamaño y conservación de borradores.
- [ ] Celulares compactos/grandes, tablets, laptop, escritorio y ultrawide; TV exige foco/mando y distancia de lectura, no solo captura grande.
- [ ] Reorganizar contenido en columnas cuando proceda, conservar anchos legibles y acciones alcanzables; scroll permitido para contenido largo, no miniaturizar toda la pantalla.
- [ ] Carga/vacío/error/contenido largo/fotos ausentes/texto ampliado; contraste, etiquetas accesibles y objetivos táctiles.
- [ ] Inspeccionar captura individual a escala apropiada, interactuar, corregir y repetir antes de aprobar. Hojas de miniaturas y ausencia de overflow no son aceptación visual.
- [ ] Distinguir capturas de widgets simulados de app compilada y dispositivos reales. Hardware no disponible queda no verificado.

Aceptación: ficha de cada pantalla con tamaño, estado, evidencia y acciones comprobadas. No marcar 468 capturas como 468 revisiones visuales aprobadas.

## 11. H — CI, GitHub, staging y entrega

- [ ] Integrar cambios en repositorios correctos y ramas acotadas; recuperar historial/backend remoto antes de publicar una copia ZIP como sustituto.
- [ ] CI backend: restore/build/unitarias/integración aislada/contratos. CI app: formato/análisis/pruebas/build según plataforma.
- [ ] Actualizar OpenAPI y documentación, configuraciones de ejemplo sin secretos y migraciones con impacto y procedimiento de recuperación.
- [ ] Revisar diffs; no publicar archivos de configuración privada, ZIP, base, capturas con datos personales o cambios ajenos.
- [ ] Desplegar primero staging autorizado; confirmar versión, salud, migraciones, permisos, almacenamiento, callbacks y webhooks.
- [ ] Ejecutar checklist E2E y pruebas de regresión finales sobre esa misma versión. Registrar fallos y repetir después de corregir.
- [ ] Release Android firmado con clave del propietario; iOS y hardware no disponibles no se declararán verificados.
- [ ] Preparar rollback de aplicación y recuperación compatible de datos; no hacer rollback SQL destructivo automático de pagos.
- [ ] Solo después, preparar publicación/producción mediante autorización específica y configuración live separada.

## 12. Lo que puedo avanzar y lo que necesitamos

**Avance local:** lectura de fuentes, compilación, proyecto de pruebas, correcciones de servicios/controladores/app, contratos, documentación y revisión visual. Usar dependencias simuladas o base local aislada para no tocar servicios reales.

**Necesario para cierre remoto:** autenticación GitHub con acceso a ambos repositorios; referencia del commit desplegado; staging y base/storage aislados; cuentas autorizadas cliente/Yonke; configuración Stripe test/Connect/webhook y acceso al proceso de despliegue. Los secretos se configuran privadamente, no se piden por chat ni se guardan en el plan.

Decisiones comerciales pendientes se registran y no se inventan: transiciones definitivas, comisión, reembolso y aceptación de varias ofertas. Se puede avanzar con controles conservadores y pruebas locales, pero no afirmar implementación final de reglas no acordadas.

## 13. Registro de ejecución y definición de terminado

Cada tarea: ID, prioridad, estado (pendiente/en curso/corregida/verificada/bloqueada), archivos, evidencia, prueba y resultado, riesgo residual y commit/PR cuando exista. Los resultados históricos no sustituyen pruebas tras una nueva modificación.

El cierre exige:

- [ ] Backend y app compilables, suite final aprobada y contratos compatibles.
- [ ] Escenario real de ambos roles y permisos negativos verificados en staging.
- [ ] Sin hallazgos críticos abiertos; riesgos restantes explícitos y aceptados por responsable.
- [ ] Pagos test y recuperación consistentes, sin confiar en UI como confirmación.
- [ ] Todas las fichas visuales del alcance aprobadas o excepciones explícitas.
- [ ] Cambios revisados en GitHub, versión desplegada identificada y procedimiento de entrega/recuperación preparado.

Primer bloque recomendado: **A → B → C1/C2**, empezando por compilación y pruebas de cancelación/resultado de pago. No modificar producción para descubrir si una corrección funciona.

## 14. Ampliación tras segunda revisión de fuentes y API — 4 de octubre de 2026

Se volvió a consultar únicamente el Swagger público de Azure: **75 operaciones**. Incluye lectura de perfil en `GET /api/ClienteAuth/{guidId}`, órdenes, pagos y cuatro operaciones de mensajes. Esto acredita rutas publicadas, no correspondencia de código desplegado ni permisos efectivos. Las comprobaciones siguientes se basan en la copia ZIP; no se realizaron intentos de acceso ajeno, SMS o pagos en producción.

### 14.1 Nuevos bloqueos prioritarios, con evidencia y aceptación

| ID | Evidencia en fuentes | Trabajo a agregar | Prueba de cierre |
|---|---|---|---|
| BSEC-01 / P0 | CotizacionYonkeService.RegistrarCotizacionAsync guarda `UsuarioId = _currentUserService.UserId`; OrdenService.CrearDesdeCotizacionAsync exige que ese mismo campo y el usuario de la solicitud sean el cliente que acepta | Definir creador Yonke, propietario cliente y asignación como relaciones distintas; comprobar que el asociado pertenece al Yonke asignado al cotizar; ajustar autorización, DTO y consumidores, sin cambiar significado de datos históricos a ciegas | Yonke A cotiza para cliente A; cliente A acepta; cliente B y Yonke B no pueden; datos históricos compatibles |
| BSEC-02 / P0 | ObtenerMensajesAsync recibe usuarioId pero no lo usa para autorizar; repositorio filtra solo por GUID de cotización. Leer/no-leídos filtran remitente distinto pero no pertenencia. Controlador solo exige roles y usuario identificado | Añadir validación común de participantes en las cuatro operaciones y al entrar en grupos SignalR; no basta excluir mensajes del propio remitente | Tercero autenticado no consulta historial/conteo ni modifica lectura; denegación sin cambios persistidos |
| BSEC-03 / P0 | EnviarMensajeAsync etiqueta cotizacion.UsuarioId como Cliente y usuario de solicitud como Yonke, mientras la creación guarda al usuario que cotiza | Derivar remitente del participante real y rol autorizado, no de etiquetas inconsistentes; revisar destinatarios push | Mensaje Yonke aparece como Yonke en ambos lados y viceversa; push llega al destinatario, no al emisor |
| BSEC-04 / P1 | ClienteOtpService.GenerarCodigo usa Random.Shared y CodigoHash usa SHA256 del código corto sin contexto secreto | Usar generador criptográfico; revisar hash/HMAC con secreto servidor, comparación segura, rotación y uso único atómico; no limitarse a cambiar longitud | Código de seis dígitos; no se reutiliza; verificaciones simultáneas dan un solo éxito; hash almacenado no es OTP en claro |
| BSEC-05 / P1 | SolicitarOtpAsync crea cliente con TelefonoConfirmado=true antes de verificar; ya existen expiración de cinco minutos y bloqueo tras cinco fallos | Confirmar teléfono únicamente después de verificar, corregir semántica histórica con cuidado; añadir cooldown/cupo de emisión independiente de intentos y recuperación de fallo SMS | Solicitar no confirma identidad; verificar sí; reenvíos simultáneos no eluden límites ni facturan SMS ilimitados; pruebas con emisor falso |
| BSEC-06 / P1 | ExceptionMiddleware captura cualquier excepción como 500 y entrega exception.Message en Errors | Revisar pipeline realmente registrado; mapear excepciones conocidas y ocultar detalle interno de errores inesperados; traceId y logs privados | Permiso denegado retorna 403 apropiado; validación no se disfraza de 500; error SQL no se devuelve al cliente |
| BFUN-01 / P1 | Mensaje se guarda antes de enviar Firebase/SignalR; un fallo posterior puede producir respuesta fallida aunque el mensaje exista | Separar confirmación persistida de entrega de notificaciones; outbox/reintento durable o estrategia compatible con Unit of Work; deduplicación de envío | Caída de push no pierde mensaje ni hace duplicarlo al reintentar; aviso pendiente recuperable |
| BFUN-02 / P1 | Listado de mensajes usa ToListAsync sin límite/página | Añadir paginación estable y límite máximo, cursor/orden con desempate de ID e índice apropiado | Conversación larga sin carga completa; nuevas entradas no duplican/saltan mensajes al paginar |

Estos puntos describen inconsistencias/ausencia de controles en métodos inspeccionados. La exposición efectiva de Azure y todos los caminos alternativos se validarán en staging. No son correcciones ya aplicadas.

### 14.2 Perfil cliente: corregir alcance, no duplicar endpoints

- [ ] Reconocer la lectura existente `GET /api/ClienteAuth/{guidId}` y su DTO público; no seguir afirmando que no existe ninguna consulta de cliente.
- [ ] Revisar campos que devuelve, acceso por participante y propósito público/privado; no añadir contacto privado a lectura pública.
- [ ] Confirmar si existe lectura propia completa y actualización autorizada; si falta, proponer contrato diferenciado compatible, no crear un duplicado de perfil público.
- [ ] Cambiar LocalClientProfileRepository por adaptación remota solo después de acordar endpoints; migrar nombre/direcciones locales por cuenta con aprobación, sin enviar automáticamente datos de otra sesión.
- [ ] Actualizar comentarios y documentos históricos que atribuyen ausencia absoluta de perfil a un contrato anterior.

### 14.3 Datos históricos, migraciones y compatibilidad hacia atrás

- [ ] Antes de corregir UsuarioId, inventariar qué significan los registros existentes y dónde se usan en órdenes, mensajes, DTO y notificaciones. Preparar migración explícita si hace falta separar campos; nunca reasignar identidades masivamente por suposición.
- [ ] Detectar y tratar estados financieros contradictorios, duplicados y teléfonos confirmados sin verificación con reporte y procedimiento aprobado, sin borrar evidencia financiera.
- [ ] Probar restricciones e índices con SQL aislado; registrar versiones de esquema y migraciones realmente aplicadas. Un índice en DbContext no acredita que esté desplegado.
- [ ] Prueba de app anterior contra API nueva y app nueva contra API compatible; cambios de DTO aditivos primero cuando sea viable. Definir cuándo deja de soportarse una versión antigua.
- [ ] Copia/restauración verificadas, acceso mínimo y procedimiento de recuperación antes de migraciones de producción.

### 14.4 Amenazas, límites de pruebas y privacidad

- [ ] Crear inventario de activos: JWT/OTP, contacto/dirección, fotos, conversaciones, órdenes/importes, secretos Stripe y roles soporte.
- [ ] Mapear fronteras de confianza: dispositivo no confiable → API → base/blob → Stripe/SMS/push; registrar actor, amenaza, control y prueba para cada flujo.
- [ ] Definir alcance escrito de staging: recursos/cuentas, horarios/cupos, límites de peticiones, exclusiones y criterio de detener pruebas. Prohibidos fuerza bruta real, cargas agresivas y cobros reales en esta revisión.
- [ ] Retención/minimización de OTP, IP, dispositivos push, archivos y mensajes; eliminación de cuenta con obligaciones financieras, según requisitos que confirme el responsable. No inventar plazos legales.
- [ ] Auditar descargas, URL de imágenes, metadatos y vistas previas: el permiso de API no basta si el blob privado queda expuesto por URL pública permanente.
- [ ] Mensajes no deben aparecer íntegros en push/pantalla bloqueada sin política de privacidad adecuada; redacción de logs y datos de capturas.
- [ ] Enrutamiento/deep links, URLs Checkout, restricciones de host y estado de sesión: validar al abrir y consultar objeto; no confiar en parámetros de URL.

### 14.5 Operación, costos y recuperación

- [ ] Límites de tiempo/cancelación y reintentos acotados para Stripe, SMS, correo y push; no repetir automáticamente operaciones financieras no idempotentes.
- [ ] Alertas de errores de autorización, emisión OTP, webhook fallido, órdenes atascadas y discrepancia de importes; métricas/traceId sin secretos ni datos personales innecesarios.
- [ ] Límite de costo de SMS/almacenamiento y detección de abuso; cuentas test no generan cargos de proveedor inadvertidos.
- [ ] Health/readiness seguros: no divulgar cadenas de conexión ni internals. Endpoint de salud no equivale a prueba de flujo completo.
- [ ] Semillas e inicialización al arrancar: confirmar que no crean roles privilegiados, usuarios demo o migraciones de producción sin control.
- [ ] Respaldo y restauración de base y archivos; reconciliación Stripe cuando el servidor perdió eventos; gestión de rotación de secretos y respuesta a incidentes.
- [ ] Seguridad de pipeline: permisos mínimos GitHub/Azure, revisión de cambios, artefactos rastreables y secretos separados por ambiente. ZIP no debe sustituir historial Git.

### 14.6 Matriz de regresión obligatoria y criterio de parada

Para cada ruta afectada, registrar rol permitido/denegado, dueño/tercero, DTO válido/inválido, recurso inexistente, estado permitido/prohibido, red interrumpida, duplicación/concurrencia y efectos persistidos. Pruebas unitarias de servicios, integración HTTP y persistencia real aislada son evidencias distintas.

- [ ] Datos de prueba: clientes A/B; Yonkes A/B con asignaciones distintas; solicitud sin foto/con foto propia; cotización disponible/no disponible; orden pendiente/pagada/cancelada; mensaje propio/ajeno.
- [ ] Inventario de acciones repetidas: doble toque, dos dispositivos, reintento tras timeout y retorno tardío. No resolver todo deshabilitando botones: servidor controla concurrencia.
- [ ] Verificar accesibilidad, teclado y responsive con estos estados reales; errores 403/409/429 deben tener UX clara sin simular éxito.
- [ ] Detener una etapa si una corrección rompe contrato, expone datos o contradice pagos; corregir y repetir pruebas antes de continuar su aprobación.
- [ ] Adjuntar evidencia del commit, versión backend/app, esquema y pruebas. No trasladar al resultado final conteos históricos de tests como si pertenecieran al código nuevo.

**Orden revisado del primer bloque:** A (compilar y aislar) → BSEC-01/02/03 (identidades y chat) → C1/C2 (órdenes y resultado) → OTP/errores/transporte → resto del flujo. No basta corregir la cancelación si el cliente ni siquiera puede aceptar correctamente por la inconsistencia de identidad.
