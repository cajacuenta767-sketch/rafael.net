# Errores del Web API que afectan a la app

Revisión del código de `cajacuenta767-sketch/pipeline` (commit `15d1b4e`,
.NET 9) hecha el 25 de septiembre de 2026 para conectar la app de punta a
punta. El API desplegado en Azure es más reciente que ese código: publica
`SolicitudYonkes/MisSolicitudes` y `CotizacionYonke/MisCotizaciones/Total`,
que no están en el repositorio. Cada punto debe confirmarse contra Azure
antes de corregirlo.

Swagger en vivo (25 de septiembre de 2026, copia en `docs/openapi_v1.json`):
confirma `MisSolicitudes` con `SolicitudYonke_List_DTO`, agrega
`SolicitudYonkes/TotalSolicitudesNuevas` y `SolicitudYonkes/MasReciente`, y
`usuarioId` ya es `uuid`. El Swagger no publica roles ni respuestas de la
mayoría de operaciones, así que los puntos de roles y formatos de este
documento siguen viniendo del código del repositorio.

La columna **App** indica qué hace hoy la app mientras el API no cambie.

## Críticos

| # | Problema | Dónde | App |
| --- | --- | --- | --- |
| 1 | `POST /api/Solicitudes` devuelve el `GuidId` de un objeto mapeado aparte, no el de la solicitud guardada. Fotos y envío a yonkes fallan con "no existe". | `SolicitudesController.cs` (`NuevaSolicitud`), `SolicitudService.cs:119` | Resuelve el GUID real con `mi-solicitud-reciente` comparando pieza, marca, modelo y año. |
| 2 | Login de yonke: `if (!yonke.Autorizado == false)` equivale a `Autorizado == true`. Bloquea a los autorizados y deja pasar a los demás. | `YonkeAuthService.cs:75` | Muestra el mensaje del servidor. |
| 3 | `UpdateYunke` reemplaza la entidad completa: pone `Autorizado=false`, borra los datos de Stripe y reactiva yonkes dados de baja. También lo llama `ActualizarLogo`. | `YunkeService.cs:216-238`, `YunkeRepository.cs:117` | Sin rodeo posible; no enviar cambios de perfil hasta corregirlo si afecta la operación. |
| 4 | `AddIdentity` deja la cookie como esquema por defecto. Los endpoints con `[Authorize]` sin `AuthenticationSchemes` responden 302 a `/Account/Login` en vez de aceptar el Bearer: `ClienteAuth/registrar-dispositivo`, `GET Solicitudes/{guid}`, `Auth/soporte` y el hub de SignalR. | `Program.cs:155,181` | El 302 solo hace fallar esa acción (no cierra la sesión). El detalle de solicitud se arma con `mis-solicitudes` (cliente) o con `MisSolicitudes` + fotos (yonke; sin marca, modelo ni año). El registro de push del cliente y el tiempo real fallan hasta corregirlo; el chat sigue con sondeo. **Arreglo en el API:** agregar `AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme` a esos `[Authorize]`. |
| 5 | Clave JWT con valor real en `appsettings.json` de un repositorio público. Cualquiera puede firmar tokens de cualquier rol. | `appsettings.json`, `appsettings.Development.json` | — Rotar la clave en Azure y sacarla del repositorio. |
| 6 | `Utilerias` sin `[Authorize]`: cualquiera crea o edita marcas y modelos. | `UtileriasController.cs:200,220,310,330` | La app no llama esos endpoints. |
| 7 | IDOR: se puede leer o modificar la solicitud, imágenes, ciudades, cotización, conversación, perfil, cobertura o dispositivos de otro usuario conociendo el GUID. | `SolicitudService`, `SolicitudesImagenesService`, `SolicitudCiudadesService`, `CotizacionYonkeService`, `SolicitudCotizacionMensajeService`, `ChatHub`, `YunkeService`, `YonkesCoberturasController`, `YunkeDispositivoService` | — Validar en cada servicio que el recurso pertenece al usuario del token. |

## Altos

| # | Problema | Dónde | App |
| --- | --- | --- | --- |
| 8 | `mis-cotizaciones` no proyecta `Activo` (siempre `false`), `SolicitudGuidId`, año, yonke ni `TiempoEntregaDias`. | `SolicitudesRepository.cs:265-297` | Asume activas las de esa lista (el servidor ya filtra) y relaciona por folio. |
| 9 | El remitente de los mensajes se etiqueta al revés y el push siempre va al yonke; los tokens de los clientes nunca se usan. | `SolicitudCotizacionMensajeService.cs:77-89,143-160` | Decide "mío" comparando `usuarioId` con el del JWT. El cliente no recibe push de mensajes hasta corregirlo. |
| 10 | No hay endpoint del yonke para listar sus cotizaciones ni sus conversaciones (el Swagger en vivo solo publica el total); `mis-cotizaciones` es del rol Cliente. `SolicitudYonke_List_DTO` tampoco trae marca, modelo ni año. | `DashboardSuscriptoresController.cs` | Muestra "pendiente" en lugar de 403; la bandeja muestra pieza, folio, ciudad y fotos. |
| 11 | `POST /api/Yonkes` y `PUT baja` exigen rol Soporte. | `YonkesController.cs:233,315` | Explica que el alta y la baja las hace soporte. |
| 12 | `SignalR` no lee `access_token` de la query (`JwtBearerEvents.OnMessageReceived`), que es como se autentican los WebSockets. Nadie une al yonke al grupo que recibe `NuevaSolicitud`. | `Program.cs:181-205` | Intenta conectar y usa sondeo si falla. |
| 13 | `solicitar-otp` sin límite por teléfono ni por IP (costo de SMS); crea el cliente como confirmado antes de verificar. | `ClienteOtpService.cs` | — |
| 14 | Crear orden compara `cotizacion.UsuarioId` (el yonke) con el cliente: el cliente nunca puede crear la orden. | `OrdenService.cs:114-118` | Fuera de alcance (Stripe). |
| 15 | Errores de negocio devueltos como 500 (límite diario de solicitudes) y `UnauthorizedAccessException` / `KeyNotFoundException` sin manejar. | `GlobalExeptionFilter.cs`, `SolicitudesController.cs:177-181` | Reconoce el texto del límite diario y quita "Error interno:". |

## Contrato

- Un solo formato de respuesta. Hoy conviven `ApiResponseGlobal`, DTO sin
  envoltorio, `{success,message}`, `{mensaje}`, `{error:[…]}`,
  `ValidationProblemDetails` y texto plano. La app los lee todos en
  `DioApiClient`.
- `[ProducesResponseType]` en cada acción: 63 de 66 publican "200 OK" sin
  esquema.
- Login con `expiresAt`, refresh token y endpoint de cierre de sesión y de
  baja de dispositivo. Hoy el token dura 30 días sin revocación.
- 401, 403 y 404 con el mismo cuerpo de error; contraseña incorrecta hoy es
  400.

## Pedido para el API: perfil del cliente

Hoy el perfil del cliente (nombre, teléfono, correo y foto)
se guarda solo en el teléfono, por cuenta (`sub` del JWT), porque el API no
tiene dónde guardarlo. Si el cliente reinstala la app o cambia de teléfono,
se le vuelve a pedir el registro (prellenado con lo que entregue el login).

Para que el perfil viva en el servidor hace falta:

| Endpoint | Uso |
| --- | --- |
| `GET /api/ClienteAuth/perfil` | `Nombre`, `Telefono`, `Correo` y `FotoPerfil` del cliente del token (columnas que ya existen en `Clientes`) |
| `PUT /api/ClienteAuth/perfil` | Guardar nombre, teléfono y correo |
| `PUT /api/ClienteAuth/perfil/foto` (multipart) | Subir o quitar la foto |
| `esNuevo` o `perfilCompleto` en `LoginClienteResponse` | Mostrar el registro solo la primera vez, en cualquier teléfono |

El login por OTP crea al cliente con `Nombre = "Cliente refaNet"`; la app lo
trata como "sin nombre". Con esos endpoints, la app solo cambia
`LocalClientProfileRepository` por una implementación contra el API.


## Pedido para el API: cliente en la cotización

El cliente ve el nombre, el logo y el teléfono del yonke
(`CotizacionYonke/{guid}` + `Yonkes/{guid}`), pero el yonke no tiene cómo
ver al cliente: ninguna respuesta incluye datos de `Clientes` y el perfil
del cliente vive solo en su teléfono (ver el pedido anterior). La bandeja y
el chat del yonke muestran "Cliente · folio" hasta que el API lo entregue.

La app del yonke ya lee al cliente de `GET /api/CotizacionYonke/{guid}` en
cualquiera de estas formas (`QuoteClient` en
`lib/features/yonke_messages/domain/quote_client.dart`):

| Forma | Campos |
| --- | --- |
| Objeto `cliente` en `data`, en `solicitudYonkes` o en `solicitudYonkes.solicitudes` | `nombre`, `telefono` (formato `+52...`), `fotoPerfil` (https) |
| Campos planos en `data` | `nombreCliente`, `telefonoCliente`, `fotoCliente` |

Requisitos del lado del servidor:

- Guardar el perfil del cliente en `Clientes` (endpoints del pedido
  anterior); si no, el yonke solo vería "Cliente refaNet", que la app oculta.
- Entregar el cliente solo al yonke asignado a esa cotización (punto 7,
  IDOR): el teléfono es un dato personal.
