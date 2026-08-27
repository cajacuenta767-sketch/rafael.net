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

## Fuera del alcance móvil

Los siguientes endpoints aparecen en Swagger, pero no deben ejecutarse desde la
aplicación pública sin confirmar permisos de administrador:

- Crear y actualizar marcas.
- Crear y actualizar modelos.
- Webhook de Stripe.
- Página web `/pago/exitoso`.
