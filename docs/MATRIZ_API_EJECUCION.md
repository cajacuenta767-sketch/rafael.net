# Matriz de operaciones API — contrato público Azure

Consulta de ejecución: 3 de octubre de 2026. Fuente: [Swagger Azure](https://refanetwebapi-a4dhhqd0d7hseqds.westus2-01.azurewebsites.net/swagger/v1/swagger.json). 75 operaciones inventariadas. Se reemplaza el inventario provisional de 71 operaciones del archivo local, no se modifica la copia de OpenAPI del usuario.

Las referencias DTO son las publicadas, no contratos supuestos. «Sin DTO referenciado» requiere revisar esquema inline/cuerpo real; no significa respuesta vacía. Roles y propiedad efectivos, consumidor por archivo y prueba en staging siguen pendientes. Login/webhook heredan seguridad global en Swagger: no usarla como prueba de autorización en ejecución.

| ID | Método / ruta | DTO entrada publicado | Respuestas / DTO | Permisos y prueba |
|---|---|---|---|---|
| OP-001 | POST `/api/Auth/soporte` | CrearUsuarioSoporteDTO | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-002 | POST `/api/Auth/login` | LoginSoporteDTO | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-003 | POST `/api/ClienteAuth/google` | GoogleLoginRequest | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-004 | POST `/api/ClienteAuth/solicitar-otp` | SolicitarOtpRequest | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-005 | POST `/api/ClienteAuth/verificar-otp` | VerificarOtpRequest | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-006 | GET `/api/ClienteAuth/{guidId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-007 | POST `/api/ClienteAuth/registrar-dispositivo` | RegistrarDispositivoRequest | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-008 | POST `/api/CotizacionYonke` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-009 | GET `/api/CotizacionYonke/{cotizacionGuidId}` | Sin referencia / comprobar parámetros y multipart | 200:SolicitudCotizacionesApiResponseGlobal | Pendiente de backend/staging |
| OP-010 | PUT `/api/CotizacionYonke/{cotizacionGuidId}` | RegistrarCotizacionRequest | 200:StringApiResponseGlobal | Pendiente de backend/staging |
| OP-011 | GET `/api/CotizacionYonke/MisCotizaciones/Total` | Sin referencia / comprobar parámetros y multipart | 200:Int32ApiResponseGlobal | Pendiente de backend/staging |
| OP-012 | GET `/api/DashboardSuscriptores/resumen` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-013 | GET `/api/DashboardSuscriptores/mis-solicitudes` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-014 | GET `/api/DashboardSuscriptores/mis-cotizaciones` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-015 | GET `/api/DashboardSuscriptores/mi-solicitud-reciente` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-016 | GET `/api/Orden/{guidId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-017 | GET `/api/Orden/cotizacion/{cotizacionGuidId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-018 | POST `/api/Orden` | CrearOrdenRequest | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-019 | POST `/api/Orden/{guidId}/cancelar` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-020 | POST `/api/Pagos/checkout/{ordenGuidId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-021 | POST `/api/Pagos/stripe/webhook` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-022 | GET `/pago/exitoso` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-023 | GET `/api/Pagos/resultado/{sessionId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-024 | POST `/api/SolicitudCiudades/{solicitudGuidId}/ciudad/{ciudadId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-025 | DELETE `/api/SolicitudCiudades/{solicitudGuidId}/ciudad/{ciudadId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-026 | POST `/api/SolicitudCiudades/{solicitudGuidId}/ciudades` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-027 | GET `/api/SolicitudCiudades/{solicitudGuidId}/ciudades` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-028 | PUT `/api/SolicitudCiudades/{solicitudGuidId}/ciudades` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-029 | DELETE `/api/SolicitudCiudades/{solicitudGuidId}/ciudades` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-030 | GET `/api/SolicitudCiudades/existe` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-031 | POST `/api/SolicitudCotizacionMensajes` | RegistrarMensajeCotizacionRequest | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-032 | GET `/api/SolicitudCotizacionMensajes/{solicitudCotizacionGuidId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-033 | PUT `/api/SolicitudCotizacionMensajes/{solicitudCotizacionGuidId}/leer` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-034 | GET `/api/SolicitudCotizacionMensajes/{solicitudCotizacionGuidId}/no-leidos` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-035 | GET `/api/Solicitudes/AllPaged` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-036 | GET `/api/Solicitudes/{guidId}` | Sin referencia / comprobar parámetros y multipart | 200:Solicitud_Busqueda_DTOApiResponseGlobal | Pendiente de backend/staging |
| OP-037 | DELETE `/api/Solicitudes/{guidId}` | SolicitudUpdateStatusDTO | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-038 | POST `/api/Solicitudes` | Solicitudes_Create_DTO | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-039 | POST `/api/SolicitudesImagenes/{solicitudGuidId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-040 | GET `/api/SolicitudesImagenes/solicitud/{solicitudGuidId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-041 | GET `/api/SolicitudesImagenes/{imagenGuidId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-042 | DELETE `/api/SolicitudesImagenes/{imagenGuidId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-043 | POST `/api/SolicitudYonkes/{solicitudGuidId}/enviar` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-044 | GET `/api/SolicitudYonkes/solicitud/{solicitudGuidId}/destinatarios` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-045 | PUT `/api/SolicitudYonkes/{solicitudYonkeGuidId}/vista` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-046 | GET `/api/SolicitudYonkes/TotalSolicitudesNuevas` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-047 | GET `/api/SolicitudYonkes/MasReciente` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-048 | GET `/api/SolicitudYonkes/MisSolicitudes` | Sin referencia / comprobar parámetros y multipart | 200:SolicitudYonke_List_DTOListApiResponseGlobal | Pendiente de backend/staging |
| OP-049 | GET `/api/Utilerias/entidades` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-050 | GET `/api/Utilerias/entidad/{id}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-051 | GET `/api/Utilerias/entidad/{entidadId}/ciudades` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-052 | GET `/api/Utilerias/ciudad/{id}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-053 | GET `/api/Utilerias/marcas` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-054 | GET `/api/Utilerias/marca/{id}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-055 | PUT `/api/Utilerias/marca/{id}` | Marcas | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-056 | POST `/api/Utilerias/marca` | Marcas | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-057 | GET `/api/Utilerias/modelos` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-058 | GET `/api/Utilerias/modelo/{id}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-059 | PUT `/api/Utilerias/modelo/{id}` | Modelos | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-060 | POST `/api/Utilerias/modelo` | Modelos | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-061 | POST `/api/YonkeAuth/login` | LoginYonkeRequest | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-062 | POST `/api/YonkeAuth/forgot-password` | ForgotPasswordRequest | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-063 | POST `/api/YonkeAuth/reset-password` | ResetPasswordViewModel | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-064 | GET `/api/YonkeAuth/reset-password-page` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-065 | GET `/api/Yonkes/byPage` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-066 | GET `/api/Yonkes/{guidId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-067 | POST `/api/Yonkes` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-068 | PUT `/api/Yonkes/updateInfo/byGuidId/{guidId}` | YunkeUpdateInfoDTO | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-069 | PUT `/api/Yonkes/ActualizarLogo` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-070 | PUT `/api/Yonkes/baja/byGuidId/{guidId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-071 | POST `/api/YonkesCalificaciones` | RegistrarCalificacionRequest | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-072 | GET `/api/YonkesCalificaciones/{yonkeGuidId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-073 | GET `/api/YonkesCoberturas/guid/{yonkeGuidId}` | Sin referencia / comprobar parámetros y multipart | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-074 | PUT `/api/YonkesCoberturas` | YunkeCoberturaDTO | 200:sin DTO referenciado | Pendiente de backend/staging |
| OP-075 | POST `/api/YonkesDispositivos` | RegistrarDispositivoDto | 200:sin DTO referenciado | Pendiente de backend/staging |
