class CoverageCity {
  const CoverageCity({
    required this.id,
    required this.name,
    required this.state,
  });

  final int id;
  final String name;
  final String state;
}

class YonkeCoverageSnapshot {
  const YonkeCoverageSnapshot({
    required this.cities,
    required this.selectedCityIds,
  });

  final List<CoverageCity> cities;
  final Set<int> selectedCityIds;
}

class YonkeIdentityContractPendingException implements Exception {
  const YonkeIdentityContractPendingException();
}
