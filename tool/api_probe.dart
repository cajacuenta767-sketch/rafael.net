// Sonda del contrato de la API para búsqueda (catálogo de marcas y modelos),
// ciudad (estados y ciudades) y cotizaciones del cliente.
//
// Consulta cada endpoint, muestra el estatus HTTP y compara la forma de la
// respuesta con lo que la app lee. No imprime valores de los registros ni el
// token: solo nombres de claves, tipos y conteos.
//
// Uso, desde la raíz del proyecto:
//
//   dart run tool/api_probe.dart
//   dart run tool/api_probe.dart --token=<jwt> --quote-id=<guid>
//   dart run tool/api_probe.dart --base-url=https://otro-servidor
//
// Opciones: --base-url, --token, --state-id, --brand-id, --quote-id,
// --request-id, --yonke-id. Sin token solo se prueban los catálogos públicos.
// Termina con código 1 si algún endpoint respondió con error o sin las claves
// que la app necesita.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dio/dio.dart';

const _defaultBaseUrl =
    'https://refanetwebapi-a4dhhqd0d7hseqds.westus2-01.azurewebsites.net';

Future<void> main(List<String> arguments) async {
  final options = _parseArguments(arguments);
  if (options == null) {
    exitCode = 2;
    return;
  }

  final baseUrl = options['base-url'] ?? _defaultBaseUrl;
  final token = options['token'] ?? '';
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      // Los códigos de error se reportan, no se lanzan.
      validateStatus: (_) => true,
    ),
  );

  print('Sonda de contrato refaNet');
  print('Servidor: $baseUrl');
  print(
    token.isEmpty
        ? 'Sin token: solo se prueban los catálogos públicos.'
        : 'Con token: se incluyen las cotizaciones del cliente.',
  );
  print('');

  final results = <_Outcome>[];

  // --- Ciudad -------------------------------------------------------------
  final states = await _run(
    dio,
    const _Probe(
      label: 'Estados',
      path: '/api/Utilerias/entidades',
      usedBy: 'ciudad de la solicitud',
      expectedKeys: ['id', 'entidad'],
    ),
  );
  results.add(states);

  final stateId = int.tryParse(options['state-id'] ?? '') ?? states.firstId;
  if (stateId == null) {
    _skip('Ciudades del estado', 'no hay estados; pasa --state-id=<id>');
  } else {
    results.add(
      await _run(
        dio,
        _Probe(
          label: 'Ciudades del estado $stateId',
          path: '/api/Utilerias/entidad/$stateId/ciudades',
          usedBy: 'ciudad de la solicitud',
          expectedKeys: const ['id', 'ciudad'],
          optionalKeys: const ['entidade', 'entidad'],
        ),
      ),
    );
  }

  // --- Búsqueda (catálogos de los filtros y de la nueva solicitud) --------
  final brands = await _run(
    dio,
    const _Probe(
      label: 'Marcas',
      path: '/api/Utilerias/marcas',
      usedBy: 'filtros de búsqueda y nueva solicitud',
      expectedKeys: ['id', 'marca'],
    ),
  );
  results.add(brands);

  final brandId = int.tryParse(options['brand-id'] ?? '') ?? brands.firstId;
  if (brandId == null) {
    _skip('Modelos de la marca', 'no hay marcas; pasa --brand-id=<id>');
  } else {
    results.add(
      await _run(
        dio,
        _Probe(
          label: 'Modelos de la marca $brandId',
          path: '/api/Utilerias/modelos',
          query: {'marcaId': brandId},
          usedBy: 'filtros de búsqueda y nueva solicitud',
          expectedKeys: const ['id', 'modelo'],
        ),
      ),
    );
  }

  // --- Cotizaciones (requieren sesión) ------------------------------------
  const quoteKeys = ['guidId', 'precio', 'disponible', 'activo'];
  const quoteNestedKeys = [
    'solicitudYonkes.solicitudGuidId',
    'solicitudYonkes.yonkeGuidId',
    'solicitudYonkes.yonkes.nombre',
    'solicitudCotizacionEstatus.descripcion',
  ];
  if (token.isEmpty) {
    _skip('Mis solicitudes', 'requiere --token=<jwt>');
    _skip('Solicitud reciente', 'requiere --token=<jwt>');
    _skip('Mis cotizaciones', 'requiere --token=<jwt>');
    _skip('Detalle de cotización', 'requiere --token=<jwt>');
    _skip('Ciudades de la solicitud', 'requiere --token=<jwt>');
    _skip('Perfil del yonke', 'requiere --token=<jwt> y --yonke-id=<guid>');
    _skip('Cobertura del yonke', 'requiere --token=<jwt> y --yonke-id=<guid>');
  } else {
    results.add(
      await _run(
        dio,
        const _Probe(
          label: 'Mis solicitudes',
          path: '/api/DashboardSuscriptores/mis-solicitudes',
          query: {'Page': 1, 'CantidadRegistrosPorPagina': 5},
          usedBy: 'mis solicitudes (cliente) y bandeja del yonke',
          expectedKeys: ['guidId', 'piezaBuscada'],
          optionalKeys: [
            'marca',
            'modelo',
            'estatusSolicitud',
            'totalCotizaciones',
            'solicitudGuidId',
            'solicitudes',
          ],
        ),
      ),
    );
    results.add(
      await _run(
        dio,
        const _Probe(
          label: 'Solicitud reciente',
          path: '/api/DashboardSuscriptores/mi-solicitud-reciente',
          usedBy: 'inicio del cliente',
          expectedKeys: ['guidId', 'piezaBuscada'],
        ),
      ),
    );
    final quotes = await _run(
      dio,
      const _Probe(
        label: 'Mis cotizaciones',
        path: '/api/DashboardSuscriptores/mis-cotizaciones',
        usedBy: 'cotizaciones recibidas por solicitud',
        expectedKeys: quoteKeys,
        nestedKeys: quoteNestedKeys,
      ),
    );
    results.add(quotes);

    final quoteId = options['quote-id'] ?? quotes.firstGuid;
    if (quoteId == null || quoteId.isEmpty) {
      _skip('Detalle de cotización', 'no hay guidId; pasa --quote-id=<guid>');
    } else {
      results.add(
        await _run(
          dio,
          _Probe(
            label: 'Detalle de cotización',
            path: '/api/CotizacionYonke/$quoteId',
            usedBy: 'detalle de cotización',
            expectedKeys: quoteKeys,
            nestedKeys: quoteNestedKeys,
          ),
        ),
      );
    }

    final yonkeId = options['yonke-id'];
    if (yonkeId == null || yonkeId.isEmpty) {
      _skip('Perfil del yonke', 'pasa --yonke-id=<guid>');
      _skip('Cobertura del yonke', 'pasa --yonke-id=<guid>');
    } else {
      results.add(
        await _run(
          dio,
          _Probe(
            label: 'Perfil del yonke',
            path: '/api/Yonkes/$yonkeId',
            usedBy: 'perfil del yonke',
            expectedKeys: const ['guidId', 'nombre'],
            optionalKeys: const ['telefono', 'correo', 'direccion', 'ciudades'],
          ),
        ),
      );
      results.add(
        await _run(
          dio,
          _Probe(
            label: 'Cobertura del yonke',
            path: '/api/YonkesCoberturas/guid/$yonkeId',
            usedBy: 'cobertura del yonke',
            expectedKeys: const ['ciudadId'],
            optionalKeys: const ['activo'],
          ),
        ),
      );
    }

    final requestId = options['request-id'];
    if (requestId == null || requestId.isEmpty) {
      _skip('Ciudades de la solicitud', 'pasa --request-id=<guid>');
    } else {
      results.add(
        await _run(
          dio,
          _Probe(
            label: 'Ciudades de la solicitud',
            path: '/api/SolicitudCiudades/$requestId/ciudades',
            usedBy: 'ciudades asociadas a una solicitud',
          ),
        ),
      );
    }
  }

  final failed = results.where((outcome) => outcome.failed).length;
  print(
    'Resumen: ${results.length} endpoints consultados, $failed con problemas.',
  );
  exitCode = failed == 0 ? 0 : 1;
}

class _Probe {
  const _Probe({
    required this.label,
    required this.path,
    required this.usedBy,
    this.query = const {},
    this.expectedKeys = const [],
    this.optionalKeys = const [],
    this.nestedKeys = const [],
  });

  final String label;
  final String path;
  final String usedBy;
  final Map<String, Object?> query;

  /// Claves que la app lee en cada registro. Si falta alguna, hay problema.
  final List<String> expectedKeys;

  /// Claves que la app usa si existen, con alternativa si no.
  final List<String> optionalKeys;

  /// Claves anidadas, en notación con puntos, que la app también lee.
  final List<String> nestedKeys;
}

class _Outcome {
  const _Outcome({required this.failed, this.firstId, this.firstGuid});

  final bool failed;
  final int? firstId;
  final String? firstGuid;
}

Future<_Outcome> _run(Dio dio, _Probe probe) async {
  final query = probe.query.entries.map((e) => '${e.key}=${e.value}').join('&');
  final shownPath = query.isEmpty ? probe.path : '${probe.path}?$query';
  print('${probe.label}: GET $shownPath');
  print('    usado por: ${probe.usedBy}');

  final watch = Stopwatch()..start();
  final Response<dynamic> response;
  try {
    response = await dio.get<dynamic>(
      probe.path,
      queryParameters: probe.query.isEmpty ? null : probe.query,
    );
  } on DioException catch (error) {
    print('    ERROR de red: ${error.type.name} ${error.message ?? ''}'.trim());
    print('');
    return const _Outcome(failed: true);
  }
  watch.stop();

  final status = response.statusCode ?? 0;
  print('    HTTP $status en ${watch.elapsedMilliseconds} ms');
  final body = response.data;
  if (status < 200 || status >= 300) {
    print('    cuerpo: ${_describe(body)}');
    if (body is Map && body['message'] is String) {
      print('    message: ${body['message']}');
    }
    if (status == 401 || status == 403) {
      print('    requiere sesión: pasa --token=<jwt> de un login válido');
    }
    print('');
    return const _Outcome(failed: true);
  }

  Object? data = body;
  if (body is Map) {
    if (body.containsKey('success') || body.containsKey('data')) {
      print(
        '    sobre ApiResponseGlobal: success=${body['success']} '
        'statusCode=${body['statusCode']} '
        'message=${body['message'] == null ? 'no' : 'sí'}',
      );
      data = body['data'];
    } else {
      print('    sin sobre: objeto con claves ${_keys(body)}');
    }
  }

  Map<dynamic, dynamic>? sample;
  if (data is List) {
    final records = data.whereType<Map>();
    print('    data: lista con ${data.length} registros');
    sample = records.isEmpty ? null : records.first;
  } else if (data is Map) {
    print('    data: objeto');
    sample = data;
  } else {
    print('    data: ${_describe(data)}');
  }

  var failed = false;
  if (sample == null) {
    if (probe.expectedKeys.isNotEmpty) {
      print('    sin registros: no se pudo verificar la forma');
    }
  } else {
    print('    claves del registro: ${_keys(sample)}');
    for (final key in probe.expectedKeys) {
      final present = sample.containsKey(key);
      if (!present) failed = true;
      print('    ${present ? 'OK    ' : 'FALTA '}$key');
    }
    for (final key in probe.optionalKeys) {
      print('    ${sample.containsKey(key) ? 'OK    ' : 'opc.  '}$key');
    }
    for (final path in probe.nestedKeys) {
      final present = _hasPath(sample, path);
      if (!present) failed = true;
      print('    ${present ? 'OK    ' : 'FALTA '}$path');
    }
  }
  print('');

  final id = sample?['id'];
  final guid = sample?['guidId'];
  return _Outcome(
    failed: failed,
    firstId: id is num ? id.toInt() : int.tryParse('$id'),
    firstGuid: guid?.toString(),
  );
}

void _skip(String label, String reason) {
  print('$label: OMITIDO ($reason)');
  print('');
}

bool _hasPath(Map<dynamic, dynamic> record, String path) {
  Object? current = record;
  for (final segment in path.split('.')) {
    if (current is! Map || !current.containsKey(segment)) return false;
    current = current[segment];
  }
  return true;
}

String _keys(Map<dynamic, dynamic> record) =>
    record.keys.map((key) => '$key').join(', ');

String _describe(Object? value) => switch (value) {
  null => 'vacío',
  String() => 'texto de ${value.length} caracteres',
  List() => 'lista con ${value.length} elementos',
  Map() => 'objeto con claves ${_keys(value)}',
  _ => value.runtimeType.toString(),
};

const _knownOptions = {
  'base-url',
  'token',
  'state-id',
  'brand-id',
  'quote-id',
  'request-id',
  'yonke-id',
};

Map<String, String>? _parseArguments(List<String> arguments) {
  final options = <String, String>{};
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--help' || argument == '-h') {
      _printUsage();
      return null;
    }
    if (!argument.startsWith('--')) {
      print('Argumento no reconocido: $argument');
      _printUsage();
      return null;
    }
    final separator = argument.indexOf('=');
    final name = separator == -1
        ? argument.substring(2)
        : argument.substring(2, separator);
    if (!_knownOptions.contains(name)) {
      print('Opción no reconocida: --$name');
      _printUsage();
      return null;
    }
    if (separator != -1) {
      options[name] = argument.substring(separator + 1);
    } else if (index + 1 < arguments.length) {
      options[name] = arguments[++index];
    } else {
      print('Falta el valor de --$name');
      _printUsage();
      return null;
    }
  }
  return options;
}

void _printUsage() {
  print('Uso: dart run tool/api_probe.dart [opciones]');
  for (final option in _knownOptions) {
    print('  --$option=<valor>');
  }
}
