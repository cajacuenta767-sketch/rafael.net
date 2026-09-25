# Arquitectura de integración API

Fecha de revisión: 26 de agosto de 2026.

Contrato revisado: [Swagger UI Web Api Yonke V2](https://refanetwebapi-a4dhhqd0d7hseqds.westus2-01.azurewebsites.net/index.html).
La interfaz publica actualmente el documento `/swagger/v1/swagger.json` con
`info.version: V1`; ambos identificadores se conservan aquí para evitar asumir
un versionado de rutas que todavía no existe.

## Estado del contrato

El OpenAPI publicado contiene 65 operaciones agrupadas en 16 controladores y
41 esquemas. La API todavía está en construcción, así que la aplicación separa
la infraestructura HTTP, los módulos funcionales y las pantallas. Los métodos
de transporte devuelven `dynamic` temporalmente; se cambiarán a modelos tipados
cuando el backend documente respuestas estables.

| Módulo Swagger | Operaciones | Módulo Flutter |
| --- | ---: | --- |
| ClienteAuth | 5 | `features/auth` |
| YonkeAuth | 1 | `features/auth` |
| Solicitudes | 4 | `features/requests` |
| SolicitudesImagenes | 4 | `features/requests` |
| SolicitudCiudades | 7 | `features/requests` |
| SolicitudYonkes | 2 | `features/requests` |
| CotizacionYonke | 3 | `features/quotes` |
| SolicitudCotizacionMensajes | 4 | `features/quotes` |
| DashboardSuscriptores | 4 | `features/dashboard` |
| Orden | 4 | `features/orders` |
| Pagos | 4 | `features/payments` |
| Utilerias | 12 | `features/catalogs` |
| Yonkes | 6 | `features/yonkes` |
| YonkesCalificaciones | 2 | `features/yonkes` |
| YonkesCoberturas | 2 | `features/yonkes` |
| YonkesDispositivos | 1 | `features/yonkes` |

## Estructura preparada

```text
lib/
├── app/
│   ├── router/              navegación y rutas por rol
│   └── theme/               identidad visual global
├── core/
│   ├── config/              URL y configuración por ambiente
│   ├── di/                  proveedores e inyección de dependencias
│   ├── network/             HTTP, errores, archivos y endpoints
│   └── storage/             almacenamiento seguro de tokens
└── features/
    ├── auth/                cliente, OTP, Google, Apple y login yonke
    ├── catalogs/            estados, ciudades, marcas y modelos
    ├── dashboard/           resumen del suscriptor
    ├── orders/              creación, consulta y cancelación
    ├── payments/            checkout y consulta del resultado
    ├── quotes/              cotizaciones y conversación
    ├── requests/            solicitudes, ciudades, imágenes y envío
    └── yonkes/              perfil, logo, cobertura, rating y dispositivo
```

## Configuración por ambiente

La URL no está fijada dentro de los servicios. Se puede cambiar al ejecutar o
compilar la aplicación:

```shell
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://servidor-desarrollo.example.com
```

Los logs HTTP están apagados por defecto para no exponer tokens o datos
personales. Solo durante desarrollo pueden activarse con
`--dart-define=ENABLE_NETWORK_LOGS=true`.

### Todas las variables

| Variable | Obligatoria | Uso |
| --- | --- | --- |
| `API_BASE_URL` | No (Azure por defecto) | Servidor del API |
| `APP_ENV` | No | `development` o `production` |
| `GOOGLE_SERVER_CLIENT_ID` | No (proyecto Rafael Net por defecto) | Client ID **Web** de Google; debe ser el mismo valor que `Google:ClientId` en la configuración del API en Azure |
| `SIGNALR_HUB_PATH` | No (`/hubs/notificaciones`) | Hub de mensajes en tiempo real |
| `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_SENDER_ID`, `FIREBASE_PROJECT_ID` | Para push | Opciones de Firebase de la app `com.refanet.app`. Sin ellas la app funciona y solo desactiva el push |
| `FIREBASE_IOS_BUNDLE_ID` | No (`com.refanet.app`) | Bundle de iOS registrado en Firebase |

Compilación de prueba contra Azure con push activo:

```shell
flutter run --release \
  --dart-define=APP_ENV=production \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=1:...:android:... \
  --dart-define=FIREBASE_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=...
```

Los valores de Firebase están en la consola de Firebase → Configuración del
proyecto → app Android `com.refanet.app`. Deben venir del **mismo proyecto**
cuya cuenta de servicio usa el API para enviar (`FirebaseAdmin`); si son de
otro proyecto, el registro funciona pero los avisos nunca llegan.

### Google Sign-In

1. En Google Cloud (proyecto Rafael Net) debe existir un cliente OAuth
   **Web**; su ID va en `GOOGLE_SERVER_CLIENT_ID` y en `Google:ClientId` del
   API. El API valida la audiencia del `idToken` contra ese valor: si no
   coinciden, el login responde 401.
2. Debe existir un cliente OAuth **Android** con el paquete
   `com.refanet.app` y el SHA-1 de la firma de depuración y de la de release
   (`keytool -list -v -keystore <keystore>`). Sin él, el selector de cuentas
   se cierra con `DEVELOPER_ERROR` / código 10.
3. En iOS, un cliente OAuth **iOS** para el bundle definitivo y su
   `REVERSED_CLIENT_ID` como URL scheme en `ios/Runner/Info.plist`.

### Push en iOS

Además de las variables de Firebase: subir la llave APNs a Firebase, activar
*Push Notifications* en Xcode (agrega `aps-environment` al entitlement) y
alinear el bundle `com.example.appYonke` con `com.refanet.app`.
`UIBackgroundModes: remote-notification` ya está en `Info.plist`.

### Tiempo real

Las conversaciones se unen al grupo de la cotización en `/hubs/notificaciones`
(`UnirseCotizacion`) y se refrescan con `NuevoMensaje`. Si el hub rechaza la
conexión, la conversación sigue actualizándose cada 15 segundos.

## Decisiones de seguridad

- El token se guarda mediante almacenamiento seguro de iOS/Android.
- La cabecera `Authorization: Bearer <token>` se agrega centralmente.
- No hay secretos, llaves de Stripe, Firebase ni credenciales sociales en el
  repositorio.
- El webhook de Stripe está identificado como responsabilidad exclusiva del
  backend y no tiene método invocable desde la app.
- Los errores HTTP se convierten a `ApiException` en un único punto.
- Los campos nulos se eliminan de las consultas antes de enviar la petición.

## Flujo funcional previsto

### Cliente

1. Iniciar sesión con teléfono/OTP, Google o Apple.
2. Registrar el token del dispositivo.
3. Cargar catálogos de estado, ciudad, marca y modelo.
4. Crear una solicitud y subir imágenes.
5. Asociar ciudades y enviar la solicitud a yonkes con cobertura.
6. Consultar cotizaciones y conversar con el yonke.
7. Crear una orden desde una cotización.
8. Abrir checkout, consultar resultado y calificar la compra.

### Yonke

1. Iniciar sesión con correo y contraseña.
2. Registrar el dispositivo para notificaciones.
3. Consultar dashboard y solicitudes recibidas.
4. Marcar solicitudes como vistas.
5. Crear o actualizar cotizaciones, incluyendo imágenes.
6. Gestionar perfil, logotipo y ciudades de cobertura.
7. Consultar órdenes, mensajes y calificaciones.

## Orden recomendado de implementación

1. Cerrar contrato de autenticación y formato estándar de respuesta.
2. Implementar sesión, selección de rol y redirecciones protegidas.
3. Integrar catálogos y creación de solicitudes.
4. Integrar imágenes multipart y envío a yonkes.
5. Integrar dashboard, cotizaciones y mensajería.
6. Integrar órdenes y flujo Stripe con enlaces profundos móviles.
7. Integrar Firebase Messaging y registro/renovación de dispositivos.
8. Completar telemetría, manejo offline, pruebas y publicación.

## Probar los endpoints de búsqueda, ciudad y cotizaciones

`tool/api_probe.dart` consulta los endpoints que usan esas pantallas y compara
la forma de cada respuesta con las claves que la app lee. Solo imprime
estatus, tipos y nombres de claves; nunca valores ni el token.

```shell
dart run tool/api_probe.dart
dart run tool/api_probe.dart --token=<jwt> --quote-id=<guid>
dart run tool/api_probe.dart --base-url=https://otro-servidor
```

Sin token se prueban los catálogos públicos; con el token de un login válido
se agregan las cotizaciones del cliente. Termina con código 1 si algún
endpoint respondió con error o sin alguna clave necesaria.

| Endpoint | Pantalla | Claves que la app lee |
| --- | --- | --- |
| `GET /api/Utilerias/entidades` | Ciudad de la solicitud | `id`, `entidad` |
| `GET /api/Utilerias/entidad/{id}/ciudades` | Ciudad de la solicitud | `id`, `ciudad`; `entidade` opcional |
| `GET /api/Utilerias/marcas` | Filtros de búsqueda, nueva solicitud | `id`, `marca` |
| `GET /api/Utilerias/modelos?marcaId=` | Filtros de búsqueda, nueva solicitud | `id`, `modelo` |
| `GET /api/DashboardSuscriptores/mis-cotizaciones` | Cotizaciones recibidas | `guidId`, `precio`, `disponible`, `activo`, `solicitudYonkes.solicitudGuidId`, `solicitudYonkes.yonkes.nombre`, `solicitudCotizacionEstatus.descripcion` |
| `GET /api/CotizacionYonke/{guid}` | Detalle de cotización | las mismas del renglón anterior |
| `GET /api/Orden/cotizacion/{guid}` | Detalle de cotización | `404` significa que no hay orden previa |
| `GET /api/DashboardSuscriptores/mi-solicitud-reciente` | Inicio del cliente | `Solicitud_Busqueda_DTO` (objeto o lista de uno) |
| `GET /api/DashboardSuscriptores/mis-solicitudes` | Mis solicitudes (cliente) | `guidId`, `piezaBuscada`, `marca`, `modelo`, `año`, `estatusSolicitud`, `totalCotizaciones` |
| `GET /api/SolicitudYonkes/MisSolicitudes` | Bandeja del yonke | `SolicitudYonke_List_DTO`: `solicitudYonkeGuidId`, `solicitudGuidId`, `folio`, `piezaBuscada`, `fechaEnvio`, `estatus`, `vista`, `cotizaciones`, `imagenes[].url`, `ciudades[].ciudad` |
| `GET /api/SolicitudYonkes/TotalSolicitudesNuevas` | Inicio del yonke | número en `data` |
| `GET /api/Solicitudes/{guid}` + `SolicitudesImagenes/solicitud/{guid}` + `SolicitudCiudades/{guid}/ciudades` | Detalle de solicitud | `Solicitud_Busqueda_DTO`, `urlImagen`, `ciudades.ciudad` + `entidades.entidad` |
| `GET /api/SolicitudCotizacionMensajes/{guid}` y `PUT .../leer` | Conversaciones (cliente y yonke) | `SolicitudCotizacionMensajes`: `guidId`, `usuarioId`, `tipoRemitenteId`, `mensaje`, `leido`, `fechaCreacion` |
| `GET /api/Yonkes/{guid}` | Perfil del yonke | `nombre`, `responsable`, `telefono`, `correo`, `direccion`, `cp`, `ciudades.ciudad` |
| `GET /api/YonkesCoberturas/guid/{guid}` y `PUT /api/YonkesCoberturas` | Cobertura del yonke | `ciudadId`, `activo` |

Las mismas formas están fijadas en `test/api_flows_test.dart` y
`test/contract_parsers_test.dart`, que ejercitan pantallas y parsers con un
cliente HTTP simulado. El OpenAPI no publica un buscador de refacciones: la
pantalla de búsqueda usa marcas y modelos reales y, al buscar, ofrece crear la
solicitud con lo capturado.

## Cliente nuevo

Después del login (OTP o Google) la app decide a dónde ir: si esa cuenta no
tiene perfil completo en el teléfono abre directo `/cliente/registro`; si ya
se registró, el inicio. Mientras el API responde se muestra "Iniciando
sesión…".

- Pide solo lo que existe en la tabla `Clientes` del API: nombre completo,
  celular y correo (obligatorios) y foto (opcional, galería o cámara).
- Con Google llegan nombre, correo y foto de la cuenta; con OTP el celular
  verificado (bloqueado) y el nombre vacío: el número nunca se usa como
  nombre.
- "Mis datos" usa el mismo formulario para editarlos.

El perfil se guarda en el teléfono por cuenta mientras el API no publique
uno (ver `docs/BACKEND_ISSUES.md`).

## Sesión

La sesión solo se cierra cuando el usuario elige "Cerrar sesión", al dar de
baja la cuenta o cuando el token de verdad ya no sirve: venció su `exp`,
JwtBearer responde `invalid_token` o `GET /api/Yonkes/byPage` (esquema JWT)
también responde 401. Un 302 hacia `/Account/Login` o un 401 aislado de un
endpoint mal configurado solo hacen fallar esa acción.

## Sin datos inventados

Cada pantalla consulta la API con el token guardado al iniciar sesión. Si una
llamada falla se muestra el mensaje del servidor con "Reintentar"; nunca se
mezclan solicitudes, cotizaciones o ciudades locales con las del servidor. No
existe modo prueba: el cliente entra con OTP o Google y el yonke con su
correo y contraseña.

Pendientes marcados en pantalla:

- Buscador de refacciones y catálogo de categorías: no existen en el OpenAPI.
- Lista de cotizaciones y bandeja de mensajes del yonke: el API solo publica
  `mis-cotizaciones` para el rol Cliente (ver `docs/BACKEND_ISSUES.md`).
- Alta y baja de yonkes: el API las reserva al rol Soporte; la app lo explica.
- Checkout y resultado de pago (`Pagos`): fuera de esta integración.
- Apple Sign In (requiere configuración en Mac).

## Fuera del alcance móvil

Los siguientes endpoints aparecen en Swagger, pero no deben ejecutarse desde la
aplicación pública sin confirmar permisos de administrador:

- Crear y actualizar marcas.
- Crear y actualizar modelos.
- Webhook de Stripe.
- Página web `/pago/exitoso`.
