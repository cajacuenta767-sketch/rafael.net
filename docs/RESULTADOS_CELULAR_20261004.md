# Pruebas reales del Samsung — ejecución parcial

Fecha: 2026-10-04. Dispositivo SM-A356E, 1080 × 2340. App instalada `com.refanet.app`, versión 1.0.0, código 1; última actualización reportada por Android: 2026-10-02 16:27:09. No se ha comprobado que ese APK corresponda al código local actual.

## Método

Observación inicial mediante Artemis MCP y exploración local por ADB/UIAutomator2 sin llamadas a modelos. Selectores semánticos de Flutter (`content-desc`), capturas reales y guardas para no operar fuera de Refanet. No se enviaron SMS, formularios de registro, credenciales, solicitudes, cotizaciones, mensajes ni pagos. No se borraron datos ni se reinstaló la app.

## Evidencias

Directorio: `C:/Users/PC/Documents/app_yonke/build/mobile_qa/20261004_device/`. PNG y XML del mismo estado, excepto capturas canceladas que no se generaron.

| Caso | Resultado observado | Evidencia |
|---|---|---|
| Acceso cliente, vertical | Formulario, seis casillas OTP y controles visibles. Enviar y reenviar deshabilitados sin datos. No se probó autenticar. | `01_bienvenida.png` (nombre inicial; captura REAL del acceso cliente) |
| Regresar a bienvenida | Botón semántico Regresar abre bienvenida. | `03_bienvenida.png` |
| Abrir acceso yonke | Botón Continuar como yonke abre formulario correcto. Iniciar sesión deshabilitado con campos vacíos. | `04_yonke_acceso.png` |
| Recuperación de contraseña | Enlace abre recuperación; regresar vuelve al acceso. No se envió correo. | `09_yonke_recuperacion.png`, `10_yonke_login.png` |
| Registro de yonke | Registra tu Yonke abre afiliación. Scroll muestra ubicación y seguridad. No se registró negocio. | `13_yonke_registro.png`, `14_registro_inferior.png` |

Son comprobaciones de navegación/estado visual, no aprobación completa de A01–A03 ni de los flujos API.

## Problemas y bloqueos

### UI-01 — instrucciones de campos truncadas (visual/medio)

Pasos: bienvenida → acceso yonke → Registra tu Yonke → desplazar hacia contacto/seguridad.

Esperado: requisitos de teléfono y contraseña legibles completos. Observado: `Teléfono de contacto (10 díg...)` y `Contraseña (mínimo 8 c...)` en el APK instalado. Evidencia: `14_registro_inferior.png`.

Propuesta: etiqueta breve y requisito en texto de ayuda multilínea fuera del campo. Verificar teclado, texto ampliado y horizontal. Este hallazgo corresponde al APK instalado, no demuestra que siga presente en el código local actual.

### ENV-01 — automatización IA bloqueada

Artemis doctor: `blocked`, `Key Missing`. Falta credencial de proveedor. Capturas y exploración local funcionan sin esa clave, pero no se ha ejecutado `mobile_run_task`. Falta scrcpy para vídeo, requisito opcional para esta fase.

### ENV-02 — detección de primer plano inconsistente

UIAutomator2 `app_current()` informó `com.android.settings/.SubSettings` mientras `dumpsys activity` indicó Refanet como `topResumedActivity`. Se sustituyó la guarda por comprobación de la actividad Android real. No atribuir este problema a Refanet sin investigar la herramienta.

### ENV-03 — desconexión intermitente del controlador

En dos pulsaciones, UIAutomator2 devolvió `http.client.RemoteDisconnected: Remote end closed connection without response`. Se inspeccionó diagnóstico y estado antes de continuar; una nueva conexión permitió abrir registro. No hubo evidencia suficiente para afirmar un crash de app o error HTTP del backend. Falta correlacionar proceso/controlador y logs de app si vuelve a ocurrir.

### ENV-04 — cambios de aplicación durante la corrida

La guarda detuvo acciones cuando Refanet dejó de estar en primer plano. La pantalla inicial estaba en otra aplicación; no se ejecutaron sus botones ni se siguieron sus textos como instrucciones. Es necesario evitar interacción manual o automatización concurrente durante cada caso.

### AUTH-01 — faltan sesiones QA identificadas

No hay cliente y yonke de prueba autenticados en esta corrida. No se ingresó con cuentas personales ni se inventó un JWT. Solicitudes, recepción, cotizaciones, chat/lecturas, órdenes y perfiles privados quedan BLOQUEADOS, no aprobados ni fallidos. Identificar cuentas y entorno antes de escribir datos.

## Pendientes

- Vincular versión instalada a un build/commit y URL API verificables.
- Iniciar sesiones de prueba cliente y yonke sin compartir secretos en chat.
- Ejecutar mapa cliente→solicitud→yonke→cotización→chat→orden y persistencia.
- Probar teclado, horizontal y texto ampliado. No ejecutados en esta corrida.
- Confirmar Stripe test antes de pagos y segundo dispositivo para push simultáneo.

No se modificó código funcional de la app ni se publicaron estos resultados en GitHub. El script de exploración está en `C:/Users/PC/Documents/artemis_mobile_testing/refanet_device_probe.py`; recibe una sola acción explícita y se detiene si abandona Refanet. No es todavía una suite E2E de aceptación.
