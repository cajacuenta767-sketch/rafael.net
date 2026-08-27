typedef JsonMap = Map<String, dynamic>;

class ApiEnvelope<T> {
  const ApiEnvelope({
    required this.success,
    required this.message,
    required this.data,
    required this.statusCode,
    required this.errors,
  });

  final bool success;
  final String? message;
  final T? data;
  final int? statusCode;
  final Object? errors;

  factory ApiEnvelope.fromJson(
    JsonMap json,
    T Function(Object? json) decodeData,
  ) {
    return ApiEnvelope(
      success: json['success'] == true,
      message: json['message'] as String?,
      data: json.containsKey('data') ? decodeData(json['data']) : null,
      statusCode: (json['statusCode'] as num?)?.toInt(),
      errors: json['errors'],
    );
  }
}
