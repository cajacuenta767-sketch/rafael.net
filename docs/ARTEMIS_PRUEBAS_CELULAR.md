# Artemis — instalación y verificación

Fecha: 2026-10-04. Repositorio oficial instalado en `C:/Users/PC/Documents/artemis_mobile_testing`, entorno virtual aislado; dependencias del lockfile instaladas con `uv sync --frozen --no-dev`.

## Verificado

- Samsung SM-A356E autorizado por ADB, resolución 1080 × 2340.
- App `com.refanet.app` instalada; abierta sin borrar datos ni reinstalarla.
- Servidor MCP registrado en Codex y probado mediante cliente MCP local.
- Cinco herramientas disponibles: estado, diagnóstico, trazas, gestión y ejecución de tareas.
- Captura real obtenida mediante `mobile_get_device_state` en `C:/Users/PC/Documents/artemis_mobile_testing/live_screenshot_RFCX40ZR43X.jpg`.

## Límites y pendientes

- No se ejecutó ningún recorrido autónomo ni se validaron solicitudes, pagos o mensajes.
- Falta una clave de API de un proveedor de modelos. El diagnóstico no detectó ninguna. No pegar claves en el chat: configurar localmente el `.env` de Artemis, por ejemplo `GEMINI_API_KEY`.
- Falta scrcpy para grabación/repetición de vídeo; no bloquea esta captura.
- Puerto propio 8775 para no interferir con el programa que ocupa 8000.
- No se instalaron reglas globales ni se modificó Antigravity.
- Helper de accesibilidad automático desactivado; se usa UIAutomator2. No se mantiene despierto el teléfono.
- Las pruebas con IA pueden enviar pantallas al proveedor y consumir su cuota de API: usar cuentas de prueba y evitar datos personales. No se hicieron llamadas a modelos en esta verificación.

## Continuación segura

1. Configurar clave local y recargar la conexión MCP de Codex.
2. Diagnosticar de nuevo antes de iniciar tareas.
3. Explorar bienvenida, accesos y navegación; capturas con teclado y orientación.
4. Ejecutar flujos cliente–yonke solamente con cuentas y entorno de prueba identificados. No efectuar pagos reales ni publicar datos de producción.
5. Registrar fallos y capturas; distinguir pruebas visuales de comprobaciones API/SQL.

Para retirar la integración: `codex mcp remove artemis`. Esto no borra la carpeta instalada ni los artefactos.
