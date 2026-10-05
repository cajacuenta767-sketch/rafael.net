# Ejecución del plan — estado verificable

Fecha: 3 de octubre de 2026. Ejecución iniciada; el plan completo no está terminado.

## Implementado y verificado

- APP-01: una sesión nueva elimina refresh, expiración y GUID Yonke anteriores cuando no llegan. Se rechaza token vacío. El access token se escribe después de los metadatos y se limpia el almacén si la escritura falla; no es una transacción del servidor ni resuelve todavía todos los escenarios de escrituras concurrentes.
- APP-03, alcance parcial: cachés de resolución cliente/Yonke dejan de ser estáticas globales; se invalidan al consultar después de una nueva sesión/cierre mediante revisión de SessionEvents. Falta verificar llamadas en vuelo, edición de perfil y aislamiento E2E completo.
- Inventario inicial de 71 operaciones del contrato local en `MATRIZ_API_EJECUCION.md`. Azure fue consultado nuevamente; la revisión anterior contabilizó 75 operaciones. No declarar ambos contratos idénticos ni cerrar la matriz mientras falta trazabilidad de DTO, permisos y consumidores.
- `flutter test --no-pub test/secure_token_store_test.dart test/api_endpoints_openapi_test.dart test/client_messages_test.dart test/yonke_messages_test.dart`: 55 pruebas aprobadas.
- `flutter analyze --no-pub`: sin incidencias.

Las primeras pruebas detectaron una directiva import mal situada introducida durante esta ejecución; se corrigió y se repitieron las pruebas hasta aprobar. No ocultar ese resultado bajo la ejecución anterior fallida.

## Siguiente trabajo local, todavía pendiente

1. Completar matriz endpoint/DTO/roles/consumidor y pruebas de caché al cambiar de cuenta con consultas en vuelo.
2. Exponer sincronización de lectura de mensajes sin ocultar fallos ni bloquear historial disponible.
3. Listados paginados y recuperación sin registros locales como única fuente.
4. Contratos tipados de órdenes/pagos y recuperación por ID antes de integrar Checkout.
5. Fichas de pantalla y validación visual sobre app real, incluyendo horizontal/vertical y teclado. No se generaron ni aprobaron capturas nuevas en este bloque.

## Dependencias externas no resueltas

- Acceso autorizado al backend .NET y correspondencia con la versión desplegada; no hay backend en esta carpeta.
- Staging, cuentas reales autorizadas cliente/Yonke y contrato de sesión para probar permisos, persistencia y flujo E2E.
- Respuestas de órdenes/pagos y reglas de estados, importe e idempotencia acordadas con backend; un OpenAPI incompleto no permite inventarlas.
- Configuración Stripe test/webhook/retorno y modelo comercial; no se habilitaron cobros.
- Autenticación GitHub de escritura: el intento documental anterior falló. No se extrajeron credenciales de Chrome.

No se modificó Azure ni se ejecutaron ataques de autenticación. La guía de pruebas de autenticación móvil limita esta validación a pruebas locales y a documentación pública hasta disponer de alcance y entorno autorizados. La aplicación sigue teniendo funciones del plan pendientes; no describir este bloque como «todo conectado» o «listo para producción».

## Segundo bloque ejecutado — 3 de octubre de 2026

Este apartado actualiza el estado anterior sin eliminar su historial.

### Cambios incorporados

- Matriz sustituida por inventario de las **75 operaciones del Swagger consultado en Azure**. Se identifican referencias de entrada/salida; permisos efectivos, consumidores y respuestas reales siguen sin aprobarse.
- Caché cliente: pruebas de cambio de cuenta y respuesta en vuelo que llega después del cierre. Los resolutores cliente/Yonke descartan respuestas de una revisión de sesión anterior. Aislamiento E2E de todos los repositorios todavía pendiente.
- Ambos chats muestran lectura pendiente y permiten reintentar si falla la sincronización. El historial disponible no se oculta por ese fallo; no se inventa confirmación de lectura del servidor.
- Recuperación de cotizaciones registradas deja de truncarse por defecto a 30, consulta hasta 200 y agrupa peticiones de ocho. Solo se omite 404; otros errores se propagan. **No sustituye un listado paginado oficial del backend**.
- Resumen Yonke muestra carga y advertencia de actualización incompleta, en lugar de presentar todos los fallos como ceros fiables.
- Navegación lateral desde 1200 píxeles lógicos, sin menú hamburguesa, conservando las acciones del botón +. Prueba de formulario que mantiene el borrador al cambiar escritorio/móvil.
- Tema global corregido a azul, verde y superficies blancas, eliminando el tinte rojo heredado.
- Actualizar logo invalida la imagen anterior y el resolutor del Yonke. Falta verificar persistencia con una cuenta real.
- Crear orden tras respuesta incierta consulta si ya existe antes de ofrecer un nuevo intento. No repite automáticamente POST; 403 no provoca recuperación que oculte el rechazo.
- Cancelar orden requiere estado confirmado al consultar el servidor. Estados desconocidos no se interpretan como pendiente de pago; órdenes pagadas no ofrecen cancelación por inferencia local.
- Release Android deja de usar firma debug. Se añadió plantilla privada de configuración, exclusiones Git y documentación para conectar la clave de firma existente, sin generar ni sustituir la clave del propietario.
- Plantilla de configuración staging sin tokens ni secretos, y guía de dependencias de API/pruebas.

### Verificación realizada

- Suite completa intermedia: **499 pruebas aprobadas**. Después se ejecutaron pruebas nuevas de caché, recuperación de órdenes, perfil y navegación, además de una selección de **164 pruebas aprobadas** tras el cambio de tema. **Suite completa final: 506 pruebas aprobadas**, ejecutada con `flutter test --no-pub --concurrency=2`.
- `flutter analyze --no-pub`: sin incidencias tras los cambios de implementación.
- `flutter build web --no-pub`: compilación final correcta.
- Gradle `help --offline`: correcto. Esto valida carga de configuración, **no firma ni publicación de APK release**.
- **468 capturas de prueba: 39 pantallas × 12 perfiles** en `build/plan_execution/devices_final`. Perfiles verticales/horizontales de celulares, tablets, laptop, escritorio, monitor 4K con escala 200 % y ultrawide. Cada captura conserva metadatos de tamaño lógico/DPR. No representan todos los dispositivos existentes ni datos reales de Azure.
- Revisados individualmente inicio cliente de laptop y resumen Yonke horizontal compacto. En horizontal corto hay desplazamiento para acceder al contenido inferior; no se comprime todo dentro de una pantalla a costa de la legibilidad.
- App web compilada abierta en navegador local: bienvenida, acceso cliente y acceso Yonke. No se aceptaron términos por el usuario, no se enviaron OTP y no se usaron credenciales. No hay aprobación visual individual de todas las capturas ni flujo autenticado real.
- Generación de hojas de revisión de los 12 perfiles aprobada; son índices visuales de capturas simuladas, no evidencia de tamaño real de uso ni aprobación de cada pantalla.

### Criterios que siguen abiertos

1. Validación visual individual de cada pantalla/estado, teclado, texto grande, foco y mando de TV; panel doble de conversaciones en escritorio y fichas de aceptación completas.
2. Listados oficiales paginados, recuperación entre dispositivos y eliminación de dependencias de registros locales.
3. Contratos completos y pruebas E2E de IDs, estados, permisos por campo, conflictos, importes e idempotencia.
4. Backend .NET accesible, staging y usuarios autorizados para confirmar persistencia, roles y seguridad. No basta un JWT inventado ni un botón de simulación.
5. Stripe test: creación de sesión en servidor, webhook firmado e idempotente, estado de pago consultable y retorno aprobado; claves privadas solo en backend. No está listo para cobros reales.
6. Clave Android existente y credencial GitHub de escritura. No se publicó este bloque ni se modificó Azure; la autorización genérica no proporciona esas credenciales.

El plan principal continúa abierto. No se activó Antigravity: el control nativo de aplicaciones está deshabilitado en esta sesión.

## Revisión de seguridad — 4 de octubre de 2026

Se añadió `REVISION_ARQUITECTURA_SEGURIDAD.md` con arquitectura observada, diez controles/hallazgos y pendientes verificables. Se corrigió la invalidación de sesión nueva por un 401 de una petición anterior, conservando el interceptor y el patrón existente. Pruebas de sesiones, integración y flujos: 51 aprobadas. No se dispone de fuentes .NET en esta carpeta; no se atribuye una arquitectura al servidor ni se declara seguridad total.

### Backend recibido posteriormente

El usuario proporcionó el ZIP .NET. Ya se dispone de copia separada para análisis; ver `BACKEND_ZIP_REVISION.md`. La limitación de ausencia de fuentes queda superada. Siguen pendientes correspondencia con Azure, compilación, pruebas backend, staging y credenciales privadas. Stripe ya tiene implementación de servidor; debe auditarse y probarse, no considerarse ausente.

## Primer bloque de correcciones backend — 4 de octubre de 2026

Cambios únicamente en `C:/Users/PC/Documents/YonkeWebApi_audit_20261004/YonkeWebApi-master`, no desplegados. La guía de autenticación móvil mantuvo las pruebas aisladas, sin intentar acceso ajeno en Azure.

- Compilación original correcta: 0 errores y 393 advertencias. NuGet informa NU1903 de AutoMapper 12.0.1 y compatibilidad NU1701 de dependencias antiguas. No se corrigieron esas dependencias todavía.
- Política de participantes del chat: cliente identificado por solicitud; asociado por YonkeGuidId validado de sesión y asignación. Se aplica a enviar, historial, lectura y conteo. Corrige etiquetas de remitente. Falta validación HTTP completa y pertenencia de grupos SignalR.
- Registro de cotización exige que el Yonke de sesión coincida con el asignado. Aceptación de orden valida al propietario de la solicitud, sin exigir que sea también el creador Yonke de la cotización. No se reasignaron IDs históricos.
- OTP usa RandomNumberGenerator y teléfono nuevo no confirmado hasta verificación. Hash/HMAC, emisión limitada y uso único concurrente siguen pendientes.
- Cancelación directa solo admite estado conocido 1 (PendientePago); 9 es reintento sin cambios. Otros estados se rechazan. Política conservadora pendiente de aprobación comercial. **No resuelve carrera entre cancelación y webhook ni transacciones SQL**.
- Retorno Stripe distingue PaymentStatus paid del pendiente; siguen pendientes autorización/minimización del retorno anónimo y prueba de webhook.
- Middleware de errores ahora registrado en Program: respuestas generales y códigos para excepciones conocidas sin exception.Message; respeta respuesta iniciada/cancelación. Algunos controladores capturan sus propias excepciones y todavía pueden revelar detalles; revisar todos. Mapear InvalidOperationException a 409 es comportamiento provisional que requiere prueba por ruta. Observabilidad privada/traceId pendientes.
- Compilación final correcta, 0 errores. Conteos de advertencias incrementales no se interpretan como reducción real del inventario.
- `dotnet run --project SecurityRegression/SecurityRegression.csproj --no-restore`: **17 comprobaciones aisladas aprobadas** (políticas de participantes/cancelación, 1000 códigos OTP con formato correcto y errores 403/404/500 sin detalle interno). Este ejecutable usa net10.0 disponible localmente y referencia Core net9.0; no es una suite HTTP/SQL ni certificación de servicios completos.

No se cambió Flutter en este bloque, no se publicaron cambios GitHub ni se ejecutó el backend con base real. El plan permanece abierto para pruebas de servicios con repositorios controlados, HTTP, persistencia, concurrencia, seguridad de dependencias y staging.

### Pruebas HTTP posteriores

Se creó y ejecutó `HttpSecurityRegression` sobre controladores/servicios reales con host Kestrel aislado, JWT firmados efímeros y repositorios simulados: **45 comprobaciones aprobadas (34 peticiones HTTP + 11 comprobaciones de efectos)**. Detectó cotización inexistente como 500; se corrigió a 404. Mensaje vacío ahora devuelve 400. Ver `RESULTADOS_PRUEBAS_HTTP_BACKEND.md` para alcance y reproducción. No representa pruebas SQL/Azure/Stripe ni validación de todas las operaciones.

### Preparación de esquema local, sin base real

Se materializó el modelo EF/SQL Server de 35 entidades sin conexión y se verificaron nuevos índices de orden única por cotización y conversación ordenada. Se añadieron scripts de preflight/adición protegida y guía dentro de database del backend. No son migraciones ejecutadas ni esquema Azure confirmado. Las 45 comprobaciones HTTP se repitieron y aprobaron. Ver ENTREGA_BACKEND_LOCAL_SQL.md. Quedan pruebas SQL, concurrencia, conflictos únicos y dependencias abiertas.
