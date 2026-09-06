import '../domain/part_search.dart';

abstract interface class PartsSearchRepository {
  Future<List<PartSearchResult>> search(
    String query,
    PartSearchFilters filters,
  );
}

/// El OpenAPI no publica un buscador de refacciones. La pantalla informa la
/// situación y ofrece crear la solicitud con los datos capturados.
class UnavailablePartsSearchRepository implements PartsSearchRepository {
  const UnavailablePartsSearchRepository();

  @override
  Future<List<PartSearchResult>> search(
    String query,
    PartSearchFilters filters,
  ) => throw const SearchUnavailableException();
}

class SearchUnavailableException implements Exception {
  const SearchUnavailableException();
}
