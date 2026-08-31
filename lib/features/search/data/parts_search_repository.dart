import '../domain/part_search.dart';

abstract interface class PartsSearchRepository {
  bool get usesDemoData;

  Future<List<PartSearchResult>> search(
    String query,
    PartSearchFilters filters,
  );
}

class DemoPartsSearchRepository implements PartsSearchRepository {
  const DemoPartsSearchRepository();

  @override
  bool get usesDemoData => true;

  @override
  Future<List<PartSearchResult>> search(
    String query,
    PartSearchFilters filters,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final normalized = _normalize(query);
    return demoPartSearchResults.where((result) {
      final searchable = _normalize(
        [
          result.partName,
          result.category,
          result.brandName,
          result.modelName,
          result.year,
        ].whereType<Object>().join(' '),
      );
      return searchable.contains(normalized) &&
          (filters.category == null || result.category == filters.category) &&
          (filters.brandId == null || result.brandId == filters.brandId) &&
          (filters.modelId == null || result.modelId == filters.modelId) &&
          (filters.year == null || result.year == filters.year);
    }).toList();
  }
}

class UnavailablePartsSearchRepository implements PartsSearchRepository {
  const UnavailablePartsSearchRepository();

  @override
  bool get usesDemoData => false;

  @override
  Future<List<PartSearchResult>> search(
    String query,
    PartSearchFilters filters,
  ) => throw const SearchUnavailableException();
}

class SearchUnavailableException implements Exception {
  const SearchUnavailableException();
}

String _normalize(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[áàä]'), 'a')
    .replaceAll(RegExp(r'[éèë]'), 'e')
    .replaceAll(RegExp(r'[íìï]'), 'i')
    .replaceAll(RegExp(r'[óòö]'), 'o')
    .replaceAll(RegExp(r'[úùü]'), 'u');

const demoPartSearchResults = <PartSearchResult>[
  PartSearchResult(
    id: 'demo-alternador-nissan-sentra-2018',
    partName: 'Alternador',
    category: 'Eléctrico',
    brandId: 1,
    brandName: 'Nissan',
    modelId: 1,
    modelName: 'Sentra',
    year: 2018,
    description: 'Referencia de demostración para crear una solicitud.',
  ),
  PartSearchResult(
    id: 'demo-radiador-nissan-versa-2020',
    partName: 'Radiador',
    category: 'Enfriamiento',
    brandId: 1,
    brandName: 'Nissan',
    modelId: 2,
    modelName: 'Versa',
    year: 2020,
    description: 'Referencia de demostración para crear una solicitud.',
  ),
  PartSearchResult(
    id: 'demo-transmision-toyota-corolla-2019',
    partName: 'Transmisión',
    category: 'Transmisión',
    brandId: 2,
    brandName: 'Toyota',
    modelId: 3,
    modelName: 'Corolla',
    year: 2019,
    description: 'Referencia de demostración para crear una solicitud.',
  ),
  PartSearchResult(
    id: 'demo-faro-ford-ranger-2021',
    partName: 'Faro delantero',
    category: 'Iluminación',
    brandId: 3,
    brandName: 'Ford',
    modelId: 6,
    modelName: 'Ranger',
    year: 2021,
    description: 'Referencia de demostración para crear una solicitud.',
  ),
];
