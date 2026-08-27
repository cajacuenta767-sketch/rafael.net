import 'dart:typed_data';

class ApiFile {
  const ApiFile({
    required this.fieldName,
    required this.fileName,
    required this.bytes,
  });

  final String fieldName;
  final String fileName;
  final Uint8List bytes;
}
