# Preparación local para entrega al cliente

Fecha: 4 de octubre de 2026.

Plan detallado y criterios de cierre: [PLAN_ENTREGA_BACKEND_SQL_AZURE.md](PLAN_ENTREGA_BACKEND_SQL_AZURE.md).

Backend modificado en C:/Users/PC/Documents/YonkeWebApi_audit_20261004/YonkeWebApi-master. Se conserva ASP.NET Core/Core/Infra, Unit of Work, EF Core y SQL Server. No se instaló otra base ni se cambió proveedor.

Se verificó el modelo EF offline: **35 entidades**, índice único de orden por cotización e índice compuesto de conversación. Se generó DDL de referencia para base vacía, NO un script para recrear la base Azure ni una migración validada sobre datos existentes.

Archivos entregables dentro del backend:

- database/001_preflight_readonly.sql: estructura/índices y conteo de duplicados sin datos personales.
- database/002_security_indexes_review.sql: propuesta aditiva, exige nombre exacto de base, comprueba columnas/duplicados, usa transacción y no borra registros. Requiere revisión y prueba SQL por el cliente antes de aplicar.
- database/README.md: pasos de copia/staging, respaldo, revisión, aplicación y pendientes.
- DatabaseSchemaReview: herramienta reproducible que valida modelo y genera referencia sin abrir conexión.

HTTP posterior a cambios de modelo: **45 comprobaciones aprobadas**, con repositorios simulados. Modelo EF validado no significa DDL ejecutado ni carreras SQL verificadas.

Pendientes críticos: esquema real y baseline/migraciones, SQL aislado, recuperación ante conflicto único, concurrencia pago/cancelación, almacenamiento durable de eventos Stripe, relaciones e identidades históricas y dependencias vulnerables notificadas por NuGet. En esta ejecución también aparecieron avisos de Microsoft.Build/NuGet transitivos; distinguir herramientas de compilación y dependencias de runtime antes de actualizar.

No se accedió a la base real ni se desplegó Azure. Publicar API no aplica índices automáticamente. El cliente debe coordinar cambio de esquema y código; no publicar proyectos de pruebas como servidor ni ejecutar referencia CREATE sobre una base existente.
