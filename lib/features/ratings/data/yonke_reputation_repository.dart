import '../../yonkes/data/yonkes_api.dart';
import '../domain/yonke_reputation.dart';

abstract interface class YonkeReputationRepository {
  Future<YonkeReputation> getReputation(String yonkeId);
}

class ApiYonkeReputationRepository implements YonkeReputationRepository {
  const ApiYonkeReputationRepository(this._yonkesApi);

  final YonkesApi _yonkesApi;

  @override
  Future<YonkeReputation> getReputation(String yonkeId) async {
    final response = await _yonkesApi.getRatings(yonkeId);
    return reputationFromResponse(response);
  }
}

YonkeReputation reputationFromResponse(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  final records = switch (data) {
    List() => data,
    Map() when data['items'] is List => data['items'] as List,
    Map() when data['registros'] is List => data['registros'] as List,
    _ => const <dynamic>[],
  };
  return YonkeReputation(
    records: records
        .whereType<Map>()
        .where((item) => item['activa'] != false)
        .map(_ratingFromJson)
        .whereType<YonkeRatingRecord>()
        .toList(growable: false),
  );
}

YonkeRatingRecord? _ratingFromJson(Map<dynamic, dynamic> json) {
  final value = json['calificacion'];
  final rating = value is num ? value.toInt() : int.tryParse('$value');
  if (rating == null || rating < 1 || rating > 5) return null;
  final createdAt = DateTime.tryParse(json['fechaCreacion']?.toString() ?? '');
  final comment = json['comentario']?.toString().trim();
  return YonkeRatingRecord(
    rating: rating,
    comment: comment == null || comment.isEmpty ? null : comment,
    createdAt: createdAt,
  );
}
