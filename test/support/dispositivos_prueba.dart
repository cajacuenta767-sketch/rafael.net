import 'package:flutter/widgets.dart';

/// Matriz de dispositivos para las pruebas responsive.
///
/// Los tamaños son lógicos (dp). El tamaño físico que se fija en
/// `tester.view.physicalSize` es `lógico × dpr`, igual que en un dispositivo
/// real. La tabla completa está en `docs/RESPONSIVE_TEST_PLAN.md`.
enum CategoriaDispositivo {
  telefonoPequeno('Teléfono pequeño'),
  telefonoMedio('Teléfono medio'),
  telefonoGrande('Teléfono grande'),
  plegable('Plegable'),
  tabletChica('Tablet 7-8"'),
  tabletGrande('Tablet 10-13"'),
  laptopWeb('Laptop / web'),
  escritorio('Escritorio');

  const CategoriaDispositivo(this.etiqueta);

  final String etiqueta;
}

enum Orientacion { vertical, horizontal }

class DispositivoPrueba {
  const DispositivoPrueba({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.ancho,
    required this.alto,
    this.dpr = 1,
    this.orientacion = Orientacion.vertical,
  });

  /// Identificador corto: se usa en nombres de tests, claves de hallazgos y
  /// nombres de archivo de capturas (`build/screenshots/<pagina>/<id>.png`).
  final String id;
  final String nombre;
  final CategoriaDispositivo categoria;
  final double ancho;
  final double alto;
  final double dpr;
  final Orientacion orientacion;

  Size get tamanoLogico => Size(ancho, alto);

  Size get tamanoFisico => Size(ancho * dpr, alto * dpr);

  bool get esHorizontal => orientacion == Orientacion.horizontal;

  String get descripcion =>
      '$nombre ${ancho.toInt()}×${alto.toInt()}'
      '${esHorizontal ? ' horizontal' : ''}';

  @override
  String toString() => id;
}

const todosLosDispositivos = <DispositivoPrueba>[
  // Teléfonos pequeños
  DispositivoPrueba(
    id: 'android-320',
    nombre: 'Android compacto',
    categoria: CategoriaDispositivo.telefonoPequeno,
    ancho: 320,
    alto: 640,
    dpr: 2,
  ),
  DispositivoPrueba(
    id: 'galaxy-s8',
    nombre: 'Galaxy S8 / gama baja',
    categoria: CategoriaDispositivo.telefonoPequeno,
    ancho: 360,
    alto: 640,
    dpr: 3,
  ),
  // Teléfonos medios
  DispositivoPrueba(
    id: 'iphone-se',
    nombre: 'iPhone SE',
    categoria: CategoriaDispositivo.telefonoMedio,
    ancho: 375,
    alto: 667,
    dpr: 2,
  ),
  DispositivoPrueba(
    id: 'iphone-14',
    nombre: 'iPhone 13/14',
    categoria: CategoriaDispositivo.telefonoMedio,
    ancho: 390,
    alto: 844,
    dpr: 3,
  ),
  DispositivoPrueba(
    id: 'pixel-7',
    nombre: 'Pixel 7',
    categoria: CategoriaDispositivo.telefonoMedio,
    ancho: 412,
    alto: 915,
    dpr: 2.625,
  ),
  // Teléfonos grandes
  DispositivoPrueba(
    id: 'iphone-15-pro-max',
    nombre: 'iPhone 15 Pro Max',
    categoria: CategoriaDispositivo.telefonoGrande,
    ancho: 430,
    alto: 932,
    dpr: 3,
  ),
  // Teléfonos en horizontal
  DispositivoPrueba(
    id: 'iphone-14-horizontal',
    nombre: 'iPhone 13/14',
    categoria: CategoriaDispositivo.telefonoMedio,
    ancho: 844,
    alto: 390,
    dpr: 3,
    orientacion: Orientacion.horizontal,
  ),
  DispositivoPrueba(
    id: 'iphone-15-pro-max-horizontal',
    nombre: 'iPhone 15 Pro Max',
    categoria: CategoriaDispositivo.telefonoGrande,
    ancho: 932,
    alto: 430,
    dpr: 3,
    orientacion: Orientacion.horizontal,
  ),
  // Plegables
  DispositivoPrueba(
    id: 'plegable-cerrado',
    nombre: 'Galaxy Z Fold cerrado',
    categoria: CategoriaDispositivo.plegable,
    ancho: 344,
    alto: 882,
    dpr: 2.6,
  ),
  DispositivoPrueba(
    id: 'plegable-abierto',
    nombre: 'Pixel Fold abierto',
    categoria: CategoriaDispositivo.plegable,
    ancho: 673,
    alto: 841,
    dpr: 2.6,
  ),
  // Tablets chicas
  DispositivoPrueba(
    id: 'tablet-7',
    nombre: 'Tablet Android 7"',
    categoria: CategoriaDispositivo.tabletChica,
    ancho: 600,
    alto: 960,
    dpr: 2,
  ),
  DispositivoPrueba(
    id: 'ipad-mini',
    nombre: 'iPad mini',
    categoria: CategoriaDispositivo.tabletChica,
    ancho: 768,
    alto: 1024,
    dpr: 2,
  ),
  // Tablets grandes
  DispositivoPrueba(
    id: 'tablet-10',
    nombre: 'Tablet Android 10"',
    categoria: CategoriaDispositivo.tabletGrande,
    ancho: 800,
    alto: 1280,
    dpr: 1.5,
  ),
  DispositivoPrueba(
    id: 'ipad-air',
    nombre: 'iPad Air',
    categoria: CategoriaDispositivo.tabletGrande,
    ancho: 820,
    alto: 1180,
    dpr: 2,
  ),
  DispositivoPrueba(
    id: 'ipad-pro',
    nombre: 'iPad Pro 12.9"',
    categoria: CategoriaDispositivo.tabletGrande,
    ancho: 1024,
    alto: 1366,
    dpr: 2,
  ),
  DispositivoPrueba(
    id: 'ipad-air-horizontal',
    nombre: 'iPad Air',
    categoria: CategoriaDispositivo.tabletGrande,
    ancho: 1180,
    alto: 820,
    dpr: 2,
    orientacion: Orientacion.horizontal,
  ),
  DispositivoPrueba(
    id: 'ipad-pro-horizontal',
    nombre: 'iPad Pro 12.9"',
    categoria: CategoriaDispositivo.tabletGrande,
    ancho: 1366,
    alto: 1024,
    dpr: 2,
    orientacion: Orientacion.horizontal,
  ),
  // Laptop / web
  DispositivoPrueba(
    id: 'ventana-escritorio',
    nombre: 'Ventana de escritorio por defecto',
    categoria: CategoriaDispositivo.laptopWeb,
    ancho: 1280,
    alto: 720,
    orientacion: Orientacion.horizontal,
  ),
  DispositivoPrueba(
    id: 'laptop-hd',
    nombre: 'Laptop HD / Chrome',
    categoria: CategoriaDispositivo.laptopWeb,
    ancho: 1366,
    alto: 768,
    orientacion: Orientacion.horizontal,
  ),
  DispositivoPrueba(
    id: 'macbook-air',
    nombre: 'MacBook Air',
    categoria: CategoriaDispositivo.laptopWeb,
    ancho: 1440,
    alto: 900,
    dpr: 2,
    orientacion: Orientacion.horizontal,
  ),
  // Escritorio
  DispositivoPrueba(
    id: 'escritorio-fhd',
    nombre: 'Monitor Full HD',
    categoria: CategoriaDispositivo.escritorio,
    ancho: 1920,
    alto: 1080,
    orientacion: Orientacion.horizontal,
  ),
];

/// Subconjunto para pruebas costosas (escala de texto, capturas extra):
/// un teléfono pequeño, uno medio, una tablet y una laptop.
final dispositivosRepresentativos = <DispositivoPrueba>[
  dispositivoPorId('android-320'),
  dispositivoPorId('iphone-14'),
  dispositivoPorId('ipad-mini'),
  dispositivoPorId('laptop-hd'),
];

/// Escala de texto del tier de humo.
const escalasTextoHumo = <double>[1];

/// Escalas de accesibilidad: "Grande" y "Muy grande" del sistema.
const escalasTextoAccesibilidad = <double>[1.3, 1.5];

/// Escala extrema documentada pero no ejecutada por defecto.
const escalasTextoExtremas = <double>[2];

DispositivoPrueba dispositivoPorId(String id) =>
    todosLosDispositivos.firstWhere((d) => d.id == id);
