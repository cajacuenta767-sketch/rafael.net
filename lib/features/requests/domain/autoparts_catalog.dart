class AutopartItem {
  const AutopartItem({
    required this.name,
    required this.category,
    this.hasSides = false,
    this.aliases = const [],
  });

  final String name;
  final String category;
  final bool hasSides;
  final List<String> aliases;
}

String normalizeText(String input) {
  var output = input.toLowerCase().trim();
  const diacritics = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  diacritics.forEach((key, value) {
    output = output.replaceAll(key, value);
  });
  return output;
}

const catalogCategories = [
  'Todas',
  'Carrocería',
  'Cristales',
  'Motor',
  'Eléctrico',
  'Enfriamiento',
  'Transmisión',
  'Suspensión',
  'Frenos',
  'Iluminación',
  'Interiores',
];

List<AutopartItem> searchAutoparts(String query, {String category = 'Todas'}) {
  final cleanQuery = normalizeText(query);
  var pool = autopartsCatalog;
  if (category != 'Todas') {
    pool = pool.where((item) => item.category == category).toList();
  }

  if (cleanQuery.isEmpty) {
    final list = List<AutopartItem>.from(pool);
    list.sort((a, b) => normalizeText(a.name).compareTo(normalizeText(b.name)));
    return list;
  }

  final ranked = <({AutopartItem item, int score})>[];

  for (final item in pool) {
    final cleanName = normalizeText(item.name);
    final words = cleanName.split(RegExp(r'\s+'));
    int bestScore = 0;

    // 1. Coincidencia exacta (1000 pts)
    if (cleanName == cleanQuery) {
      bestScore = 1000;
    }
    // 2. El nombre comienza con el término de búsqueda (500 pts)
    else if (cleanName.startsWith(cleanQuery)) {
      bestScore = 500;
    }
    // 3. Alguna palabra dentro del nombre comienza con el término (300 pts)
    else if (words.any((w) => w.startsWith(cleanQuery))) {
      bestScore = 300;
    } else if (cleanQuery.length >= 2) {
      // 4. Búsqueda en alias / sinónimos populares (solo a partir de 2 letras)
      for (final alias in item.aliases) {
        final cleanAlias = normalizeText(alias);
        final aliasWords = cleanAlias.split(RegExp(r'\s+'));
        if (cleanAlias == cleanQuery) {
          bestScore = bestScore < 400 ? 400 : bestScore;
        } else if (cleanAlias.startsWith(cleanQuery)) {
          bestScore = bestScore < 250 ? 250 : bestScore;
        } else if (cleanQuery.length >= 3 &&
            aliasWords.any((w) => w.startsWith(cleanQuery))) {
          bestScore = bestScore < 200 ? 200 : bestScore;
        }
      }
    }

    // 5. Subcadena interna (50 pts) SOLO para consultas de 3 o más letras
    // Para consultas de 1 o 2 letras (ej. "f" o "fa") las subcadenas están bloqueadas
    // para evitar que "Cofre" o "MAF" aparezcan ante la letra "F".
    if (bestScore == 0 && cleanQuery.length >= 3) {
      if (cleanName.contains(cleanQuery)) {
        bestScore = 50;
      } else {
        for (final alias in item.aliases) {
          if (normalizeText(alias).contains(cleanQuery)) {
            bestScore = 30;
            break;
          }
        }
      }
    }

    if (bestScore > 0) {
      ranked.add((item: item, score: bestScore));
    }
  }

  ranked.sort((a, b) {
    final scoreDiff = b.score.compareTo(a.score);
    if (scoreDiff != 0) return scoreDiff;
    return normalizeText(a.item.name).compareTo(normalizeText(b.item.name));
  });

  return ranked.map((entry) => entry.item).toList();
}

const popularAutopartChips = [
  'Faro delantero',
  'Facia delantera',
  'Calavera',
  'Motor',
  'Alternador',
  'Transmisión',
  'Compresor A/C',
  'Espejo lateral',
  'Puerta',
  'Amortiguador',
];

const autopartsCatalog = [
  // 1. Carrocería y Colisión
  AutopartItem(
    name: 'Faro delantero',
    category: 'Carrocería',
    hasSides: true,
    aliases: ['foco delantero', 'luz delantera', 'optica', 'farola', 'faro'],
  ),
  AutopartItem(
    name: 'Calavera',
    category: 'Carrocería',
    hasSides: true,
    aliases: [
      'faro trasero',
      'stop',
      'luz trasera',
      'piloto trasero',
      'calaveras',
    ],
  ),
  AutopartItem(
    name: 'Faro de niebla',
    category: 'Carrocería',
    hasSides: true,
    aliases: [
      'neblinero',
      'faros de niebla',
      'luz antiniebla',
      'faros auxiliares',
    ],
  ),
  AutopartItem(
    name: 'Facia delantera',
    category: 'Carrocería',
    aliases: [
      'defensa delantera',
      'bumper delantero',
      'paragolpes delantero',
      'parachoques delantero',
    ],
  ),
  AutopartItem(
    name: 'Facia trasera',
    category: 'Carrocería',
    aliases: [
      'defensa trasera',
      'bumper trasero',
      'paragolpes trasero',
      'parachoques trasero',
    ],
  ),
  AutopartItem(
    name: 'Cofre',
    category: 'Carrocería',
    aliases: ['capo', 'capot', 'tapa de motor', 'bonete'],
  ),
  AutopartItem(
    name: 'Parrilla delantera',
    category: 'Carrocería',
    aliases: ['rejilla', 'grille', 'parrilla frontal'],
  ),
  AutopartItem(
    name: 'Salpicadera',
    category: 'Carrocería',
    hasSides: true,
    aliases: ['guardafango', 'guardabarros', 'aleta', 'lodera'],
  ),
  AutopartItem(
    name: 'Puerta delantera',
    category: 'Carrocería',
    hasSides: true,
    aliases: ['portezuela delantera', 'puerta piloto', 'puerta copiloto'],
  ),
  AutopartItem(
    name: 'Puerta trasera',
    category: 'Carrocería',
    hasSides: true,
    aliases: ['portezuela trasera'],
  ),
  AutopartItem(
    name: 'Tapa de cajuela',
    category: 'Carrocería',
    aliases: ['maletero', 'baul', 'compuerta trasera', 'porton trasero'],
  ),
  AutopartItem(
    name: 'Espejo lateral',
    category: 'Carrocería',
    hasSides: true,
    aliases: ['retrovisor lateral', 'espejo exterior', 'espejo retrovisor'],
  ),
  AutopartItem(
    name: 'Alma de facia delantera',
    category: 'Carrocería',
    aliases: [
      'barra de impacto delantera',
      'esqueleto de facia',
      'refuerzo de defensa',
    ],
  ),
  AutopartItem(
    name: 'Alma de facia trasera',
    category: 'Carrocería',
    aliases: ['barra de impacto trasera', 'refuerzo de facia trasera'],
  ),
  AutopartItem(
    name: 'Marco de radiador',
    category: 'Carrocería',
    aliases: ['frente estructural', 'soporte de radiador', 'panel frontal'],
  ),
  AutopartItem(
    name: 'Estribo lateral',
    category: 'Carrocería',
    hasSides: true,
    aliases: ['faldon lateral', 'talonera', 'estribos'],
  ),
  AutopartItem(
    name: 'Quemacocos',
    category: 'Carrocería',
    aliases: ['techo corredizo', 'sunroof', 'moonroof'],
  ),

  // 2. Cristales
  AutopartItem(
    name: 'Parabrisas',
    category: 'Cristales',
    aliases: ['vidrio delantero', 'cristal frontal', 'windshield'],
  ),
  AutopartItem(
    name: 'Medallón trasero',
    category: 'Cristales',
    aliases: ['cristal trasero', 'vidrio trasero', 'luna trasera'],
  ),
  AutopartItem(
    name: 'Cristal de puerta',
    category: 'Cristales',
    hasSides: true,
    aliases: ['vidrio de ventana', 'vidrio lateral'],
  ),
  AutopartItem(
    name: 'Cristal aleta',
    category: 'Cristales',
    hasSides: true,
    aliases: ['vidrio custode', 'vidrio triangular'],
  ),
  AutopartItem(
    name: 'Espejo retrovisor interior',
    category: 'Cristales',
    aliases: ['retrovisor central', 'espejo de cabina'],
  ),

  // 3. Motor y Componentes Internos
  AutopartItem(
    name: 'Motor completo',
    category: 'Motor',
    aliases: ['motor', 'motor 3/4', 'motor 7/8', 'maquina', 'bloque armado'],
  ),
  AutopartItem(
    name: 'Cabeza de motor',
    category: 'Motor',
    aliases: ['culata', 'cabezal', 'cabeza con valvulas'],
  ),
  AutopartItem(
    name: 'Bloque de motor',
    category: 'Motor',
    aliases: ['monoblock', 'block'],
  ),
  AutopartItem(
    name: 'Árbol de levas',
    category: 'Motor',
    aliases: ['arbol de levas', 'eje de levas', 'camshaft'],
  ),
  AutopartItem(
    name: 'Cigüeñal',
    category: 'Motor',
    aliases: ['cigueñal', 'crankshaft'],
  ),
  AutopartItem(
    name: 'Cárter de aceite',
    category: 'Motor',
    aliases: ['carter', 'deposito de aceite'],
  ),
  AutopartItem(
    name: 'Múltiple de admisión',
    category: 'Motor',
    aliases: ['multiple de admision', 'intake manifold'],
  ),
  AutopartItem(
    name: 'Múltiple de escape',
    category: 'Motor',
    aliases: ['multiple de escape', 'headers'],
  ),
  AutopartItem(
    name: 'Tapa de punterías',
    category: 'Motor',
    aliases: ['tapa de valvulas', 'valve cover'],
  ),
  AutopartItem(
    name: 'Soporte de motor',
    category: 'Motor',
    hasSides: true,
    aliases: ['tacon de motor', 'base de motor'],
  ),
  AutopartItem(
    name: 'Turbo cargador',
    category: 'Motor',
    aliases: ['turbo', 'turbocompresor', 'intercooler'],
  ),

  // 4. Sistema Eléctrico, Módulos e Ignición
  AutopartItem(
    name: 'Alternador',
    category: 'Eléctrico',
    aliases: ['generador de corriente'],
  ),
  AutopartItem(
    name: 'Marcha',
    category: 'Eléctrico',
    aliases: ['motor de arranque', 'starter', 'arrancador'],
  ),
  AutopartItem(
    name: 'Computadora de motor',
    category: 'Eléctrico',
    aliases: ['ecu', 'pcm', 'modulo de motor', 'computadora automotriz'],
  ),
  AutopartItem(
    name: 'Módulo BCM',
    category: 'Eléctrico',
    aliases: ['modulo de carroceria', 'body control module'],
  ),
  AutopartItem(
    name: 'Módulo TCM',
    category: 'Eléctrico',
    aliases: ['computadora de transmision', 'modulo de caja'],
  ),
  AutopartItem(
    name: 'Caja de fusibles',
    category: 'Eléctrico',
    aliases: ['fusiblera', 'ipdm', 'caja de reles'],
  ),
  AutopartItem(
    name: 'Bobina de encendido',
    category: 'Eléctrico',
    aliases: ['bobinas', 'ignition coil', 'paquete de bobinas'],
  ),
  AutopartItem(
    name: 'Distribuidor',
    category: 'Eléctrico',
    aliases: ['distribuidor de encendido'],
  ),
  AutopartItem(
    name: 'Sensor MAF',
    category: 'Eléctrico',
    aliases: ['sensor de flujo de aire', 'flujometro'],
  ),
  AutopartItem(
    name: 'Sensor de oxígeno',
    category: 'Eléctrico',
    aliases: ['sensor o2', 'sensor lambda'],
  ),
  AutopartItem(
    name: 'Sensor de cigüeñal (CKP)',
    category: 'Eléctrico',
    aliases: ['sensor ckp', 'sensor de posicion de cigueñal'],
  ),
  AutopartItem(
    name: 'Mando de luces',
    category: 'Eléctrico',
    aliases: ['palanca de direccionales', 'switch de luces'],
  ),
  AutopartItem(
    name: 'Botonera de elevadores',
    category: 'Eléctrico',
    aliases: ['master switch', 'control de vidrios', 'botones de ventana'],
  ),
  AutopartItem(
    name: 'Arnés eléctrico',
    category: 'Eléctrico',
    aliases: ['cableado de motor', 'ramal electrico'],
  ),

  // 5. Enfriamiento y Clima
  AutopartItem(
    name: 'Radiador',
    category: 'Enfriamiento',
    aliases: ['radiador de agua', 'radiador de enfriamiento'],
  ),
  AutopartItem(
    name: 'Motoventilador',
    category: 'Enfriamiento',
    aliases: [
      'abanico con tolva',
      'ventilador de radiador',
      'electroventilador',
    ],
  ),
  AutopartItem(
    name: 'Condensador de A/C',
    category: 'Enfriamiento',
    aliases: ['condensador de clima', 'radiador de aire acondicionado'],
  ),
  AutopartItem(
    name: 'Compresor de A/C',
    category: 'Enfriamiento',
    aliases: ['compresor de aire acondicionado', 'bomba de clima'],
  ),
  AutopartItem(
    name: 'Evaporador de clima',
    category: 'Enfriamiento',
    aliases: ['evaporador a/c', 'nucleo de calefaccion'],
  ),
  AutopartItem(
    name: 'Depósito recuperador',
    category: 'Enfriamiento',
    aliases: ['deposito de anticongelante', 'tanque de expansion'],
  ),
  AutopartItem(
    name: 'Bomba de agua',
    category: 'Enfriamiento',
    aliases: ['water pump'],
  ),
  AutopartItem(
    name: 'Termostato',
    category: 'Enfriamiento',
    aliases: ['toma de agua con termostato', 'caja de agua'],
  ),

  // 6. Transmisión y Tren Motriz
  AutopartItem(
    name: 'Transmisión automática',
    category: 'Transmisión',
    aliases: [
      'caja automatica',
      'transmision cvt',
      'caja de velocidades automatica',
    ],
  ),
  AutopartItem(
    name: 'Transmisión manual',
    category: 'Transmisión',
    aliases: ['caja manual', 'caja estandar', 'transmision estandar'],
  ),
  AutopartItem(
    name: 'Convertidor de par',
    category: 'Transmisión',
    aliases: ['turbina de transmision', 'torque converter'],
  ),
  AutopartItem(
    name: 'Flecha cardán',
    category: 'Transmisión',
    aliases: ['cardan', 'barra de transmision', 'eje cardan'],
  ),
  AutopartItem(
    name: 'Flecha homocinética',
    category: 'Transmisión',
    hasSides: true,
    aliases: ['semieje', 'palier', 'eje homocinetico', 'flecha'],
  ),
  AutopartItem(
    name: 'Diferencial',
    category: 'Transmisión',
    aliases: [
      'calabaza de diferencial',
      'diferencial trasero',
      'corona y piñon',
    ],
  ),
  AutopartItem(
    name: 'Caja de transferencia',
    category: 'Transmisión',
    aliases: ['transfer 4x4', 'caja transfer'],
  ),
  AutopartItem(
    name: 'Chicote de velocidades',
    category: 'Transmisión',
    aliases: ['palanca selectora', 'cables de cambios'],
  ),

  // 7. Suspensión y Dirección
  AutopartItem(
    name: 'Amortiguador delantero',
    category: 'Suspensión',
    hasSides: true,
    aliases: ['amortiguadores delanteros', 'strut delantero'],
  ),
  AutopartItem(
    name: 'Amortiguador trasero',
    category: 'Suspensión',
    hasSides: true,
    aliases: ['amortiguadores traseros'],
  ),
  AutopartItem(
    name: 'Horquilla de suspensión',
    category: 'Suspensión',
    hasSides: true,
    aliases: ['brazo de suspension', 'trapecio', 'tijera de suspension'],
  ),
  AutopartItem(
    name: 'Barra estabilizadora',
    category: 'Suspensión',
    aliases: ['barra de torsion', 'cacahuates', 'tornillos estabilizadores'],
  ),
  AutopartItem(
    name: 'Cremallera de dirección',
    category: 'Suspensión',
    aliases: [
      'caja de direccion',
      'direccion electroasistida',
      'direccion hidraulica',
    ],
  ),
  AutopartItem(
    name: 'Bomba de dirección',
    category: 'Suspensión',
    aliases: ['bomba hidraulica de direccion', 'power steering pump'],
  ),
  AutopartItem(
    name: 'Mangueta de rueda',
    category: 'Suspensión',
    hasSides: true,
    aliases: ['mango de rueda', 'portamaza', 'spindle'],
  ),
  AutopartItem(
    name: 'Masa balero',
    category: 'Suspensión',
    hasSides: true,
    aliases: ['maza de rueda', 'rodamiento de rueda', 'hub'],
  ),
  AutopartItem(
    name: 'Puente delantero',
    category: 'Suspensión',
    aliases: ['subchasis', 'cuna de motor', 'puente de suspension'],
  ),
  AutopartItem(
    name: 'Eje trasero',
    category: 'Suspensión',
    aliases: ['puente trasero', 'eje rigido'],
  ),

  // 8. Frenos
  AutopartItem(
    name: 'Caliper de freno',
    category: 'Frenos',
    hasSides: true,
    aliases: ['mordaza de freno', 'pinza de freno'],
  ),
  AutopartItem(
    name: 'Booster de frenos',
    category: 'Frenos',
    aliases: ['servofreno', 'boster'],
  ),
  AutopartItem(
    name: 'Bomba de frenos',
    category: 'Frenos',
    aliases: ['cilindro maestro', 'master cylinder'],
  ),
  AutopartItem(
    name: 'Módulo ABS',
    category: 'Frenos',
    aliases: ['bomba abs', 'modulo antibloqueo'],
  ),
  AutopartItem(
    name: 'Disco de freno',
    category: 'Frenos',
    hasSides: true,
    aliases: ['rotores de freno'],
  ),

  // 9. Interior y Seguridad
  AutopartItem(
    name: 'Bolsa de aire de volante',
    category: 'Interior',
    aliases: ['airbag piloto', 'bolsa de aire conductor'],
  ),
  AutopartItem(
    name: 'Bolsa de aire de tablero',
    category: 'Interior',
    aliases: ['airbag copiloto', 'bolsa de aire pasajero'],
  ),
  AutopartItem(
    name: 'Bolsas de aire laterales',
    category: 'Interior',
    hasSides: true,
    aliases: ['airbags de cortina'],
  ),
  AutopartItem(
    name: 'Módulo SRS',
    category: 'Interior',
    aliases: ['modulo de bolsas de aire', 'sensor de impacto'],
  ),
  AutopartItem(
    name: 'Tablero de instrumentos',
    category: 'Interior',
    aliases: ['cluster', 'velocimetro', 'tacometro', 'cuadro de instrumentos'],
  ),
  AutopartItem(
    name: 'Cinturón de seguridad',
    category: 'Interior',
    hasSides: true,
    aliases: ['cinturon con pretensor'],
  ),
  AutopartItem(
    name: 'Chapa de puerta',
    category: 'Interior',
    hasSides: true,
    aliases: ['cerradura de puerta', 'actuador de seguro'],
  ),
  AutopartItem(
    name: 'Motor elevador de cristal',
    category: 'Interior',
    hasSides: true,
    aliases: ['mecanismo elevador', 'maquinaria de vidrio'],
  ),
];
