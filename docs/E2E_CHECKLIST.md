# Prueba de punta a punta contra el API de Azure

Se ejecuta en un teléfono Android con una compilación que apunte al API
publicado (ver variables en `docs/API_INTEGRATION.md`). Se necesitan un
teléfono de cliente con SMS y una cuenta de yonke autorizada con cobertura en
la ciudad de prueba.

Antes de empezar:

```shell
dart run tool/api_probe.dart            # catálogos públicos
flutter test                            # incluye rutas contra docs/openapi_v1.json
```

| # | Paso | Resultado esperado | Resultado |
| --- | --- | --- | --- |
| 1 | Cliente: iniciar sesión con OTP | Entra al inicio; los contadores vienen del servidor | |
| 2 | Cliente: iniciar sesión con Google | Entra al inicio. Si falla con 401, revisar `Google:ClientId` en Azure | |
| 3 | Cliente: crear solicitud con 2 fotos | Pantalla de éxito; aparece en "Mis solicitudes" con sus fotos | |
| 4 | Cliente: cuarta solicitud del día | Mensaje de límite diario, sin solicitud fantasma | |
| 5 | Yonke: iniciar sesión | Entra al inicio con el total real de cotizaciones | |
| 6 | Yonke: bandeja | Aparece la solicitud del paso 3 | |
| 7 | Yonke: abrir la solicitud | Se marca como vista | |
| 8 | Yonke: cotizar con precio y foto | "Cotización enviada"; si el servidor rechaza, se ve su mensaje | |
| 9 | Cliente: cotizaciones recibidas | Aparece la cotización del paso 8 con su precio | |
| 10 | Cliente ↔ yonke: chat | Los mensajes llegan en segundos (tiempo real) o en menos de 15 s (sondeo) | |
| 11 | Yonke: push de nueva solicitud | Llega el aviso al crear otra solicitud (requiere Firebase) | |
| 12 | Sesión revocada o vencida | Cualquier pantalla lleva al login con "Tu sesión expiró" | |
| 13 | Modo avión | Error con "Reintentar"; nunca datos de ejemplo | |
| 14 | Cerrar sesión e iniciar con otra cuenta | No aparecen datos de la cuenta anterior | |
