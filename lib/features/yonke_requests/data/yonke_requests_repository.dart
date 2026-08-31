import '../domain/yonke_request_summary.dart';

abstract interface class YonkeRequestsRepository {
  bool get usesDemoData;

  Future<YonkeRequestsPageResult> getAssignedRequests({
    required int page,
    required int pageSize,
    String? search,
    YonkeRequestFilters filters = const YonkeRequestFilters(),
  });

  Future<void> markAsViewed(String requestYonkeId);
}

class AssignedRequestsEndpointPendingException implements Exception {
  const AssignedRequestsEndpointPendingException();
}

class UnavailableYonkeRequestsRepository implements YonkeRequestsRepository {
  const UnavailableYonkeRequestsRepository();

  @override
  bool get usesDemoData => false;

  @override
  Future<YonkeRequestsPageResult> getAssignedRequests({
    required int page,
    required int pageSize,
    String? search,
    YonkeRequestFilters filters = const YonkeRequestFilters(),
  }) => throw const AssignedRequestsEndpointPendingException();

  @override
  Future<void> markAsViewed(String requestYonkeId) =>
      throw const AssignedRequestsEndpointPendingException();
}

class DemoYonkeRequestsRepository implements YonkeRequestsRepository {
  const DemoYonkeRequestsRepository();

  @override
  bool get usesDemoData => true;

  @override
  Future<YonkeRequestsPageResult> getAssignedRequests({
    required int page,
    required int pageSize,
    String? search,
    YonkeRequestFilters filters = const YonkeRequestFilters(),
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final query = _normalize(search ?? '');
    final items = demoYonkeRequests.where((item) {
      final searchable = _normalize(
        [
          item.part,
          item.brand,
          item.model,
          item.year,
          item.folio,
          item.city,
        ].whereType<Object>().join(' '),
      );
      final date = item.receivedAt;
      return (query.isEmpty || searchable.contains(query)) &&
          (filters.status == null || item.status == filters.status) &&
          (filters.city == null || item.city == filters.city) &&
          (filters.from == null ||
              !date.isBefore(_startOfDay(filters.from!))) &&
          (filters.to == null || !date.isAfter(_endOfDay(filters.to!)));
    }).toList();
    return YonkeRequestsPageResult(items: items, page: 1, hasMore: false);
  }

  @override
  Future<void> markAsViewed(String requestYonkeId) async {
    if (!requestYonkeId.startsWith('demo-')) {
      throw StateError('El repositorio de prueba solo admite IDs demo.');
    }
  }
}

String _normalize(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[áàä]'), 'a')
    .replaceAll(RegExp(r'[éèë]'), 'e')
    .replaceAll(RegExp(r'[íìï]'), 'i')
    .replaceAll(RegExp(r'[óòö]'), 'o')
    .replaceAll(RegExp(r'[úùü]'), 'u');

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _endOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

final demoYonkeRequests = <YonkeRequestSummary>[
  YonkeRequestSummary(
    requestId: 'demo-request-alternador',
    requestYonkeId: 'demo-assignment-alternador',
    part: 'Alternador',
    status: YonkeRequestStatus.newRequest,
    receivedAt: DateTime(2026, 8, 31, 9, 20),
    isDemo: true,
    brand: 'Nissan',
    model: 'Sentra',
    year: 2018,
    city: 'Nogales, Sonora',
    folio: 'DEMO-001',
    photoCount: 4,
  ),
  YonkeRequestSummary(
    requestId: 'demo-request-faro',
    requestYonkeId: 'demo-assignment-faro',
    part: 'Faro delantero',
    status: YonkeRequestStatus.viewed,
    receivedAt: DateTime(2026, 8, 30, 17, 45),
    isDemo: true,
    brand: 'Toyota',
    model: 'Corolla',
    year: 2016,
    city: 'Hermosillo, Sonora',
    folio: 'DEMO-002',
    photoCount: 2,
  ),
  YonkeRequestSummary(
    requestId: 'demo-request-transmision',
    requestYonkeId: 'demo-assignment-transmision',
    part: 'Transmisión automática',
    status: YonkeRequestStatus.quoted,
    receivedAt: DateTime(2026, 8, 29, 14, 10),
    isDemo: true,
    brand: 'Ford',
    model: 'Ranger',
    year: 2020,
    city: 'Agua Prieta, Sonora',
    folio: 'DEMO-003',
    photoCount: 3,
    hasQuote: true,
  ),
];
