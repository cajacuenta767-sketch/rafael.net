# Plan de adaptación responsive de REFANET

Actualización del 3 de octubre de 2026: la propuesta ampliada que integra revisión visual completa, contratos del API, JWT y Stripe está en [PLAN_ADAPTACION_API_STRIPE.md](PLAN_ADAPTACION_API_STRIPE.md). Su alcance nuevo está pendiente de revisión; las casillas aprobadas de este documento corresponden al trabajo responsive anterior.

Estado: ejecución autorizada; adaptación visual anterior rechazada por el usuario. Fecha: 2 de octubre de 2026. Revisión 6: corrección de tamaños y de evidencia. No equivale a certificación de todos los dispositivos.

## 1. Objetivo y límites

Adaptar las pantallas del cliente y del Yonke para que sean legibles, bonitas y utilizables en celulares, tablets, plegables, laptops, monitores y pantallas de TV. Conservar la identidad visual, el azul del Yonke, el verde del cliente, los apartados y sus funciones actuales.

El usuario aprobó la ejecución local de este documento. No incluye publicar cambios en GitHub, desplegar Azure, alterar contratos del API ni crear pedidos reales.

No es posible enumerar ni certificar cada modelo comercial. La cobertura se organizará por espacio disponible, orientación, escala de texto y modo de interacción. Los siguientes tamaños son ventanas de prueba representativas, no especificaciones exactas de modelos comerciales.

## 2. Inventario de dispositivos y orden de revisión

Todas las medidas son ancho × alto en píxeles lógicos de Flutter. No equivalen necesariamente a los píxeles físicos del panel. Se comprobarán también densidades 1×, 2× y 3× en una selección representativa.

### Corrección obligatoria de la interpretación de tamaños

La matriz anterior incluyó ventanas lógicas extremas; no deben presentarse como simulaciones fieles de celulares o tablets por coincidir con resoluciones comerciales físicas. Los resultados anteriores sin metadatos son evidencia de estrés, no aprobación visual.

La galería principal usa ahora perfiles explícitos de ventana lógica y DPR; por ejemplo:

| Perfil ilustrativo | Ventana lógica | DPR | Superficie física simulada |
| --- | --- | --- | --- |
| Celular compacto | 360 × 640 | 3 | 1080 × 1920 |
| Celular grande | 430 × 932 | 3 | 1290 × 2796 |
| Tablet | 800 × 1280 | 2 | 1600 × 2560 |
| Tablet de alta resolución | 960 × 1706 | 3 | 2880 × 5118 |
| Escritorio | 1600 × 900 | 1 | 1600 × 900 |
| Monitor 4K con escala ilustrativa 200 % | 1920 × 1080 | 2 | 3840 × 2160 |

Celulares y tablets tienen también orientación horizontal. Estos son perfiles representativos, no medidas certificadas de modelos concretos. La ventana lógica efectiva depende del sistema, navegador, escala y áreas ocupadas por sus barras.

Cada captura nueva registra ventana lógica, DPR, superficie física y resolución de salida PNG. La salida puede limitarse a 2560 píxeles de ancho para controlar recursos; el visor al 100 % lógico reconstruye el ancho lógico, no confunde píxeles de imagen con tamaño de interfaz. Las miniaturas no sirven para aprobar legibilidad. La galería deja ocultas por defecto las pruebas antiguas/extremas y permite abrir una captura al 100 % o ajustarla a la ventana.

Los controles no se harán más pequeños para evitar desplazamiento. En ventanas cortas se reduce decoración y se permite scroll. Los formularios conservan un ancho legible; listados, resúmenes y revisión aprovechan columnas cuando hay espacio. No se amplía globalmente la aplicación en proporción a la resolución.

### 2.1. Celulares

| Grupo | Ventanas verticales de prueba |
| --- | --- |
| Muy pequeños o antiguos | 320 × 480; 320 × 568 |
| Compactos | 360 × 640; 375 × 667 |
| Compactos y altos | 360 × 720; 360 × 740; 360 × 760; 360 × 780; 360 × 800 |
| Medianos | 375 × 812; 384 × 800; 390 × 844; 393 × 852 |
| Medianos y altos | 393 × 873; 400 × 900; 412 × 846; 412 × 892 |
| Grandes | 412 × 915; 414 × 736; 414 × 896; 428 × 926 |
| Extra grandes | 430 × 932; 440 × 956; 480 × 960 |

Cada ventana se probará también en horizontal, intercambiando ancho y alto. Se propone soporte base desde 320 de ancho; los tamaños inferiores se registran como pruebas de estrés, sin prometer la misma distribución. Los perfiles no representan modelos comerciales concretos.

### 2.2. Plegables y dispositivos de doble pantalla

| Situación | Ventanas / comprobaciones |
| --- | --- |
| Pantalla exterior estrecha | 280 × 653; 320 × 820; 344 × 882 |
| Pantalla exterior ancha | 360 × 800; 400 × 900 |
| Abierto, casi cuadrado | 600 × 720; 673 × 841; 720 × 840 |
| Abierto grande | 768 × 900; 840 × 960 |
| Dos pantallas | Probar cada panel y el conjunto con separación central; registrar tamaño y posición de la separación |
| Parcialmente plegado | Probar espacio disponible a ambos lados de la bisagra y posturas tipo libro / mesa |

Repetir orientación vertical y horizontal. No ubicar controles esenciales sobre zonas de bisagra u oclusión reportadas por el dispositivo. Comprobar que abrir/cerrar el dispositivo no pierda datos, selección, conversación ni posición útil de navegación. Una simulación sin bisagra no certifica este comportamiento en hardware.

### 2.3. Tablets

| Grupo | Ventanas verticales de prueba |
| --- | --- |
| Mini | 600 × 800; 600 × 960 |
| Pequeñas | 640 × 960; 720 × 1080 |
| Medianas | 768 × 1024; 800 × 1280 |
| Grandes | 820 × 1180; 834 × 1112; 834 × 1194 |
| Extra grandes | 900 × 1200; 960 × 1280; 1024 × 1366 |
| Tablets grandes / convertibles | 1080 × 1440; 1200 × 1600 |

Probar todas en horizontal y vertical. Añadir pantalla dividida al 25 %, 33 %, 50 %, 67 % y 75 % del espacio disponible, descontando la separación del sistema. Incluir ventanas flotantes, perfiles estrechos de 360 × 1024 y 512 × 1024, teclado físico y cambios de orientación con formularios empezados. Registrar el tamaño efectivo de la ventana, no solo el del dispositivo.

### 2.4. Laptops, convertibles y Chromebooks

| Grupo | Ventanas de prueba |
| --- | --- |
| Muy compactas | 1024 × 600; 1024 × 768 |
| Compactas | 1280 × 720; 1280 × 800; 1366 × 768 |
| Medianas | 1440 × 900; 1536 × 864; 1536 × 960 |
| Grandes | 1600 × 900; 1600 × 1000; 1920 × 1080; 1920 × 1200 |

No probar solamente maximizado: incluir media pantalla, ventanas pequeñas, restaurar/maximizar y redimensionamiento continuo. En convertibles, probar transición entre ratón/teclado y uso táctil.

En convertibles, probar obligatoriamente vertical y horizontal; añadir las ventanas invertidas de la tabla cuando el sistema permita esa orientación. En laptops convencionales, probar ventanas estrechas y altas sin asumir que la pantalla física gira.

### 2.5. Monitores

| Grupo | Ventanas de prueba |
| --- | --- |
| Convencionales | 1280 × 1024; 1600 × 900; 1920 × 1080 |
| Altos / 16:10 | 1920 × 1200; 2560 × 1600 |
| QHD | 2560 × 1440 |
| Ultrapanorámicos | 2560 × 1080; 3440 × 1440 |
| Superultrapanorámicos | 3840 × 1080; 5120 × 1440 |
| Grandes / alta resolución | 3840 × 2160; 5120 × 2880 |
| Monitor vertical | 1080 × 1920; 1440 × 2560 |

Son perfiles de ventana lógica para probar el layout. En hardware real se anotarán por separado resolución física, escala del sistema y ventana lógica obtenida. Los formularios y conversaciones tendrán un ancho cómodo; no se estirarán hasta los extremos.

### 2.6. TVs, proyectores y pantallas de negocio

- Perfiles HD, Full HD y 4K: paneles físicos de 1280 × 720, 1920 × 1080 y 3840 × 2160. Registrar la ventana lógica real de cada plataforma; no asumir que coincide con el panel.
- Simular además ventanas lógicas de esos tamaños para revisar distribución, distinguiéndolas de pruebas en TV real.
- Revisar lectura a distancia, márgenes seguros, foco visible, control remoto, flechas, botón Atrás y teclado en pantalla.
- No depender exclusivamente del ratón, hover o gestos táctiles.

### 2.7. Otros formatos y límites

- Kioscos, pantallas táctiles de mostrador y terminales industriales: incluir perfiles 480 × 800, 800 × 480, 1024 × 768 y 1080 × 1920, con sus entradas reales si están disponibles.
- Relojes y pantallas de automóvil: inventariados, pero fuera del alcance inicial. Requieren una experiencia y verificación de plataforma propias; no basta con encoger la app actual.
- Ventanas libres: comprobar continuidad entre los tamaños enumerados, no únicamente puntos aislados.
- En cada punto de cambio de distribución, probar un píxel antes, el valor exacto y un píxel después. Para los cortes iniciales: 599/600/601, 839/840/841, 1199/1200/1201 y 1599/1600/1601. Agregar cualquier corte específico que aparezca al implementar.
- Probar también el límite mínimo 319/320/321 y ventanas de poca altura: 240, 320, 360, 480 y 600. Los tamaños extremos son pruebas de estrés; documentar el comportamiento y los límites, sin ocultar fallos.

Orden de trabajo: celulares de menor a mayor espacio → horizontales → plegables → tablets y multiventana → laptops → monitores → TV/proyectores → kioscos y pruebas de límites. Los perfiles repetidos pueden reutilizar evidencia de layout cuando todas sus condiciones coincidan; no reutilizarla como prueba de plataforma o interacción distinta.

### 2.8. Reglas explícitas de orientación

- Celulares, tablets, plegables, convertibles y kioscos: probar vertical y horizontal. En kioscos, incorporar la versión invertida de cada ventana enumerada.
- En dispositivos que lo permitan, probar horizontal con giro hacia la izquierda y hacia la derecha. Registrar las zonas seguras reales de cada lado; invertir ancho y alto por sí solo no reproduce la posición de la cámara o los recortes.
- La orientación vertical invertida se comprobará cuando la plataforma la admita; no se exigirá forzar una orientación no disponible.
- TVs y proyectores: horizontal como perfil base; vertical cuando la instalación o el uso como señalización lo permita. No asumir soporte físico de rotación.
- Monitores: ventanas anchas y altas, además de los perfiles verticales definidos.
- Una orientación aprobada no aprueba automáticamente la otra. Cada una tendrá casos y evidencias propios.

TV: validar el diseño en una ventana grande no demuestra compatibilidad con Android TV, Apple TV o sus controles remotos. La instalación y los plugins de esas plataformas requieren comprobación separada. No se prometerá soporte nativo donde no se haya ejecutado la app.

## 3. Apartados que se revisarán

### Acceso y bienvenida

- Bienvenida y selección de rol.
- Acceso del cliente, consentimiento legal y OTP cuando sean accesibles.
- Acceso, registro y recuperación de contraseña del Yonke.
- Errores de validación, teclado abierto y mensajes de carga.

### Cliente

- Inicio, navegación y acciones del botón central.
- Nueva solicitud: vehículo/pieza, detalles, fotos, ciudad y revisión.
- Mis solicitudes, filtros y detalle de solicitud.
- Cotizaciones, detalle, aceptación, orden creada y seguimiento.
- Lista de mensajes, conversación, adjuntos y composición con teclado abierto.
- Explorar yonkes y detalle del negocio disponible en la app.
- Notificaciones.
- Perfil, edición, direcciones, métodos de pago, ayuda y calificación.

### Yonke

- Inicio y navegación.
- Solicitudes, filtros y detalle.
- Crear cotización, listado, detalle y edición disponible.
- Lista de mensajes, conversación y adjuntos.
- Perfil, edición del negocio y logotipo.
- Horario, contacto, configuración, cobertura, ayuda y notificaciones, según las vistas o diálogos que realmente existen.

La base son las 39 pantallas capturadas en la galería. Se ampliará el inventario con subpantallas, menús, diálogos y estados que la galería inicial no cubre. No se considerará que capturar una página padre valida sus formularios secundarios.

## 4. Adaptación propuesta

| Ancho disponible | Tratamiento propuesto |
| --- | --- |
| 320–599 | Una columna, navegación inferior, formularios desplazables y acciones alcanzables. Las tarjetas se reorganizan cuando no caben, sin achicar el texto hasta hacerlo ilegible. |
| 600–839 | Más espacio y tarjetas en dos columnas cuando el contenido lo permita; formularios con ancho controlado. Mantener navegación clara y táctil. |
| 840–1199 | Distribución de tablet; lista y detalle o conversación en dos paneles donde tenga sentido. Probar cada transformación antes de aplicarla globalmente. |
| 1200–1599 | Diseño de escritorio con contenido centrado, columnas útiles y navegación visible. Formularios de aproximadamente 560–720 de ancho máximo, ajustable según su contenido. |
| Desde 1600 | Mantener un ancho de contenido limitado, sin tarjetas gigantes ni espacios vacíos innecesarios. En TV, añadir escala de lectura y foco adecuados al contexto. |

Estos cortes son una propuesta inicial, no reglas rígidas para todas las pantallas. Se decidirá con `LayoutBuilder` y las restricciones reales, no con el nombre del dispositivo. No se añadirá un menú hamburguesa derecho. Inicio seguirá siendo el primer apartado; el botón central conservará su función acordada y no sustituirá Inicio.

### 4.1. Distribución esperada por apartado

| Apartado | Ventana compacta / poca altura | Ventana amplia con altura suficiente |
| --- | --- | --- |
| Bienvenida y acceso | Una columna desplazable; logo proporcionado y campos/acciones alcanzables con teclado | Formulario centrado y ancho limitado; contenido de marca separado solo si aporta claridad |
| Inicio del cliente | Hero proporcionado; resumen en dos tarjetas si caben, en una columna si no; solicitudes debajo | Resumen y solicitudes en columnas útiles, sin agrandar el auto ni las tarjetas para llenar el ancho |
| Inicio del Yonke | Indicadores que se reorganicen sin truncar etiquetas; solicitudes y banner debajo | Indicadores en fila y zona de solicitudes con ancho controlado; banner proporcional |
| Nueva solicitud y registro | Una columna; indicador de pasos compacto que conserve paso actual y progreso; acciones accesibles | Dos columnas para campos relacionados cuando haya espacio; fotos y revisión con ancho limitado |
| Listas de solicitudes, cotizaciones y yonkes | Una columna, filtros que envuelvan o usen un selector accesible | Lista y detalle en dos paneles cuando la navegación lo permita; alternativamente tarjetas en cuadrícula si no perjudica la lectura |
| Detalle de solicitud / cotización / orden | Secciones apiladas; fotos y acciones desplazables sin superposición | Información y panel de acciones en columnas; galería proporcionada; lectura en orden coherente |
| Mensajes y conversación | Lista y chat en pantallas separadas; compositor accesible con teclado abierto | Lista y conversación en dos paneles; ancho de burbujas limitado y compositor dentro del panel de chat |
| Perfil, direcciones y edición del negocio | Opciones y formularios en una columna; textos largos con ajuste | Opciones y contenido en dos zonas si hay espacio; formularios con ancho máximo y campos relacionados agrupados |
| Notificaciones y ayuda | Lista o contenido en una columna legible | Mantener ancho de lectura limitado; no crear columnas innecesarias para ocupar espacio |
| Diálogos, selectores y foto ampliada | Tamaño limitado a la zona útil; desplazamiento y cierre accesibles | Diálogo centrado con ancho máximo; imagen conserva proporción y controles visibles |

Estas distribuciones son objetivos iniciales. Antes de implementar cada apartado se guardará una referencia visual por rango y se documentarán ajustes justificados por el contenido. Mantener el orden de lectura, las rutas y las funciones actuales; no introducir nuevas funciones para resolver un problema de layout.

### 4.2. Reglas según altura disponible

- Medir la altura útil después de descontar zonas seguras, barras e insets del teclado; no decidir el layout únicamente por ancho u orientación.
- Por debajo de 480 de altura útil: priorizar campos, contenido y acciones; reducir espacio decorativo y permitir desplazamiento. No mantener heroes, banners ni encabezados con alturas que impidan usar la pantalla.
- Entre 480 y 719: distribución compacta con espacios moderados; evitar acciones fijas que tapen contenido.
- Desde 720: permitir el espaciado normal, siempre según contenido y escala de texto.
- Estos umbrales son iniciales y se probarán a −1, exacto y +1. Ajustarlos por apartado si las capturas muestran un problema.
- Con teclado abierto: mantener visible el campo enfocado y alcanzable la acción asociada; los pasos, encabezados y decoración no deben consumir el espacio necesario para escribir.

### 4.3. Referencia visual para aprobar

- Márgenes iniciales: 12–16 en ventanas muy estrechas, 16–24 en celulares, 24–32 en tablets y 32–48 en escritorio, en píxeles lógicos. Ajustar con evidencia, sin sacrificar contenido.
- Espaciado consistente entre componentes, partiendo de una escala de 4, 8, 12, 16, 24 y 32.
- Formularios: ancho máximo inicial de 560–720. Texto de ayuda y listas simples: ancho limitado según lectura. Zona principal amplia: máximo inicial de 1200–1440 salvo composiciones de dos paneles justificadas.
- Controles táctiles con área objetivo mínima de 48 × 48; en TV, tamaño y foco adecuados al contexto de distancia e interacción, verificados por separado.
- Mantener proporciones de fotos, logos y hero; evitar recortes que oculten información esencial. Documentar el encuadre esperado por rango.
- Definir para cada apartado una captura de referencia compacta, intermedia y amplia, con sus márgenes, columnas, tipografía y acciones. Comparar las nuevas capturas con esa referencia y registrar las diferencias intencionales.
- Aprobar tanto utilidad como composición: sin estiramientos excesivos, desequilibrios evidentes, espacios vacíos injustificados ni controles desproporcionados. La ausencia de overflow no equivale a aprobación estética.

### 4.4. Navegación, paneles y elementos temporales

- Inicio permanece primero. En compacto, mantener navegación inferior y botón central: acciones rápidas del cliente y centro de cotizaciones del Yonke. En amplio, mostrar las mismas acciones y etiquetas en una franja de ancho limitado; no añadir hamburguesa derecha ni esconder funciones por tamaño.
- Antes de activar lista/detalle en dos paneles, definir selección, ruta y Atrás. Al volver a un panel, conservar el elemento seleccionado y evitar pantallas duplicadas; Atrás debe volver a la lista sin perder su contexto.
- Cada panel largo tiene su propio desplazamiento; evitar scrolls anidados en el mismo eje sin necesidad. Lista, detalle y chat deben permitir alcanzar su contenido y acciones inferiores.
- Incluir avisos, validaciones, menús desplegables, sugerencias, snackbars y paneles inferiores en la matriz. Limitar su ancho y altura útil, permitir desplazamiento y evitar que tapen campos o acciones esenciales.
- Probar fotografías verticales, horizontales, cuadradas y panorámicas; logos grandes y pequeños. Mantener proporción y revisar encuadre, estado de carga y error.
- Probar cambios mientras llega contenido: una foto cargada, mensaje recibido o error nuevo no debe provocar pérdida de foco ni saltos inesperados de lectura. En chat, no forzar al último mensaje si el usuario está leyendo historial; diferenciar ese caso del usuario situado al final.
- Navegador: probar zoom 100 %, 125 %, 150 % y 200 % por separado de texto y escala del sistema; registrar el viewport efectivo.
- Capturas reproducibles: fixtures compartidos entre roles, reloj controlado cuando afecte al contenido, fuentes/iconos/assets reales y espera de carga de recursos. No comparar estados distintos como si fueran cambios del layout.
- Un fallo visual bloquea el avance del perfil. La falta de hardware deja el caso no verificado, no aprobado ni fallido por diseño; continuar solo con comprobaciones disponibles y conservar la limitación explícita.

Medidas comunes:

- `SafeArea` y respeto al espacio del teclado, barras del sistema y recortes de pantalla.
- Sustituir alturas rígidas problemáticas por restricciones flexibles y desplazamiento útil.
- Imágenes con proporciones estables, carga/error y sin deformación.
- Tipografía legible; probar escala de texto 1.0, 1.3, 1.5 y 2.0, sin desactivar la preferencia del usuario para ocultar problemas. En dispositivos disponibles, comprobar también el escalado de texto real del sistema.
- Áreas táctiles objetivo de al menos 48 × 48 píxeles lógicos.
- Navegación con teclado, orden de foco, foco visible y estados de botones.
- Mantener las conexiones actuales del API; cambiar el layout no debe romper solicitudes, cotizaciones, aceptación o mensajes.

## 5. Procedimiento obligatorio por dispositivo

1. Seleccionar un perfil de la matriz y registrar tamaño lógico, orientación, densidad, escala de texto, modo de entrada y entorno. Empezar por los celulares más pequeños del alcance base; documentar por separado las pruebas de estrés.
2. Ejecutar todas las pantallas y estados aplicables de ambos roles en esa ventana.
3. Capturar la parte inicial, intermedia y final cuando haya desplazamiento, con solapamiento suficiente para no dejar zonas sin revisar. En contenido largo, generar tantas capturas intermedias como haga falta; no asumir que dos capturas cubren toda la página. Capturar también diálogos, errores y teclado abierto en los flujos correspondientes.
4. Abrir y revisar visualmente las capturas; no basta con que el test pase.
5. Probar navegación, campos, botones, desplazamiento y foco. Una captura bonita no demuestra que la acción funcione.
6. Si aparece un fallo: registrar pantalla, tamaño y causa; detener el avance al siguiente dispositivo; corregir y repetir la captura y la prueba del caso fallido.
7. Cuando pase: repetir todas las pantallas afectadas por la corrección y los tamaños previamente aprobados que comparten ese componente.
8. Probar giro, redimensionamiento o plegado cuando corresponda: el estado del formulario, selección y conversación debe conservarse. Repetir con teclado, selector, diálogo y fotografía ampliada abiertos, además de formulario parcialmente llenado. Revisar la captura resultante de la transición, no solo la pantalla recién abierta. Si un elemento debe cerrarse por comportamiento de plataforma, documentarlo y verificar que no se pierdan datos ni quede bloqueada la navegación.
9. Marcar el perfil como aprobado solamente cuando no queden fallos conocidos dentro del alcance y estén enlazadas las evidencias visuales y funcionales. Entonces continuar con el siguiente.

Si una plataforma o servicio no puede probarse por falta de dispositivo, credenciales o soporte, dejarlo como **no verificado**, explicar la limitación y continuar con comprobaciones disponibles. Nunca marcarlo como aprobado ni afirmar que funciona solo por una simulación.

## 6. Casos y criterios de aprobación

### 6.1. Matriz de condiciones adicionales

| Aspecto | Condiciones obligatorias |
| --- | --- |
| Altura disponible | Ventana baja, teclado abierto, barras del navegador y barras del sistema; medir el espacio realmente utilizable |
| Proporción | Pantallas cuadradas, estrechas, muy altas, panorámicas y superultrapanorámicas |
| Escalado | Texto 100 %, 130 %, 150 % y 200 %; escala de escritorio 100 %, 125 %, 150 % y 200 % en entornos disponibles; densidades 1×, 2× y 3× en una selección |
| Zonas seguras | Sin recortes, notch/cámara, barras del sistema, navegación por gestos y zona de bisagra cuando corresponda |
| Interacción | Táctil, ratón, rueda, teclado/Tab/Enter/Escape y control remoto/flechas/Atrás según plataforma |
| Transiciones | Girar, plegar, abrir/cerrar teclado y redimensionar durante el uso sin perder datos ni selección |
| Contenido | Nombres y direcciones largos, precios grandes, múltiples fotos, mensajes extensos y listas largas |
| Estados | Carga, vacío, error, validación, conexión interrumpida y reintento |
| Plataforma | Distinguir pruebas de widget, app ejecutada, navegador, emulador y hardware real; registrar sistema y versión disponibles |

El teclado virtual y los recortes pueden simularse para pruebas de layout, pero eso no certifica su comportamiento real en cada sistema. El zoom de navegador y el escalado del sistema tampoco se confundirán con aumentar únicamente el tamaño de la fuente.

### 6.2. Criterios de aceptación

- Sin `RenderFlex overflow`, franjas amarillas, contenido superpuesto ni controles fuera de pantalla.
- Sin desplazamiento horizontal involuntario; el vertical permite alcanzar todas las acciones.
- Títulos, nombres largos, precios y textos ampliados legibles. Los datos esenciales no se ocultan para hacer que el layout encaje.
- Los campos enfocados y el botón de envío siguen accesibles cuando aparece el teclado.
- Menús, diálogos y selectores caben en ventanas bajas y admiten desplazamiento si hace falta.
- Fotografías, logos y estados de imagen vacía/error se ven correctamente.
- No hay pantallas de carga permanentes, errores de renderizado ni nuevas regresiones del flujo.
- Cliente y Yonke usan el mismo escenario de prueba: solicitud → cotización → aceptación → conversación. Verificar actualización y lectura donde corresponda.
- Repetir con listas vacías, una entrada, muchas entradas, datos largos, carga, error y reintento, sin multiplicar innecesariamente todas las combinaciones en cada ventana.
- El inventario completo se captura y revisa en cada ventana base y sus orientaciones definidas. Los flujos críticos se prueban funcionalmente en cada perfil. Las condiciones adicionales de densidad, texto, recortes e interacción se combinan de forma controlada por familia, incluyendo el caso de pantalla pequeña con texto máximo. No se presentará ese muestreo como prueba exhaustiva de todas las combinaciones.
- Para cada combinación planeada existirá una fila de seguimiento. Las pendientes no se tratarán como aprobadas y cualquier fallo bloqueará el avance del perfil hasta su corrección.

### 6.3. Matriz ejecutable de validación

Antes de modificar el layout, convertir el catálogo de tamaños y condiciones en casos identificados, no únicamente una lista descriptiva. Cada caso deberá incluir perfil, orientación, rol, pantalla, estado, resultado esperado y evidencia requerida.

Formato propuesto de identificador: `familia-anchoXalto-orientacion-rol-pantalla-estado`. Añadir lado de giro, escala e interacción cuando diferencien el caso. Las condiciones idénticas pueden compartir capturas, pero deben conservar trazabilidad.

| Caso / perfil | Pantalla y condición | Pendiente | Capturado | Revisado visual | Probado funcional | Regresión comprobada | Resultado / evidencia |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CEL-320x480-V | Inicio cliente, texto normal | [ ] | [ ] | [ ] | [ ] | [ ] | Por ejecutar |
| CEL-480x320-H-IZQ | Inicio cliente, zonas seguras izquierdas | [ ] | [ ] | [ ] | [ ] | [ ] | Por ejecutar |
| CEL-480x320-H-DER | Inicio cliente, zonas seguras derechas | [ ] | [ ] | [ ] | [ ] | [ ] | Por ejecutar |
| TAB-768x1024-V | Nueva solicitud parcialmente llenada | [ ] | [ ] | [ ] | [ ] | [ ] | Por ejecutar |
| TAB-1024x768-H | Giro del formulario con teclado abierto | [ ] | [ ] | [ ] | [ ] | [ ] | Por ejecutar |

Las filas anteriores ilustran el formato, no sustituyen la matriz completa ni significan que esos casos ya se hayan probado. Generar todas las filas base de ambas orientaciones y las variantes adicionales planificadas. Registrar por separado aprobado visual, aprobado funcional, fallo, pendiente y no verificado; no marcar un perfil como completo mientras falten casos de su alcance.

Los datos sintéticos son exclusivos de pruebas; no se insertarán imágenes, pedidos ni respuestas ficticias en la app de producción. Las pruebas contra Azure se separan de las visuales y no crearán ni borrarán registros reales sin autorización específica.

## 7. Fases después de aprobar

- [ ] Inventariar rutas, subpantallas y componentes; guardar capturas base antes de cambiar el diseño.
- [x] Parametrizar el capturador existente, usar fuentes/iconos/assets reales y controlar la carga de imágenes.
- [ ] Convertir el inventario ampliado en perfiles reproducibles y una matriz de tamaño + condiciones + pantalla + resultado; incluir límites de distribución y transiciones.
- [ ] Definir referencias visuales por apartado/rango, reglas de altura útil y evidencias de giro en ambas direcciones antes de aprobar el layout.
- [ ] Añadir datos de prueba coherentes y estados largos, vacíos y de error sin modificar producción.
- [x] Adaptar componentes comunes: márgenes, tipografía, tarjetas, navegación y formularios.
- [ ] Ejecutar el ciclo de captura/corrección en celulares, de menor a mayor tamaño.
- [ ] Continuar con horizontal, plegables y tablets.
- [ ] Continuar con laptops, monitores y ventanas libres.
- [ ] Revisar TV: layout, lectura y foco; distinguir claramente pruebas simuladas y hardware real.
- [x] Ejecutar `flutter analyze`, tests de widgets y pruebas de regresión funcional pertinentes.
- [x] Entregar galería local, informe de resultados y limitaciones verificables; no equivale a cerrar las revisiones pendientes.

## 8. Evidencias y entregables

- Capturas antes/después agrupadas por rol, apartado, tamaño, orientación, lado de giro y estado; incluir secuencias superior/intermedias/inferior sin zonas omitidas.
- Galería con filtros por dispositivo y apartado; acceso a cada PNG ampliado.
- Tests responsive reproducibles que alerten de desbordamientos.
- Registro de revisión con columnas: identificador de perfil, familia, tamaño físico si se conoce, tamaño lógico, orientación, densidad, escala de texto/sistema, zona segura/teclado, entrada, plataforma/entorno, rol, pantalla/estado, evidencia antes, fallo, corrección, evidencia después, regresión y resultado.
- Resultados diferenciados: **aprobado visual**, **aprobado funcional**, **falló** y **no verificado**. Las pruebas de widget no equivalen a una ejecución real en todos los sistemas operativos.
- Resumen de cambios, verificaciones realizadas y plataformas pendientes. No se garantizará compatibilidad universal con hardware que no se haya probado.

Referencias para los criterios técnicos:

- [Flutter: buenas prácticas de diseño adaptativo](https://docs.flutter.dev/ui/adaptive-responsive/best-practices): adaptar al espacio de la ventana y evitar estiramiento innecesario en pantallas grandes.
- [Flutter: SafeArea y MediaQuery](https://docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery): tamaño disponible, recortes y preferencias de accesibilidad.
- [Android: clases de tamaño de ventana](https://developer.android.com/develop/adaptive-apps/guides/use-window-size-classes): distinguir ventana disponible del formato físico del dispositivo.

## 9. Aprobación

La aprobación autoriza implementar la adaptación responsive y ejecutar este ciclo de pruebas en el código local. No autoriza publicar, desplegar, comprar emuladores/servicios ni modificar datos de Azure.

- [x] Plan aprobado por el usuario para ejecución local.
- [x] Implementación iniciada después de la aprobación.

## 10. Seguimiento de la ejecución

El informe verificable está en [RESPONSIVE_RESULTADOS.md](RESPONSIVE_RESULTADOS.md). La galería y el CSV se generan en `build/responsive`; el generador reproducible es `test/responsive_gallery_index_test.dart`.

La matriz automática cubre 136 ventanas base y 46 ventanas de límites/multiventana, con 39 pantallas por ventana. Una captura o un test sin overflow no se registra como aprobación visual individual. Las fases que incluyen revisar cada captura, hardware y todas las condiciones siguen abiertas hasta tener sus evidencias.

Las rutas de lista, detalle y conversación se mantienen separadas con ancho limitado. El inicio del cliente sí se distribuye en columnas amplias; no se ha activado un modo de dos paneles de lista/chat. Ese objetivo permanece pendiente: no se considera cumplido por centrar la pantalla.

No se introdujeron datos sintéticos en producción ni cambios de contratos del API. Las formas y fotografías sintéticas viven exclusivamente en el capturador de pruebas.
