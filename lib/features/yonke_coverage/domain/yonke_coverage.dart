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
    required this.isDemo,
  });

  final List<CoverageCity> cities;
  final Set<int> selectedCityIds;
  final bool isDemo;
}

class YonkeIdentityContractPendingException implements Exception {
  const YonkeIdentityContractPendingException();
}
