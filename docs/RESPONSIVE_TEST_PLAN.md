# Plan de pruebas responsivas

Cómo comprobar que las pantallas de refaNet se ven y funcionan en teléfonos
pequeños y grandes, plegables, tablets, laptop y escritorio (web), con y sin
texto agrandado. El objetivo de este plan es **detectar** problemas y dejarlos
registrados; no rediseña la app. Hoy la interfaz está pensada para teléfono:
navegación inferior en todos los tamaños y contenido centrado con un ancho
máximo de 520 a 760 dp. En tablet y escritorio se espera que "estire", no que
rompa.

## 1. Alcance

| Incluye | No incluye |
| --- | --- |
| Pantallas de cliente y de yonke listadas en la sección 5 | Rediseño de layouts (NavigationRail, grids adaptativos) |
| Tamaños, orientación, DPR y escala de texto | Pruebas de red o de flujo (ver `E2E_CHECKLIST.md`) |
| Android, iOS, web en Chrome; escritorio a nivel informativo | Comparación píxel a píxel (los goldens existentes siguen a 390×844) |

## 2. Matriz de dispositivos

Definida en `test/support/dispositivos_prueba.dart`. Los tamaños son lógicos
(dp); el tamaño físico es lógico × DPR.

| Categoría | id | Dispositivo de referencia | Lógico | DPR | Orientación | Cómo se prueba |
| --- | --- | --- | --- | --- | --- | --- |
| Teléfono pequeño | android-320 | Android compacto | 320×640 | 2 | vertical | auto + físico |
| Teléfono pequeño | galaxy-s8 | Galaxy S8 / gama baja | 360×640 | 3 | vertical | auto |
| Teléfono medio | iphone-se | iPhone SE 2/3 | 375×667 | 2 | vertical | auto |
| Teléfono medio | iphone-14 | iPhone 13/14 | 390×844 | 3 | vertical | auto + físico |
| Teléfono medio | pixel-7 | Pixel 7 | 412×915 | 2.625 | vertical | auto + físico |
| Teléfono grande | iphone-15-pro-max | iPhone 15 Pro Max | 430×932 | 3 | vertical | auto |
| Teléfono medio | iphone-14-horizontal | iPhone 13/14 | 844×390 | 3 | horizontal | auto + físico (rotar) |
| Teléfono grande | iphone-15-pro-max-horizontal | iPhone 15 Pro Max | 932×430 | 3 | horizontal | auto |
| Plegable | plegable-cerrado | Galaxy Z Fold, pantalla exterior | 344×882 | 2.6 | vertical | auto + físico si hay |
| Plegable | plegable-abierto | Pixel Fold abierto | 673×841 | 2.6 | vertical | auto + físico si hay |
| Tablet 7-8" | tablet-7 | Tablet Android 7" | 600×960 | 2 | vertical | auto + físico |
| Tablet 7-8" | ipad-mini | iPad mini | 768×1024 | 2 | vertical | auto |
| Tablet 10-13" | tablet-10 | Tablet Android 10" | 800×1280 | 1.5 | vertical | auto + físico |
| Tablet 10-13" | ipad-air | iPad Air | 820×1180 | 2 | vertical | auto |
| Tablet 10-13" | ipad-pro | iPad Pro 12.9" | 1024×1366 | 2 | vertical | auto |
| Tablet 10-13" | ipad-air-horizontal | iPad Air | 1180×820 | 2 | horizontal | auto |
| Tablet 10-13" | ipad-pro-horizontal | iPad Pro 12.9" | 1366×1024 | 2 | horizontal | auto |
| Laptop / web | ventana-escritorio | Ventana por defecto Windows/Linux | 1280×720 | 1 | horizontal | auto + Chrome |
| Laptop / web | laptop-hd | Laptop HD | 1366×768 | 1 | horizontal | auto + Chrome |
| Laptop / web | macbook-air | MacBook Air | 1440×900 | 2 | horizontal | auto |
| Escritorio | escritorio-fhd | Monitor Full HD | 1920×1080 | 1 | horizontal | auto + Chrome |

Escalas de texto:

| Tier | Escalas | Dispositivos |
| --- | --- | --- |
| Humo | 1.0 | Todos |
| Accesibilidad | 1.3 ("Grande"), 1.5 ("Muy grande") | android-320, iphone-14, ipad-mini, laptop-hd |
| Extrema (solo manual) | 2.0 | El teléfono físico con la fuente del sistema al máximo |

## 3. Qué se automatiza y qué es manual

**Automatizado** (`flutter test`, corre en CI):

- Ninguna pantalla lanza excepciones de layout (`RenderFlex overflowed`,
  `BoxConstraints` inválidos, etc.) en ningún dispositivo de la matriz.
- Los textos y llaves clave de cada pantalla están presentes.
- La navegación inferior, cuando existe, queda completa dentro de la pantalla.
- Se genera una captura PNG por pantalla y dispositivo para revisión visual.

**Manual** (dispositivo físico o Chrome): rotación con estado, teclado, áreas
seguras (notch, barra de gestos), pantalla dividida, abrir y cerrar un
plegable, multitarea en iPad, legibilidad real y objetivos táctiles.

Nota sobre las capturas automáticas: `flutter_test` usa una fuente de prueba
que dibuja rectángulos en lugar de letras y es más ancha que Roboto o SF. Por
eso los textos se ven como bloques, la detección de overflow es pesimista (un
overflow de pocos píxeles puede no reproducirse en un teléfono real) y las
capturas sirven para revisar composición y espacios, no tipografía. Un
overflow de decenas de píxeles sí indica un problema real de layout.

## 4. Cómo ejecutar

Todo el tier automático:

```shell
flutter test test/responsive
```

Solo verificación, sin generar capturas (más rápido):

```shell
flutter test --exclude-tags capturas
```

Solo capturas (quedan en `build/screenshots/<pagina>/<dispositivo>.png`; las
de texto x1.3 llevan sufijo `_x1.3`):

```shell
flutter test --tags capturas
```

Un solo dispositivo o una sola pantalla:

```shell
flutter test test/responsive --name "ipad-pro"
flutter test test/responsive --name "cliente-home"
```

En GitHub Actions cada corrida publica el artefacto `capturas-responsivas`
(pestaña **Summary** de la corrida, sección **Artifacts**) con la misma
carpeta `build/screenshots`, incluidas las capturas de los tests legado en
`build/screenshots/legado/`.

Para laptop y escritorio también se puede correr la app en Chrome:

```shell
flutter run -d chrome
```

y usar **Chrome DevTools → Toggle device toolbar** con los tamaños de la tabla
(1280×720, 1366×768, 1920×1080), o simplemente redimensionar la ventana.

### Agregar una pantalla a la matriz

1. Crear o reutilizar un doble en `test/support/dobles_responsivos.dart`.
2. Agregar una entrada `PaginaPrueba` en
   `test/responsive/paginas_responsivas.dart` con textos o llaves clave que
   estén visibles sin hacer scroll en un teléfono de 320×640.
3. Correr `flutter test test/responsive --name "<id>"`.

### Registrar un hallazgo conocido

Cuando un test de la matriz falla por un problema real de layout:

1. Anotarlo en la tabla de la sección 8 con un ID `RESP-xx`.
2. Agregar la clave `pagina@dispositivo` (o `pagina@dispositivo@x1.3`) en
   `test/support/hallazgos_conocidos.dart` con el ID como razón. El test queda
   saltado; la captura se sigue generando como evidencia.
3. Al corregir el layout, quitar la entrada y confirmar que el test pasa.

## 5. Checklist manual por pantalla

Se recorre en cada dispositivo físico disponible, en vertical y horizontal, con
la fuente del sistema normal y luego en "Grande".

| # | Pantalla | Qué revisar | Resultado esperado | Resultado |
| --- | --- | --- | --- | --- |
| 1 | Inicio (elegir rol) | Logo y dos botones | Ambos botones visibles sin scroll; en horizontal se acomodan en fila | |
| 2 | Cliente: ingreso | Selector de país, teléfono, código, Google/Apple | Todo cabe sin scroll (es una pantalla fija); con teclado abierto el campo enfocado sigue visible | |
| 3 | Cliente: inicio | Hero de 164 dp, banner de 156 dp, accesos, solicitudes | Texto del hero no se encima con la imagen; el banner no corta el texto con fuente grande | |
| 4 | Cliente: nueva solicitud | Grids de 3 y 2 columnas | Las tarjetas no cortan texto en 320 dp ni con fuente grande | |
| 5 | Cliente: fotos, ciudad, revisión | Grids de fotos y resumen | Sin overflow; botón de continuar alcanzable | |
| 6 | Cliente: mis solicitudes y detalle | Lista y tarjetas | Sin overflow; fechas y folios completos | |
| 7 | Cliente: cotizaciones y detalle | Lista, grid de fotos 2 columnas | Precio y botones visibles | |
| 8 | Cliente: mensajes y chat | Burbujas (ancho máx. 310 dp) | Burbujas legibles en 320 dp y no diminutas en tablet | |
| 9 | Cliente: explorar yonkes | Lista, filtro de ciudad (hoja al 72 % de alto) | En teléfono horizontal la hoja sigue siendo usable | |
| 10 | Cliente: perfil, direcciones, ayuda | Formularios | Sin overflow; se puede guardar con teclado abierto | |
| 11 | Yonke: ingreso y registro | Formulario largo | Todos los campos alcanzables; error de validación visible | |
| 12 | Yonke: inicio | Tres métricas en fila, solicitudes recientes | Las métricas no se cortan en 320 dp | |
| 13 | Yonke: bandeja y detalle de solicitud | Lista, grid de fotos 3/2 columnas, botón cotizar | Botón cotizar siempre visible | |
| 14 | Yonke: cotizar | Formulario con fotos | Sin overflow; enviar alcanzable con teclado | |
| 15 | Yonke: cotizaciones y detalle | Lista, grid 2 columnas | Sin overflow | |
| 16 | Yonke: mensajes y chat | Burbujas (ancho máx. 330 dp) | Igual que 8 | |
| 17 | Yonke: perfil y cobertura | Avatar 104 dp, listas | Sin overflow | |
| 18 | Notificaciones (ambos roles) | Lista | Sin overflow; en tablet se estira pero no rompe | |
| 19 | Documento legal | Texto largo | Scroll fluido, márgenes razonables en tablet | |

## 6. Checklist por dispositivo físico

| # | Dispositivo | Paso | Resultado esperado | Resultado |
| --- | --- | --- | --- | --- |
| 1 | Teléfono Android | Rotar a horizontal en cada pantalla de la sección 5 | Se conserva lo escrito y la posición; nada se corta | |
| 2 | Teléfono Android | Abrir teclado en ingreso, registro y nueva solicitud | El campo enfocado queda visible; el botón principal se puede alcanzar | |
| 3 | Teléfono Android | Ajustes → Pantalla → Tamaño de fuente al máximo y tamaño de pantalla "Grande" | Sin texto cortado; todo alcanzable con scroll | |
| 4 | Teléfono Android | Pantalla dividida con otra app (≈ 50 % de alto) | La app sigue usable; no lanza errores | |
| 5 | Teléfono con notch o barra de gestos | Revisar bordes superior e inferior | Nada queda debajo del notch ni de la barra (SafeArea) | |
| 6 | Plegable | Abrir y cerrar a mitad de un flujo (nueva solicitud, cotizar) | El flujo continúa sin perder datos | |
| 7 | Tablet Android | Vertical y horizontal en inicio, bandeja, chat | Contenido centrado; la navegación inferior no se deforma | |
| 8 | iPad (requiere Mac) | Split View y Slide Over | La app se adapta al ancho reducido | |
| 9 | Chrome en laptop | Ventana a 1366×768 y 1920×1080 | Contenido centrado; sin scroll horizontal | |
| 10 | Chrome en laptop | Reducir la ventana a ~400 px de ancho | Se comporta como teléfono | |
| 11 | iPhone (requiere Mac) | Tamaño de texto de accesibilidad al máximo | Sin texto cortado | |

## 7. Criterios de aceptación

- Sin franjas de overflow ni excepciones de layout en ningún dispositivo.
- Objetivos táctiles de al menos 48×48 dp.
- Con escala de texto 1.3 no se pierde información esencial (se puede
  truncar decorativo, no precios, folios ni botones).
- Todo el contenido es alcanzable con scroll; nada queda detrás del teclado
  ni de la navegación inferior.
- La navegación inferior es visible y está dentro de la pantalla.
- Rotar no pierde estado ni datos escritos.
- Sin scroll horizontal accidental.
- En tablet y escritorio la pantalla puede estirarse, pero no romperse.

## 8. Hallazgos conocidos / pendientes

Problemas detectados al montar la matriz. No se corrigen en este plan; se
registran para priorizarlos. Los que hacen fallar un test automático tienen su
clave en `test/support/hallazgos_conocidos.dart`.

| ID | Pantalla(s) | Dispositivos | Descripción | Evidencia | Estado |
| --- | --- | --- | --- | --- | --- |
| RESP-01 | Todas las que usan navegación inferior | Tablet horizontal, laptop, escritorio | La barra inferior ocupa todo el ancho mientras el contenido se centra a 520-760 dp. `YonkeDrawer` existe pero no se usa. Archivos: `client_bottom_navigation.dart`, `yonke_bottom_navigation.dart` | `build/screenshots/*/escritorio-fhd.png` | Abierto |
| RESP-02 | YonkeHomePage, ClientProfilePage, ClientYonkesPage, notificaciones (ambos roles), mensajes y chat del cliente, ClientQuotesPage, LegalDocumentPage, ClientOnboardingPage | Tablet, laptop, escritorio | No tienen `maxWidth`; las listas se estiran de borde a borde | `build/screenshots/yonke-home/ipad-pro-horizontal.png` | Abierto |
| RESP-03 | Nueva solicitud, fotos, revisión, detalle de cotización (cliente y yonke), cotizar | 320 dp con texto grande; tablet | `GridView` con `crossAxisCount` fijo (`new_request_page.dart:503,847`, `request_photos_page.dart:124`, `request_review_page.dart:150`, `quote_detail_page.dart:264`, `yonke_quote_detail_page.dart:230`, `yonke_quote_page.dart:559`) | Pendiente de agregar a la matriz | Abierto |
| RESP-04 | Cliente: inicio | Todos los teléfonos; tablet y laptop con texto 1.3+ | Hero de 164 dp y tarjetas de acceso de 156 dp de altura fija (`role_home_page.dart:160,292`). La `Column` de la tarjeta (`:305`) desborda 17 px por abajo incluso con texto normal | `build/screenshots/cliente-home/iphone-14.png`; tests saltados con clave `cliente-home@…` | Confirmado |
| RESP-05 | Cliente: explorar yonkes | Teléfono horizontal | Hoja de filtros al 72 % de alto (`client_yonkes_page.dart:582`) queda muy corta con 390 dp de alto | Manual | Abierto |
| RESP-06 | Yonke: inicio | Todos los teléfonos hasta 430 dp; tablet y laptop con texto 1.3+ | Tarjetas de métricas (`yonke_home_page.dart:306,318`): la `Column` desborda de 2 a 44 px por abajo y la `Row` valor + avatar desborda hasta 25 px a la derecha | `build/screenshots/yonke-home/android-320.png`; claves `yonke-home@…` | Confirmado |
| RESP-07 | Web / iPad | — | `web/manifest.json` fija `portrait-primary`; iPad permite todas las orientaciones y Android no bloquea ninguna. Decidir política de orientación | — | Abierto |
| RESP-08 | Todas | Texto 1.5 a 2.0 | No hay tope de `textScaler` en `app_theme.dart`; el comportamiento con escalas extremas no está acotado | — | Abierto |
| RESP-09 | Tests | — | Los loops responsivos de `test/widget_test.dart` y de `client_login_test.dart` envuelven la página en `MediaQueryData()` nuevo, que deja `size` en 0×0, así que las ramas `width < 380` siempre se activan. Migrar a `pumpEnDispositivo` | — | Abierto |
| RESP-10 | Cliente: inicio | Todos los teléfonos hasta 430 dp; tablet y laptop con texto 1.3+ | Filas sin `Flexible`/`Expanded`: el banner "Nueva solicitud" (`role_home_page.dart:233`) desborda de 97 a 199 px a la derecha y el título de sección con botón "Ver todas" (`:459`) de 104 a 206 px | `build/screenshots/cliente-home/android-320.png`; claves `cliente-home@…` | Confirmado |
| RESP-11 | Yonke: registro | Todos los teléfonos hasta 430 dp; tablet y laptop con texto 1.5 | Título de sección en `Row` sin `Flexible` (`yonke_register_page.dart:812`): desborda de 2 a 33 px a la derecha | `build/screenshots/yonke-registro/iphone-14.png`; claves `yonke-registro@…` | Confirmado |
| RESP-12 | Cliente: explorar yonkes | android-320 con texto 1.3 y 1.5 | Fila de calificación (`client_yonkes_page.dart:543`) desborda 0.94 px; probablemente redondeo de la fuente de prueba, verificar en teléfono | claves `cliente-yonkes@android-320@x…` | Por verificar |
| RESP-13 | Inicio (elegir rol) | ipad-mini con texto 1.5 | La pantalla fija no cabe: 18 px por abajo. `start_page.dart` solo habilita scroll con escala > 1.3, pero en tablet vertical con 1.5 los tamaños de logo/botones siguen sin caber | clave `inicio@ipad-mini@x1.5` | Confirmado |
| RESP-14 | Cliente: ingreso | android-320 con texto 1.5 | La pantalla fija sin scroll (`client_login_page.dart`, `resizeToAvoidBottomInset: false`) desborda 42 px por abajo | clave `cliente-login@android-320@x1.5` | Confirmado |
| RESP-15 | Yonke: mensajes | Todos los representativos con texto 1.5 | Fila de la bandeja desborda 6 px por abajo (`yonke_messages_page.dart`) | claves `yonke-mensajes@…@x1.5` | Confirmado |

### Resultados de la matriz automática

Corrida inicial (Flutter 3.47.5, 30 de septiembre de 2026): 377 tests de
verificación, 326 pasan y 51 fallan por los hallazgos RESP-04, 06, 10, 11, 12,
13, 14 y 15; esos 51 quedaron saltados en `hallazgos_conocidos.dart` y la suite
está en verde. Las 325 capturas se generaron sin errores.

| Pantalla | Pasa en | Falla en |
| --- | --- | --- |
| inicio | Todo el tier de humo; representativos con 1.3 | ipad-mini con 1.5 |
| cliente-login | Todo el tier de humo; 1.3 en representativos | android-320 con 1.5 |
| cliente-home | Plegable abierto, tablets, laptop y escritorio con texto 1 | Todos los teléfonos con texto 1; los 4 representativos con 1.3 y 1.5 |
| cliente-perfil | Todo | — |
| cliente-yonkes | Todo el tier de humo | android-320 con 1.3 y 1.5 |
| yonke-login | Todo | — |
| yonke-registro | Plegable abierto, tablets, laptop y escritorio con texto 1 | Todos los teléfonos con texto 1; android-320 e iphone-14 con 1.3 y 1.5; ipad-mini y laptop-hd con 1.5 |
| yonke-home | Plegable abierto, tablets, laptop y escritorio con texto 1 | Todos los teléfonos con texto 1; los 4 representativos con 1.3 y 1.5 |
| yonke-solicitudes | Todo | — |
| yonke-solicitud-detalle | Todo | — |
| yonke-cotizaciones | Todo | — |
| yonke-mensajes | Todo el tier de humo; 1.3 en representativos | Los 4 representativos con 1.5 |
| yonke-perfil | Todo | — |

Observaciones visuales en las capturas (no fallan el test porque no lanzan
excepción): en escritorio y tablet horizontal la barra inferior ocupa todo el
ancho (RESP-01) y las listas de yonke-home, cliente-perfil y cliente-yonkes se
estiran de borde a borde (RESP-02).

## 9. Plantilla de reporte de hallazgo

```
ID: RESP-xx
Pantalla:
Dispositivo / orientación / escala de texto:
Pasos:
Resultado esperado:
Resultado observado:
Evidencia (captura en build/screenshots/... o foto):
Test que lo cubre / clave agregada en hallazgos_conocidos.dart:
```
