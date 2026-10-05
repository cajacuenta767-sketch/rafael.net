# Revisión de arquitectura, compatibilidad y seguridad

Fecha: 4 de octubre de 2026. Alcance: código local Flutter y pruebas con adaptadores simulados. No es una certificación del backend ni una auditoría dinámica de producción.

## Arquitectura observada

La aplicación organiza funcionalidades en `lib/features`: presentación, dominio y datos. No todos los módulos implementan las tres capas de manera estricta. Riverpod en `core/di/api_providers.dart` construye dependencias; repositorios adaptan respuestas a modelos; clases API utilizan la interfaz `ApiClient`; `DioApiClient` centraliza HTTP, tokens y errores. GoRouter organiza navegación y las puertas de sesión protegen pantallas. El almacenamiento de credenciales utiliza `TokenStore` con implementación segura y avisos de sesión.

No se ha sustituido ese patrón por otra arquitectura. La corrección de este bloque permanece en el interceptor HTTP y sus pruebas existentes; no cambia rutas, DTO ni métodos del servidor.

No hay archivos `.csproj` del backend en esta carpeta. El Swagger no revela si .NET utiliza capas, Clean Architecture, repositorios, EF Core o servicios propios. Para conservar su formato de programación es obligatorio revisar sus fuentes, convenciones y pruebas antes de implementarle cambios. No se infiere su arquitectura a partir de nombres de endpoints.

## Hallazgos y controles: 10 puntos prioritarios

1. **Sesión anterior invalidando una nueva — corregido parcialmente.** Una respuesta 401 tardía podía borrar las credenciales actuales. Ahora el interceptor comprueba revisión de sesión y token enviado antes de limpiar. Prueba local reproduce el cambio de sesión con respuesta en vuelo. Una escritura concurrente durante la propia operación de borrado todavía requiere exclusión mutua en el almacén; no declarar atomicidad completa.
2. **Autorización del servidor — pendiente.** UI, GUID y JWT almacenado no prueban permisos. Verificar en staging dos clientes y dos yonkes: solicitud, cotización, chat, orden, logo y perfil deben autorizar pertenencia en cada operación. No ejecutar intercambio de IDs en Azure de producción con esta revisión.
3. **JWT y renovación — pendiente backend.** Revisar validación de firma, emisor, audiencia, expiración, algoritmos admitidos, rotación/revocación y errores 401/403 consistentes. Decodificar un JWT en el cliente no verifica su firma. No generar JWT ni claves de firma dentro de Flutter.
4. **OTP/login/recuperación — pendiente backend.** Exigir límites por cuenta/IP/dispositivo, caducidad y uso único, respuestas que no enumeren cuentas y bloqueo gradual. Los botones de prueba no sustituyen autenticación real ni deben habilitarse en producción.
5. **Transporte y origen — revisión parcial.** Host predeterminado HTTPS y redirecciones HTTP desactivadas en Dio. Falta bloquear configuraciones inseguras de release y destinos externos en el cliente HTTP; no enviar Authorization a un host ajeno. iOS no presenta excepción ATS global en el plist inspeccionado. Validación TLS de runtime y tráfico aún pendiente.
6. **Credenciales, registro y respaldo — revisión parcial.** Tokens utilizan almacenamiento seguro; Android declara `allowBackup=false`; logs de red solo habilitables en debug y no imprimen cuerpos/cabeceras. Auditar también URLs, SignalR, excepciones y artefactos compilados: esas opciones no garantizan ausencia de filtraciones. No se extrajeron secretos del navegador.
7. **Archivos y mensajes — pendiente backend.** Verificar tamaño, firma real del archivo, extensiones permitidas, nombres normalizados, contenido peligroso y permisos de lectura. Un MIME generado desde extensión en Flutter no valida el contenido ni protege el servidor. Validación y límites definitivos deben estar en .NET.
8. **Órdenes y Stripe — pendiente cierre E2E.** Se mantiene recuperación local de creación incierta y confirmación de cancelación. Backend debe calcular importes desde cotización autorizada, controlar transiciones y concurrencia, e imponer idempotencia. Checkout lo crea el servidor; webhook verifica firma sobre cuerpo original, deduplica eventos y actualiza estado de manera transaccional. Retorno del navegador no prueba pago. No hay habilitación de cobros reales ni auditoría de estas implementaciones.
9. **Release y dependencias — revisión parcial.** Release Android ya no firma con debug; secretos y claves privados están excluidos de Git. Falta auditoría de dependencias contra avisos vigentes, APK/IPA final, permisos efectivos, firma del propietario y despliegue. No afirmar ausencia de CVE ni asignar CVSS sin evidencia suficiente.
10. **Integridad funcional — pruebas parciales.** Pruebas locales de sesiones, contratos y flujos pasan; no acreditan persistencia ni concordancia cliente/Yonke en Azure. El perfil cliente continúa local y algunos listados dependen de registros locales; deben resolverse con contrato y backend antes de declarar funcionamiento completo.

## Resultado de este bloque

`flutter test --no-pub test/session_expiry_test.dart test/api_integration_test.dart test/api_flows_test.dart`: **51 pruebas aprobadas**, incluida regresión de 401 antiguo. Las 506 pruebas del bloque anterior son evidencia histórica, no se presentan como nueva ejecución de suite completa después de esta corrección.

## Puerta de salida para finalizar

- Acceso de lectura al código .NET y revisión de su estructura, cambios y pruebas originales.
- Entorno staging autorizado y cuentas de ambos roles con recursos propios para pruebas E2E y autorización negativa.
- Contratos completos de estados, IDs, sesión, archivos y pagos; reglas implementadas en servidor.
- Stripe test y webhook configurados privadamente en backend; pruebas de eventos duplicados, tardíos y fallidos.
- Suite completa y pruebas reales en dispositivos; revisión de dependencias y artefactos release; aprobación explícita de cada punto pendiente.

No se modificó el backend, no se hicieron ataques de producción y no se promete una aplicación «a prueba de todo».
