# REFANET: resultados de adaptación responsive

Fecha: 2 de octubre de 2026. Alcance: código local; sin publicación en GitHub ni despliegue o modificaciones de registros en Azure.

## Estado real

La presentación anterior fue rechazada por el usuario por contenido diminuto y evidencia de tamaños mal interpretada. La ejecución del plan **no está certificada como terminada al 100 %**: siguen pendientes la revisión visual individual de todas las combinaciones, las distribuciones lista/chat de dos paneles y las comprobaciones en plataformas e interacciones reales indicadas abajo. No se sustituyen esos pendientes por resultados de widgets.

## Corrección del 2 de octubre: tamaños y evidencia

- Acceso del cliente: no confunde escritorio con móvil horizontal; formulario de una columna, botones de al menos 52 px lógicos y texto principal de 16 px. Logo de 220 px en escritorio, 140 px en móvil y 64 px en ventanas cortas. Usa desplazamiento en lugar de comprimir controles.
- Contenedor compartido ampliado a 1200 px; navegación y botón flotante respetan el mismo límite. No hay escalado global por resolución.
- Revisión de solicitud: contenido hasta 1040 px y tarjetas en dos columnas cuando hay espacio; una columna en móvil.
- Nuevos perfiles representativos explícitos (12 ventanas con DPR 1/2/3). Las capturas registran metadatos de tamaño lógico, físico y PNG; no son hardware real.
- Galería: perfiles representativos por defecto, pruebas antiguas/extremas opcionales y visor al 100 % lógico. La miniatura no es aprobación visual.
- Las métricas automáticas de abajo corresponden a la ejecución anterior y no certifican el diseño corregido. Los nuevos resultados se registran por separado.

### Resultados de la corrección

| Comprobación | Resultado |
| --- | --- |
| Captura de todos los apartados | 468 casos pasaron: 39 pantallas × 12 perfiles representativos; `build/responsive_devices_all.log` |
| Texto al 200 %, rotación, teclado y estados adicionales | 39 casos pasaron en celular compacto; `build/responsive_devices_accessibility.log` |
| Repetición tras mejorar tipografía de revisión y Home del Yonke | 12 + 12 perfiles normales y 1 + 1 ampliados pasaron; logs `build/responsive_devices_*_final.log` |
| Acceso y contenedor responsive | 65 pruebas pasaron; `build/responsive_size_tests.log` |
| Regresión de solicitudes, Home del Yonke y widgets | 172 pruebas pasaron; `build/responsive_size_regression.log` |
| Análisis estático y web | Sin incidencias de análisis; compilación web correcta; logs `build/responsive_size_analyze.log` y `build/responsive_size_web.log` |

Se revisaron individualmente capturas del acceso en móvil, horizontal, tablet y escritorio, Home del cliente en tablet horizontal, y revisión/Home del Yonke en escritorio. No se revisaron visualmente las 507 capturas una por una ni se probó hardware real; los demás casos mantienen el estado pendiente individual en la galería. La comprobación HTTP y de sintaxis del visor no equivale a prueba de interacción completa en navegador.

La aplicación compilada está disponible en `http://127.0.0.1:8767/`; la evidencia nueva, en `http://127.0.0.1:8768/index.html`. Datos sintéticos solo en el harness de capturas; no se modificó autenticación ni API de producción.

## Cambios realizados

- Contenedor común de contenido y navegación (960 px en la ejecución inicial, 1200 px tras la corrección); formularios existentes conservan sus límites propios. Botones flotantes alineados con el contenido, no con el extremo del monitor.
- Inicio del cliente con columnas en ventanas amplias; saludo y auto sin superposición; botón y tarjetas con altura natural. Métricas del Yonke reorganizadas según espacio y escala de texto.
- Acceso y bienvenida desplazables en ventanas pequeñas, horizontales y con teclado. No se exige que toda la decoración quepa simultáneamente.
- Filas, indicadores de pasos y tarjetas se reorganizan; las etiquetas de datos no se eliminan al pasar a columna. La navegación inferior respeta el texto ampliado y gana altura cuando hace falta.
- Formularios, selección de fotos, calificación, paneles rápidos y datos de contacto del Yonke admiten desplazamiento. Se mantiene Inicio primero y la función existente del botón central. Sin hamburguesa derecha nueva.
- El chat del cliente no fuerza el salto al final durante una actualización si se está leyendo historial.
- Manejo de error de fotos en paralelo al detalle del Yonke: evita una excepción asincrónica sin manejar. Reputación sin identificador: muestra información no disponible, no un cargador permanente.

En ventanas con muy poca altura útil, el contenedor habilita un desplazamiento exterior para que el cuerpo no tenga un viewport de altura cero. En altura normal permanece inmóvil y el desplazamiento corresponde a la página. Esta es una excepción deliberada a evitar scrolls anidados.

## Evidencia automática

| Conjunto | Cobertura y resultado |
| --- | --- |
| Matriz base | 136 ventanas × 39 pantallas = 5.304 casos; pasaron. `build/responsive_matrix_a.log` y `build/responsive_matrix_b.log` |
| Límites y multiventana | 46 ventanas × 39 pantallas = 1.794 casos; pasaron. `build/responsive_limits_final.log` |
| Regresión general | 442 pruebas pasaron; `build/responsive_regression_final.log`. Incluye contratos con respuestas simuladas, acceso, pedidos, cotizaciones, mensajes, perfiles y widgets |
| Componentes responsive | Ancho máximo, etiquetas preservadas, tarjetas con texto ampliado, botón flotante y reputación sin id; `build/responsive_components_final.log` |
| Correcciones finales estrechas | 320 × 480, 480 × 320, 280 × 653 y 653 × 280; 156 casos; pasaron. `build/responsive_final_narrow.log` |
| Botón flotante final | Direcciones en 136 ventanas; pasaron. `build/responsive_fab_final.log` |
| Texto y zonas seguras | Texto 200 % en 320 × 480; 130 % y 150 % en 480 × 320; 200 % en 768 × 1024. Muestreo DPR 1/2/3 y recortes laterales simulados; logs `responsive_accessibility`, `responsive_text130`, `responsive_text150` y `responsive_text200tablet` |
| Contenido | 39 pantallas por escenario: datos largos/precio grande, respuestas vacías, errores 503 y fotos sintéticas de cuatro proporciones; logs `responsive_long`, `responsive_empty`, `responsive_errors` y `responsive_photos` |
| Combinación extrema | 320 × 480, texto al 200 % y datos largos/precio grande juntos; `build/responsive_long200.log`. Se corrigió la fila del encabezado de cotización del chat para no dejar el título sin ancho |
| Transiciones y paneles | Giro, comparación de valores de controladores existentes, teclado simulado, acciones centrales, editor del Yonke y panel de contacto en perfiles seleccionados. No certifica todas las subpantallas ni el teclado real |
| Análisis | `flutter analyze --no-pub`; resultado final en `build/responsive_analyze_final.log` |
| Web | Compilación local confirmada; `build/responsive_web_build.log`. Compilar no demuestra interacción correcta en navegador |

Los tamaños son lógicos. DPR modifica píxeles físicos sin convertir una ventana simulada en un dispositivo real. Las pruebas de giro pueden revelar campos construidos de forma diferida: comparan los valores ya existentes, no la cantidad de widgets visibles.

La combinación extrema también pasó sus 39 pantallas; después de la última corrección se repitieron las 12 pruebas de chat y componentes (`build/responsive_chat_final.log`). La compilación web final volvió a confirmarse. La sintaxis del JavaScript de la galería se validó con `node --check`; esto no sustituye probar sus controles en un navegador.

Las capturas de ventanas mayores de 1600 de ancho se reducen para almacenar evidencia: las dimensiones del PNG no deben confundirse con el viewport de prueba. Los identificadores de las ventanas divididas se muestran como enteros; los anchos fraccionarios exactos están definidos por los porcentajes y separación simulada en el capturador.

Las capturas incluyen segmentos desplazados con solapamiento. El capturador espera recursos visibles y rechaza cargadores visibles pendientes; no espera indefinidamente animaciones retenidas fuera del viewport por una lista. Las imágenes de referencia técnicas se actualizaron después de revisar sus diferencias y repetir los flujos, no en lugar de probarlos.

## Galería y seguimiento

- `build/responsive/index.html`: filtros por perfil, rol y apartado; PNG ampliado y enlaces a segmentos/estados.
- `build/responsive/manifest.json`: evidencias existentes y entorno.
- `build/responsive/seguimiento.csv`: registro por perfil/pantalla; revisión individual y certificación funcional por dispositivo no se marcan como aprobadas automáticamente.
- `build/responsive/*/review_*.png`: hojas de contacto para revisar composición. Se revisaron muestras compactas, horizontales, tablet y escritorio; no se presenta ese muestreo como revisión exhaustiva de las más de siete mil combinaciones.

Los segmentos históricos anteriores a la captura principal más reciente no se incluyen en el manifiesto. Los PNG previos se conservan en el directorio de trabajo, sin borrarlos.

## Pendientes y limitaciones

1. Revisar y registrar individualmente todas las capturas y todos los controles secundarios: aceptación legal/OTP visual, filtros, selectores, foto ampliada, validaciones, menús, editor de cotización, edición de logotipo y estados de red durante interacción.
2. Implementar y validar lista/detalle y lista/chat en dos paneles donde corresponda, incluida selección, Atrás y conservación de contexto. Hoy siguen siendo rutas separadas con lectura limitada.
3. Verificar teclado físico, Tab/Enter/Escape, ratón/rueda, foco visible y acciones por control remoto. No hay certificación de Android TV/Apple TV.
4. Verificar bisagras y oclusiones de plegables, plegado/desplegado real, giros a ambos lados y vertical invertido. Una ventana casi cuadrada no reproduce esos eventos.
5. Ejecutar zoom real de navegador 100/125/150/200 % y escala real del sistema, distintos de la escala de texto de widgets.
6. Ejecutar Android/iOS/tablet/TV en hardware o emuladores apropiados. `flutter devices` solo detectó Windows, Chrome y Edge; no había teléfono conectado. Las herramientas de control de Windows y navegador fallaron al inicializar con `failed to write kernel assets ... (os error 3)`. No se usó otra automatización de escritorio para saltar esa limitación.
7. Comprobar la integración real con Azure usando sesiones autorizadas y sin crear o borrar registros de producción fuera del alcance. Estas pruebas usan servicios reemplazados, no un JWT real ni SMS.

No se afirma compatibilidad universal ni que todo el plan esté aprobado visualmente. Los pendientes anteriores permanecen abiertos en el plan.

## Reproducir

```powershell
flutter analyze --no-pub
flutter test --no-pub -j 1 --fail-fast --dart-define=GALLERY_MATRIX=true --dart-define=GALLERY_FOLDER=build/responsive/matrix test/app_gallery_capture_test.dart
flutter test --no-pub -j 1 --fail-fast --dart-define=GALLERY_BOUNDARIES=true --dart-define=GALLERY_FOLDER=build/responsive/limites test/app_gallery_capture_test.dart
flutter test --no-pub -j 1 --dart-define=GALLERY_WIDTH=320 --dart-define=GALLERY_HEIGHT=480 --dart-define=GALLERY_TEXT_SCALE=2 --dart-define=GALLERY_EXTRA_STATES=true --dart-define=GALLERY_FOLDER=build/responsive/accesibilidad test/app_gallery_capture_test.dart
flutter test --no-pub test/responsive_gallery_index_test.dart test/responsive_contact_sheet_test.dart
```

Variantes: `GALLERY_DPR=2` o `3`; `GALLERY_SAFE=left` o `right`; `GALLERY_CONTENT=long`, `empty`, `error` o `photos`. `GALLERY_START` y `GALLERY_TAKE` permiten dividir la matriz en lotes sin cambiar los perfiles. Capturador local de Windows: requiere las fuentes y el SDK en las rutas usadas por el proyecto.
