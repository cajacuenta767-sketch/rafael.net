# Backend recibido: revisión inicial

Fecha: 4 de octubre de 2026.

Origen: ZIP proporcionado por el usuario, extraído sin sobrescrituras en `C:/Users/PC/Documents/YonkeWebApi_audit_20261004/YonkeWebApi-master`. Esta copia no tiene historial Git; no se ha comprobado correspondencia con Azure.

## Arquitectura comprobada

- `YonkeWebApi/ApiYonke.csproj`: ASP.NET Core, objetivo net9.0; controladores y configuración de dependencias.
- `Core`: DTO, entidades, interfaces y servicios de negocio.
- `Infra`: repositorios, contexto Entity Framework e implementaciones de infraestructura.
- Servicios de órdenes y pagos utilizan Unit of Work y repositorios. Las modificaciones futuras deben conservar estas convenciones y no trasladar validaciones de seguridad a Flutter.
- SDK .NET local disponible: 10.0.202. No se compiló ni ejecutó el servidor en esta revisión inicial; no se abrió conexión a su base de datos.

## Evidencia inicial de seguridad y funcionalidad

1. Program.cs configura JwtBearer y validación de emisor, audiencia, firma y vigencia. Esto es evidencia de configuración en fuentes, no validación dinámica ni garantía de secretos seguros.
2. Stripe ya contiene creación Checkout, cálculo desde orden, validación de propietario, comisión/destino Connect y verificación de webhook mediante `EventUtility.ConstructEvent`. Rectifica la dependencia anterior: hay implementación para auditar, no debe crearse otra desde cero.
3. `OrdenService.ActualizarEstatusAsync` valida propietario pero asigna el estado recibido sin verificar transición desde el estado actual. `OrdenController.Cancelar` llama ese método con 9. Riesgo: cancelar órdenes pagadas/completadas en servidor aunque Flutter no ofrezca la acción. Pendiente corrección y prueba de reglas de negocio.
4. `/pago/exitoso` es anónimo, consulta Stripe con session_id y devuelve estado e identificador PaymentIntent; su mensaje afirma éxito sin comprobar PaymentStatus. Debe evitar confirmaciones engañosas y revisar minimización de datos y autorización. No se explotó el endpoint.
5. Program.cs contiene CORS AllowAnyOrigin; revisar orígenes según clientes desplegados. CORS no sustituye autorización y no se califica como vulnerabilidad por sí solo.
6. `ObtenerResultadoPagoAsync` contiene comparación `usuarioId != usuarioId`, ineficaz; después sí comprueba `pago.UsuarioId != usuarioId`. No afirmar que ese método carece completamente de autorización: corregir código inútil y probar el control real.
7. Existen índices únicos de pagos/eventos en el contexto; aún falta revisar migraciones, manejo de concurrencia y eventos tardíos/duplicados. Un único StripeEventId en un pago no acredita un historial completo de deduplicación.
8. No se identificó proyecto de pruebas en el inventario inicial. Falta comprobar compilación, restauración de paquetes y pruebas antes de afirmar que nada está roto.

No se imprimieron archivos de configuración con credenciales ni se modificó Azure. No se cambió el backend en este bloque.
