# Imagen de inicio: auto con refacciones

Fecha: 4 de octubre de 2026. Herramienta: generación de imágenes integrada, modo edición.

Original conservado: `assets/images/home_hero_car_v2.png`. Nueva imagen: `assets/images/home_hero_car_parts_v3.png`. Consumidor: `lib/features/home/presentation/role_home_page.dart`; registrada en pubspec.yaml. No se modificaron datos ni conexiones API.

Prompt utilizado:

> Use case: precise-object-edit. Edit target: supplied existing REFANET app home hero. Keep the existing white sedan exactly recognizable, same model, angle, proportions, color, position, wheels and foreground silhouette; preserve the white background and lime-green circular backdrop. Add a tasteful small arrangement of realistic used auto spare parts BEHIND the sedan, on the upper lime circle: an alternator, brake disc, compact suspension shock absorber and headlight. Parts should be visible rising behind the roof, metallic neutral gray, clean photoreal product photography, harmonious lighting and modest scale. Never cover the car, no objects in front, no extra vehicle, no logos or text, no watermark. Retain wide landscape composition and clean white edges so it fits the existing compact mobile hero. Only add the background spare parts, keep all other elements unchanged.

Verificación: captura de RoleHomePage.client a 430×932 y 1366×768; ambas pruebas aprobadas. Capturas de widgets con datos simulados, no dispositivo físico. Imagen móvil revisada visualmente: refacciones detrás del techo, texto y acciones libres.

Captura móvil: `build/home_parts_preview/02_cliente_inicio.png`. Escritorio: `build/home_parts_desktop/02_cliente_inicio.png`.
