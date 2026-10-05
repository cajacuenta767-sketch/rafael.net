# Pruebas HTTP de seguridad del backend

Fecha: 4 de octubre de 2026. Resultado final: **45 comprobaciones aprobadas: 34 peticiones HTTP y 11 comprobaciones de efectos/identidad/importe**.

## Método y alcance

Se utilizó HttpClient contra Kestrel en loopback con puerto asignado automáticamente. El proyecto `HttpSecurityRegression` carga controladores de la API y utiliza los servicios reales `SolicitudCotizacionMensajeService`, `OrdenService`, `CurrentUserService` y el middleware de errores. JwtBearer verifica tokens firmados con una clave efímera generada en memoria para las pruebas. No se imprimen ni guardan JWT.

Repositorios y proveedores externos son sustitutos en memoria. No se ejecuta el Program de producción, no se carga su configuración privada ni se conecta a SQL, Azure, SMS, Stripe, Firebase o SignalR real. El host se detiene incluso si falla una aserción. Los JWT de prueba no sirven para Azure.

Es prueba HTTP real de una composición aislada, no un arranque completo con configuración de producción ni una validación del esquema SQL. No se usó Postman: el ejecutable permite repetir los casos y falla si la respuesta cambia.

## Casos aprobados

- Historial y no-leídos: sin JWT, inválido, vencido o emisor incorrecto → 401; rol no permitido, cliente ajeno y Yonke ajeno → 403. Dueño cliente y Yonke asignado → 200. Rechazos no consultan repositorio de mensajes.
- Lectura: sin JWT → 401; tercero → 403 sin escritura; participantes → 204.
- Cotización inexistente y GUID mal formado → 404.
- Envío: tercero → 403 sin escritura; texto vacío → 400; cliente/Yonke autorizados → 200, guardando identidad y tipo de remitente correctos. Notificaciones simuladas, no se acredita entrega real.
- Cancelación: tercero → 403 sin efectos; pagada → 409 y conserva estado; pendiente → 200 y estado 9; reintento → 200 sin otra escritura/SaveChanges.
- Creación de orden: JSON inválido → 400; cliente acepta cotización creada por asociado → 200; orden pertenece al cliente y conserva importe calculado por servicio (fixture de 500 MXN).

## Errores descubiertos y corregidos durante las pruebas

1. Primera ejecución: configuración vacía del host de prueba impedía arrancar. Se añadió proveedor de configuración en memoria; sin modificar configuración productiva.
2. Segunda ejecución: cotización inexistente devolvía 500, no 404. Se cambió excepción genérica por KeyNotFoundException en el servicio y se repitió.
3. Validación de mensaje vacío: excepción genérica reemplazada por ArgumentException para devolver 400. Se añadió caso y se repitió toda la suite final hasta aprobar.

Compilación del proyecto de pruebas y dependencias: 0 errores. Advertencias de dependencias anteriores siguen abiertas, incluida NU1903 de AutoMapper; aprobar esta suite no elimina ese riesgo.

## Cómo repetir

Desde `C:/Users/PC/Documents/YonkeWebApi_audit_20261004/YonkeWebApi-master`:

```powershell
dotnet build HttpSecurityRegression/HttpSecurityRegression.csproj --no-restore -v quiet -clp:ErrorsOnly
dotnet run --project HttpSecurityRegression/HttpSecurityRegression.csproj --no-build --no-restore
```

Requiere restauración previa de paquetes y SDK/runtime .NET 10 para este ejecutable; backend permanece net9.0. No publicar ni desplegar el ejecutable de pruebas como API.

## Todavía pendientes

Pruebas de todas las rutas/roles, firmas/audiencias JWT adicionales, OTP HTTP y límites, integración con SQL real aislado, carreras cancelación/webhook, idempotencia de pagos/mensajes, archivos, SignalR, Stripe test y comparación con despliegue Azure. Validación definitiva exige staging autorizado y configuración privada del propietario.
