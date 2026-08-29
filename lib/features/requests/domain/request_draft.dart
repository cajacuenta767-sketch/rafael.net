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
  int? cityId;
  String? cityName;
  final photos = <RequestPhoto>[];
}

class RequestPhoto {
  const RequestPhoto({required this.file, required this.bytes});

  final XFile file;
  final Uint8List bytes;
}
