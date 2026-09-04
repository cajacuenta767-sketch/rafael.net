# Pendientes del contrato backend

Esta lista debe cerrarse antes de convertir las respuestas flexibles de la app
en modelos de producción.

## Bloqueantes

- Documentar el JSON de respuesta de los logins Google, Apple, OTP y yonke.
- Definir nombre del access token, expiración, refresh token y proceso de
  renovación/revocación.
- Marcar como públicos los endpoints de login. El OpenAPI aplica Bearer de
  forma global incluso a autenticación y al webhook de Stripe.
- Cambiar el esquema Bearer de `apiKey` a `http/bearer` o confirmar exactamente
  qué valor debe enviarse en `Authorization`.
- Definir un envoltorio de respuesta uniforme para éxito y error.
- Documentar respuestas `400`, `401`, `403`, `404`, `409`, `422` y `500`.
- Documentar la estructura paginada de solicitudes, yonkes y dashboard.
- Documentar todos los campos y nombres de archivo de los formularios
  `multipart/form-data`.
- Definir las respuestas de órdenes, checkout y resultado de pago.
- Definir URLs de retorno/deep links de Stripe para Android e iOS.

## Consistencia del dominio

- Unificar `Yonke`, `Yunke` y `Yonkes` en nombres de rutas y DTO.
- Corregir nombres como `transmicion`, `SubcripcionPeriodos` y `AllPaged` o
  congelarlos explícitamente como parte del contrato.
- Evitar exponer entidades de base de datos con relaciones circulares. Crear
  DTO de respuesta pequeños para móvil.
- Marcar campos obligatorios en todos los request DTO. Actualmente casi todos
  son opcionales en OpenAPI salvo teléfono y código OTP.
- Definir rangos y reglas: año, calificación, precio, garantía, costo de envío,
  tamaño/cantidad de imágenes y longitudes de texto.
- Definir catálogo oficial de estatus de solicitud, solicitud-yonke,
  cotización, orden y pago.
- Confirmar si `DELETE /api/Solicitudes/{guidId}` conservará body o migrará a
  una acción explícita de cancelación.
- Versionar la ruta, por ejemplo `/api/v1`, antes de publicar clientes móviles.

## Operación móvil y tiendas

- Agregar cierre de sesión y desregistro/renovación de token de dispositivo.
- Agregar consulta y eliminación de cuenta del cliente si puede crear cuenta.
- Definir política de privacidad, retención y eliminación de imágenes,
  mensajes, ubicación, teléfono y tokens de dispositivo.
- Confirmar que las llaves y secretos de Stripe, Google, Apple y Firebase solo
  residan en backend o configuración segura de plataforma.
- Implementar idempotencia para crear solicitudes, cotizaciones, órdenes y
  checkout, evitando duplicados por reintentos móviles.
- Publicar ambientes separados para desarrollo, pruebas y producción.
- Añadir endpoint de salud y una política de compatibilidad mínima de la app.

## Contrato mínimo de sesión requerido por la app

La aplicación ya está preparada para guardar tokens en el almacenamiento
seguro del dispositivo, agregar `Authorization: Bearer <token>` y proteger las
rutas. Falta que el backend publique y mantenga un DTO explícito para cada
login. Como mínimo debe indicar:

- `accessToken`: obligatorio y no vacío.
- `refreshToken`: opcional, o una declaración expresa de que no habrá refresh.
- `expiresAt` o `expiresIn`: obligatorio para renovar o cerrar la sesión a
  tiempo.
- Identificador del usuario autenticado. Para yonke debe incluir
  `yonkeGuidId`, necesario para perfil, cobertura y dispositivo.
- Rol o tipo de cuenta cuando un mismo token pueda representar más de un rol.

Hasta que esos nombres y tipos aparezcan en Swagger, la app considera las
respuestas de Google, OTP y yonke como `sessionContractPending`; no navega a
áreas protegidas ni guarda valores inferidos de claves desconocidas.
