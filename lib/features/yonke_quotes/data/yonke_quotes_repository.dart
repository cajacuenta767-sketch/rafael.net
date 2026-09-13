import '../../dashboard/data/dashboard_api.dart';
import '../../quotes/data/quotes_api.dart';
import '../domain/yonke_quote.dart';

abstract interface class YonkeQuotesRepository {
  Future<YonkeQuotesPageResult> getMyQuotes({
    required int page,
    required int pageSize,
    String? search,
    YonkeQuoteFilters filters = const YonkeQuoteFilters(),
  });

  Future<YonkeQuote> getById(String quoteId);
}

/// Cotizaciones enviadas por el yonke autenticado, desde
/// `GET /api/DashboardSuscriptores/mis-cotizaciones`. El endpoint no recibe
/// paginación ni filtros, así que búsqueda, filtros y paginación se aplican
/// en la app. Los errores HTTP se propagan para que la pantalla los muestre.
class ApiYonkeQuotesRepository implements YonkeQuotesRepository {
  const ApiYonkeQuotesRepository(this._dashboardApi, this._quotesApi);

  final DashboardApi _dashboardApi;
  final QuotesApi _quotesApi;

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
