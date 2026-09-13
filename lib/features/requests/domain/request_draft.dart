import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class RequestDraft {
  String part = '';
  int? brandId;
  String? brandName;
  int? modelId;
  String? modelName;
  int? year;
  String? description;

  /// Ciudad principal (la primera elegida). Se conserva por compatibilidad.
  int? cityId;
  String? cityName;

  /// Ciudades adicionales con cobertura; el API acepta varias por solicitud.
  final extraCityIds = <int>[];
  final extraCityNames = <String>[];

  /// Todas las ciudades, principal primero y sin repetidos.
  List<int> get allCityIds => [
    ?cityId,
    ...extraCityIds.where((id) => id != cityId),
  ];

  String get citiesLabel => [?cityName, ...extraCityNames].join(', ');

  final photos = <RequestPhoto>[];
}

class RequestPhoto {
  const RequestPhoto({required this.file, required this.bytes});

  final XFile file;
  final Uint8List bytes;
}
