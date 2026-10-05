# Plan: backend local y cambios SQL para entrega al cliente

Fecha: 4 de octubre de 2026. Estado: pendiente de ejecución completa. Complementa PLAN_CIERRE_BACKEND_APP.md; no sustituye su alcance de seguridad, Stripe ni app.

## Objetivo

Corregir y verificar el backend local con su arquitectura actual —ASP.NET Core, Core/Infra, servicios, Unit of Work, EF Core y SQL Server— y entregar código, scripts y pruebas para que el cliente los revise y publique en Azure.

No requiere acceso directo a producción para preparar cambios. Sí requiere estructura real y una copia SQL aislada para confirmar compatibilidad. Publicar código no actualiza la base automáticamente.

## Punto de partida

- Copia backend: C:/Users/PC/Documents/YonkeWebApi_audit_20261004/YonkeWebApi-master.
- Modelo EF de 35 entidades validado offline; no equivale a esquema Azure comprobado.
- Cambios locales de seguridad y permisos, OTP, aceptación y cancelación; todavía no desplegados.
- Índice único de orden por cotización e índice compuesto de conversación preparados en modelo y script.
- 45 comprobaciones HTTP aprobadas con repositorios simulados; no acreditan SQL, concurrencia ni pagos reales.
- Scripts en database: preflight de lectura, propuesta aditiva y guía. Sin migraciones/historial de Azure confirmado.

## Etapas y aprobación

### 1. Confirmar versión y estructura — P0

- [ ] Recuperar historial Git y commit correspondiente al ZIP; no convertir esta copia en reemplazo del repositorio sin comparar.
- [ ] Identificar versión de API desplegada y esquema SQL actual.
- [ ] Cliente ejecuta preflight de solo lectura y comparte estructura/índices/conteo de duplicados sin datos personales ni credenciales.
- [ ] Comparar columnas, tipos, claves, filtros, estados, restricciones e historial EF con el modelo local.

**Cierre:** diferencias registradas; no inventar una migración inicial para aplicarla a una base existente.

### 2. Completar correcciones locales — P0

- [ ] Revisar permisos de cada operación y campos editables; mantener comprobaciones en servicios y repositorios.
- [ ] Verificar significado de IDs cliente/Yonke/cotización con datos históricos; cualquier transformación requiere procedimiento aprobado.
- [ ] Resolver avisos de dependencias con actualización compatible y pruebas; separar riesgos de herramientas y runtime.
- [ ] Añadir manejo de conflicto de índice único al crear órdenes simultáneas: recuperar resultado autorizado o devolver conflicto consistente, sin duplicar ni ocultar errores.
- [ ] Completar concurrencia cancelación/webhook y transiciones financieras; no basta el guard de estado en memoria.
- [ ] Mantener OTP y lectura seguros bajo peticiones concurrentes.

**Cierre:** backend compila y pruebas de servicios/HTTP pasan; riesgos críticos restantes no se marcan resueltos por compilación.

### 3. Revisar scripts y cambios de esquema — P0

- [ ] Ajustar scripts al esquema real: nombres/tablas/columnas/índices/versión SQL.
- [ ] Confirmar política de una orden por cotización y revisar duplicados antes de crear restricción.
- [ ] Si hay duplicados, detenerse y resolver con cliente preservando órdenes, pagos y trazabilidad; no borrar automáticamente.
- [ ] Verificar índices existentes por definición, no solo nombre; revisar bloqueo, tiempo, volumen y espacio de creación.
- [ ] Elegir baseline EF o scripts versionados conforme al proceso real del cliente; documentar quién ejecuta y cómo se registra.
- [ ] Separar DDL de referencia para base vacía de actualización incremental de base existente.

**Cierre:** script revisado y trazable, sin secretos ni operaciones destructivas implícitas. No llamarlo probado hasta ejecutarlo en copia SQL.

### 4. Probar en SQL aislado — P0

- [ ] Cliente proporciona o prepara copia anonimizada/esquema equivalente, sin conexión ni envíos a servicios productivos.
- [ ] Comprobar respaldo y restauración antes de aplicar cambios.
- [ ] Ejecutar preflight, cambios propuestos y verificación posterior.
- [ ] Probar repetición del script, duplicados previos, definición incompatible, base incorrecta, timeout y fallo intermedio.
- [ ] Probar dos aceptaciones simultáneas: no más de una orden por cotización; respuesta API recuperable y consistente.
- [ ] Probar pago/cancelación simultáneos: no perder pago ni confirmar transición inválida.
- [ ] Verificar lectura, historial, perfiles, importes y datos existentes tras el cambio.

**Cierre:** evidencia de persistencia/constraints y resultados; cero pérdida de datos. Tests en memoria no sustituyen esta etapa.

### 5. Staging API + app — P1

- [ ] Publicar versión revisada a staging autorizado, con base/storage aislados y credenciales privadas del cliente.
- [ ] Probar cliente A/B y Yonke A/B: recursos propios accesibles, ajenos rechazados.
- [ ] Flujo solicitud → cotización → aceptación → orden → chat/lectura; reinicio y segundo dispositivo.
- [ ] Stripe exclusivamente test: Checkout, firma webhook, duplicados, eventos tardíos y resultado persistido.
- [ ] Confirmar que versión antigua de app no rompe con cambios de contrato/esquema; registrar excepciones.

**Cierre:** ambos roles funcionan sobre la misma versión y datos reales de staging; no simular éxito ante fallo del servidor.

### 6. Paquete de entrega al cliente — P1

- [ ] Código revisado en rama/commit identificados del repositorio correcto; no incluir cambios ajenos de Flutter.
- [ ] Scripts versionados, guía de aplicación, preflight y validación posterior.
- [ ] Informe de pruebas y pendientes; configuraciones de ejemplo sin secretos.
- [ ] Lista de variables necesarias, orden de cambio de esquema/código y acciones manuales del cliente.
- [ ] Procedimiento de recuperación compatible; no eliminar restricciones o datos financieros automáticamente como rollback.
- [ ] Excluir bin/obj, credenciales, ZIP originales y herramientas de pruebas de la publicación del sitio.

**Cierre:** cliente puede reproducir y revisar la entrega. Proyecto servidor a publicar: YonkeWebApi/ApiYonke.csproj, no proyectos de regresión.

### 7. Publicación Azure por el cliente — P0 antes de producción

- [ ] Responsable confirma ambiente, versión, respaldo, ventana y plan de recuperación.
- [ ] Aplicar cambios autorizados de esquema y publicar API en el orden probado en staging.
- [ ] Verificar salud, logs privados, permisos, órdenes, mensajes, webhook y errores; identificar commit/build desplegado.
- [ ] Detener entrega si hay errores críticos, duplicados o contradicción de pagos; activar recuperación preparada.

**Cierre:** evidencia de versión y pruebas posteriores. No se autoriza ni ejecuta producción por crear este plan.

## Responsabilidades y dependencias

Trabajo local: revisar/corregir código y scripts, compilar y preparar pruebas/documentación. Cliente: confirmar esquema y política comercial, proporcionar entorno aislado/acceso autorizado, configurar secretos y aprobar/aplicar publicación Azure. No pedir contraseñas o cadenas de conexión por chat.

Si no hay copia SQL disponible, se continúa con código/modelo/scripts y se deja explícitamente pendiente la validación SQL; no afirmar entrega lista para producción.

## Registro mínimo por tarea

ID, prioridad, estado, archivos/objetos SQL afectados, motivo, prueba, resultado, versión y riesgo pendiente. Mantener evidencia de fallos corregidos, no solo el resultado final.

**Primera acción:** comparar el preflight con el modelo y completar manejo de conflictos/concurrencia local. No ejecutar scripts Azure para descubrir si funcionan.
