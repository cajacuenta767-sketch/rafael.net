import '../../yonkes/data/yonkes_api.dart';

abstract interface class ClientRatingsRepository {
  Future<void> register({
    required String quoteId,
    required int rating,
    String? comment,
  });
}

class ApiClientRatingsRepository implements ClientRatingsRepository {
  const ApiClientRatingsRepository(this._yonkesApi);

  final YonkesApi _yonkesApi;

  @override
  Future<void> register({
    required String quoteId,
    required int rating,
    String? comment,
  }) => _yonkesApi.registerRating(
    quoteId: quoteId,
    rating: rating,
    comment: comment,
  );
}
