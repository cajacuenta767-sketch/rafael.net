class PartSearchFilters {
  const PartSearchFilters({
    this.category,
    this.brandId,
    this.brandName,
    this.modelId,
    this.modelName,
    this.year,
  });

  final String? category;
  final int? brandId;
  final String? brandName;
  final int? modelId;
  final String? modelName;
  final int? year;

  int get activeCount =>
      [category, brandId, modelId, year].where((value) => value != null).length;

  bool get isEmpty => activeCount == 0;

  PartSearchFilters copyWith({
    String? category,
    int? brandId,
    String? brandName,
    int? modelId,
    String? modelName,
    int? year,
    bool clearCategory = false,
    bool clearBrand = false,
    bool clearModel = false,
    bool clearYear = false,
  }) => PartSearchFilters(
    category: clearCategory ? null : category ?? this.category,
    brandId: clearBrand ? null : brandId ?? this.brandId,
    brandName: clearBrand ? null : brandName ?? this.brandName,
    modelId: clearBrand || clearModel ? null : modelId ?? this.modelId,
    modelName: clearBrand || clearModel ? null : modelName ?? this.modelName,
    year: clearYear ? null : year ?? this.year,
  );
}

class PartSearchResult {
  const PartSearchResult({
    required this.id,
    required this.partName,
    required this.category,
    this.brandId,
    this.brandName,
    this.modelId,
    this.modelName,
    this.year,
    this.description,
  });

  final String id;
  final String partName;
  final String category;
  final int? brandId;
  final String? brandName;
  final int? modelId;
  final String? modelName;
  final int? year;
  final String? description;
}

class SearchHistoryEntry {
  const SearchHistoryEntry({required this.query, required this.filters});

  final String query;
  final PartSearchFilters filters;

  String get identity => [
    query.trim().toLowerCase(),
    filters.category ?? '',
    filters.brandId ?? '',
    filters.modelId ?? '',
    filters.year ?? '',
  ].join('|');

  Map<String, dynamic> toJson() => {
    'query': query,
    'category': filters.category,
    'brandId': filters.brandId,
    'brandName': filters.brandName,
    'modelId': filters.modelId,
    'modelName': filters.modelName,
    'year': filters.year,
  };

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) =>
      SearchHistoryEntry(
        query: json['query']?.toString() ?? '',
        filters: PartSearchFilters(
          category: json['category']?.toString(),
          brandId: (json['brandId'] as num?)?.toInt(),
          brandName: json['brandName']?.toString(),
          modelId: (json['modelId'] as num?)?.toInt(),
          modelName: json['modelName']?.toString(),
          year: (json['year'] as num?)?.toInt(),
        ),
      );
}
