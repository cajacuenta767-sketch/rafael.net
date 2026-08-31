import '../../dashboard/data/dashboard_api.dart';
import '../../quotes/data/quotes_api.dart';
import '../domain/yonke_quote.dart';

abstract interface class YonkeQuotesRepository {
  bool get usesDemoData;

  Future<YonkeQuotesPageResult> getMyQuotes({
    required int page,
    required int pageSize,
    String? search,
    YonkeQuoteFilters filters = const YonkeQuoteFilters(),
  });

  Future<YonkeQuote> getById(String quoteId);
}

class ApiYonkeQuotesRepository implements YonkeQuotesRepository {
  const ApiYonkeQuotesRepository(this._dashboardApi, this._quotesApi);

  final DashboardApi _dashboardApi;
  final QuotesApi _quotesApi;

  @override
  bool get usesDemoData => false;

  @override
  Future<YonkeQuotesPageResult> getMyQuotes({
    required int page,
    required int pageSize,
    String? search,
    YonkeQuoteFilters filters = const YonkeQuoteFilters(),
  }) async {
    final response = await _dashboardApi.getMyQuotes();
    final parsed = yonkeQuotesPageFromResponse(response);
    if (parsed == null) throw const YonkeQuotesContractPendingException();
    return _filterAndPage(
      parsed.items,
      page: page,
      pageSize: pageSize,
      search: search,
      filters: filters,
    );
  }

  @override
  Future<YonkeQuote> getById(String quoteId) async {
    final response = await _quotesApi.getById(quoteId);
    final quote = yonkeQuoteFromResponse(response);
    if (quote == null) throw const YonkeQuoteNotFoundException();
    return quote;
  }
}

class DemoYonkeQuotesRepository implements YonkeQuotesRepository {
  const DemoYonkeQuotesRepository();

  @override
  bool get usesDemoData => true;

  @override
  Future<YonkeQuotesPageResult> getMyQuotes({
    required int page,
    required int pageSize,
    String? search,
    YonkeQuoteFilters filters = const YonkeQuoteFilters(),
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return _filterAndPage(
      demoYonkeQuotes,
      page: page,
      pageSize: pageSize,
      search: search,
      filters: filters,
    );
  }

  @override
  Future<YonkeQuote> getById(String quoteId) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    for (final quote in demoYonkeQuotes) {
      if (quote.id == quoteId) return quote;
    }
    throw const YonkeQuoteNotFoundException();
  }
}

class YonkeQuotesContractPendingException implements Exception {
  const YonkeQuotesContractPendingException();
}

class YonkeQuoteNotFoundException implements Exception {
  const YonkeQuoteNotFoundException();
}

YonkeQuotesPageResult _filterAndPage(
  List<YonkeQuote> source, {
  required int page,
  required int pageSize,
  required String? search,
  required YonkeQuoteFilters filters,
}) {
  final query = _normalize(search ?? '');
  final filtered = source.where((quote) {
    final searchable = _normalize(
      [
        quote.part,
        quote.brand,
        quote.model,
        quote.year,
        quote.folio,
        quote.partNumber,
      ].whereType<Object>().join(' '),
    );
    return (query.isEmpty || searchable.contains(query)) &&
        (filters.status == null || quote.status == filters.status) &&
        (filters.onlyAvailable == null ||
            quote.available == filters.onlyAvailable) &&
        (filters.from == null ||
            !quote.createdAt.isBefore(_startOfDay(filters.from!))) &&
        (filters.to == null ||
            !quote.createdAt.isAfter(_endOfDay(filters.to!)));
  }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final safePage = page < 1 ? 1 : page;
  final start = (safePage - 1) * pageSize;
  if (start >= filtered.length) {
    return YonkeQuotesPageResult(
      items: const [],
      page: safePage,
      hasMore: false,
    );
  }
  final end = (start + pageSize).clamp(0, filtered.length);
  return YonkeQuotesPageResult(
    items: filtered.sublist(start, end),
    page: safePage,
    hasMore: end < filtered.length,
  );
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

final demoYonkeQuotes = <YonkeQuote>[
  YonkeQuote(
    id: 'demo-quote-alternador',
    requestYonkeId: 'demo-assignment-alternador',
    requestId: 'demo-request-alternador',
    part: 'Alternador',
    price: 1850,
    available: true,
    isNew: false,
    hasWarranty: true,
    warrantyDays: 30,
    shippingAvailable: true,
    shippingCost: 120,
    active: true,
    status: YonkeQuoteStatus.viewed,
    createdAt: DateTime(2026, 8, 31, 11, 25),
    imageUrls: const ['demo://alternador'],
    isDemo: true,
    brand: 'Nissan',
    model: 'Sentra',
    year: 2018,
    folio: 'DEMO-001',
    partNumber: '23100-3SH1A',
    comments: 'Pieza original usada, probada y en buen estado.',
    deliveryDays: 2,
  ),
  YonkeQuote(
    id: 'demo-quote-faro',
    requestYonkeId: 'demo-assignment-faro',
    requestId: 'demo-request-faro',
    part: 'Faro delantero',
    price: 950,
    available: true,
    isNew: false,
    hasWarranty: true,
    warrantyDays: 15,
    shippingAvailable: false,
    active: true,
    status: YonkeQuoteStatus.sent,
    createdAt: DateTime(2026, 8, 30, 18, 10),
    imageUrls: const [],
    isDemo: true,
    brand: 'Toyota',
    model: 'Corolla',
    year: 2016,
    folio: 'DEMO-002',
    comments: 'Faro usado completo, sin roturas.',
  ),
  YonkeQuote(
    id: 'demo-quote-transmision',
    requestYonkeId: 'demo-assignment-transmision',
    requestId: 'demo-request-transmision',
    part: 'Transmisión automática',
    price: 14500,
    available: true,
    isNew: false,
    hasWarranty: true,
    warrantyDays: 60,
    shippingAvailable: true,
    shippingCost: 850,
    active: true,
    status: YonkeQuoteStatus.accepted,
    createdAt: DateTime(2026, 8, 29, 15, 45),
    imageUrls: const ['demo://transmision'],
    isDemo: true,
    brand: 'Ford',
    model: 'Ranger',
    year: 2020,
    folio: 'DEMO-003',
    comments: 'Transmisión probada con garantía.',
    deliveryDays: 3,
  ),
];
