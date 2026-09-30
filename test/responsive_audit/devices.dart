// Dispositivos de la auditoría responsive.
//
// Los tamaños son los lógicos (dp / puntos CSS) con los que cada equipo
// entrega la pantalla a Flutter; son los que deciden el acomodo. La densidad
// (devicePixelRatio) solo cambia la nitidez.

enum DeviceCategory { celular, plegable, tablet, laptop, escritorio, tv }

class AuditDevice {
  const AuditDevice({
    required this.id,
    required this.name,
    required this.category,
    required this.width,
    required this.height,
    required this.pixelRatio,
    this.textScale = 1.0,
    this.keyboardHeight = 0,
    this.note,
  });

  final String id;
  final String name;
  final DeviceCategory category;
  final double width;
  final double height;
  final double pixelRatio;
  final double textScale;

  /// Alto del teclado en pantalla (dp). 0 = cerrado.
  final double keyboardHeight;
  final String? note;
}

const auditDevices = <AuditDevice>[
  // Celulares
  AuditDevice(
    id: 'cel-320',
    name: 'Celular muy angosto (iPhone SE 1ª gen, Android básico)',
    category: DeviceCategory.celular,
    width: 320,
    height: 568,
    pixelRatio: 2,
  ),
  AuditDevice(
    id: 'fold-cerrado',
    name: 'Galaxy Z Fold cerrado',
    category: DeviceCategory.plegable,
    width: 344,
    height: 882,
    pixelRatio: 2.625,
  ),
  AuditDevice(
    id: 'cel-360',
    name: 'Android popular (Galaxy A15, Moto G, Redmi)',
    category: DeviceCategory.celular,
    width: 360,
    height: 780,
    pixelRatio: 3,
  ),
  AuditDevice(
    id: 'iphone-se',
    name: 'iPhone SE (2ª y 3ª gen)',
    category: DeviceCategory.celular,
    width: 375,
    height: 667,
    pixelRatio: 2,
  ),
  AuditDevice(
    id: 'iphone-15',
    name: 'iPhone 15 / 16',
    category: DeviceCategory.celular,
    width: 393,
    height: 852,
    pixelRatio: 3,
  ),
  AuditDevice(
    id: 'pixel-8',
    name: 'Google Pixel 8',
    category: DeviceCategory.celular,
    width: 412,
    height: 915,
    pixelRatio: 2.625,
  ),
  AuditDevice(
    id: 'iphone-pro-max',
    name: 'iPhone 16 Pro Max',
    category: DeviceCategory.celular,
    width: 440,
    height: 956,
    pixelRatio: 3,
  ),
  AuditDevice(
    id: 'cel-texto-130',
    name: 'Android popular con letra grande (130 %)',
    category: DeviceCategory.celular,
    width: 360,
    height: 780,
    pixelRatio: 3,
    textScale: 1.3,
    note: 'Ajuste de accesibilidad común en usuarios mayores.',
  ),
  AuditDevice(
    id: 'cel-texto-200',
    name: 'iPhone 15 con letra máxima (200 %)',
    category: DeviceCategory.celular,
    width: 393,
    height: 852,
    pixelRatio: 3,
    textScale: 2,
    note: 'Máximo de Android 14 y de iOS sin tamaños extra.',
  ),
  AuditDevice(
    id: 'cel-teclado',
    name: 'iPhone SE con el teclado abierto',
    category: DeviceCategory.celular,
    width: 375,
    height: 667,
    pixelRatio: 2,
    keyboardHeight: 260,
    note: 'Formularios mientras se escribe: el teclado ocupa 260 dp.',
  ),
  AuditDevice(
    id: 'cel-horizontal',
    name: 'iPhone 15 en horizontal',
    category: DeviceCategory.celular,
    width: 852,
    height: 393,
    pixelRatio: 3,
  ),
  // Plegables y tablets
  AuditDevice(
    id: 'fold-abierto',
    name: 'Galaxy Z Fold abierto',
    category: DeviceCategory.plegable,
    width: 673,
    height: 841,
    pixelRatio: 2.625,
  ),
  AuditDevice(
    id: 'ipad-mini',
    name: 'iPad mini',
    category: DeviceCategory.tablet,
    width: 744,
    height: 1133,
    pixelRatio: 2,
  ),
  AuditDevice(
    id: 'tab-android',
    name: 'Galaxy Tab A9+ (Android)',
    category: DeviceCategory.tablet,
    width: 800,
    height: 1280,
    pixelRatio: 1.5,
  ),
  AuditDevice(
    id: 'ipad-air',
    name: 'iPad Air 11"',
    category: DeviceCategory.tablet,
    width: 820,
    height: 1180,
    pixelRatio: 2,
  ),
  AuditDevice(
    id: 'ipad-horizontal',
    name: 'iPad Air 11" en horizontal',
    category: DeviceCategory.tablet,
    width: 1180,
    height: 820,
    pixelRatio: 2,
  ),
  AuditDevice(
    id: 'ipad-pro',
    name: 'iPad Pro 13"',
    category: DeviceCategory.tablet,
    width: 1032,
    height: 1376,
    pixelRatio: 2,
  ),
  // Laptops y escritorio (versiones web, Windows, macOS y Linux del proyecto)
  AuditDevice(
    id: 'chromebook',
    name: 'Chromebook / laptop 13"',
    category: DeviceCategory.laptop,
    width: 1280,
    height: 800,
    pixelRatio: 1,
  ),
  AuditDevice(
    id: 'laptop-hd',
    name: 'Laptop HD 15" (la más vendida)',
    category: DeviceCategory.laptop,
    width: 1366,
    height: 768,
    pixelRatio: 1,
  ),
  AuditDevice(
    id: 'macbook-air',
    name: 'MacBook Air 13"',
    category: DeviceCategory.laptop,
    width: 1470,
    height: 956,
    pixelRatio: 2,
  ),
  AuditDevice(
    id: 'monitor-fhd',
    name: 'Monitor Full HD 24"',
    category: DeviceCategory.escritorio,
    width: 1920,
    height: 1080,
    pixelRatio: 1,
  ),
  AuditDevice(
    id: 'monitor-2k',
    name: 'Monitor 2K 27"',
    category: DeviceCategory.escritorio,
    width: 2560,
    height: 1440,
    pixelRatio: 1,
  ),
  // Televisores
  AuditDevice(
    id: 'tv-android',
    name: 'Android TV / Google TV (1080p y 4K)',
    category: DeviceCategory.tv,
    width: 960,
    height: 540,
    pixelRatio: 2,
    note: 'Android TV entrega 960×540 dp tanto en 1080p como en 4K.',
  ),
  AuditDevice(
    id: 'tv-navegador',
    name: 'Navegador de Smart TV (Tizen, webOS)',
    category: DeviceCategory.tv,
    width: 1280,
    height: 720,
    pixelRatio: 1.5,
  ),
];
