import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/token_store.dart';
import '../../auth/domain/session_payload.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../quotes/data/quotes_api.dart';
import '../domain/yonke_quote.dart';
import 'yonke_quote_registry.dart';

abstract interface class YonkeQuotesRepository {
  Future<YonkeQuotesPageResult> getMyQuotes({
    required int page,
    required int pageSize,
    String? search,
    YonkeQuoteFilters filters = const YonkeQuoteFilters(),
  });

  Future<YonkeQuote> getById(String quoteId);
}

class ApiYonkeQuotesRepository implements YonkeQuotesRepository {
  const ApiYonkeQuotesRepository(
    this._dashboardApi,
    this._quotesApi, [
    this._registry,
    this._storage = const FlutterSecureStorage(),
    this._tokens,
  ]);

  final DashboardApi _dashboardApi;
  final QuotesApi _quotesApi;
  final YonkeQuoteRegistry? _registry;
  final FlutterSecureStorage? _storage;
  final TokenStore? _tokens;

  Future<String> _resolveQuotesKey() async {
    final storage = _storage ?? const FlutterSecureStorage();
    String? email = await storage.read(key: 'yonke.active_email');
    if (email == null || email.trim().isEmpty) {
      final token = await _tokens?.readAccessToken() ??
          await storage.read(key: 'auth.access_token');
      if (token != null && token.isNotEmpty) {
        final claims = SessionResponseParser.decodeJwtClaims(token);
        email = claims?['email']?.toString() ??
            claims?['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress']
                ?.toString();
      }
    }
    if (email != null && email.trim().isNotEmpty) {
      return 'yonke.quotes.email.${email.trim().toLowerCase()}';
    }
    final yonkeId = await _tokens?.readYonkeGuidId();
    if (yonkeId != null && yonkeId.trim().isNotEmpty) {
      return 'yonke.quotes.cache.$yonkeId';
    }
    return 'yonke.quotes.history';
  }

  Future<List<YonkeQuote>> _loadCached() async {
    final storage = _storage ?? const FlutterSecureStorage();
    try {
      final key = await _resolveQuotesKey();
      var raw = await storage.read(key: key);
      if ((raw == null || raw.isEmpty) && key != 'yonke.quotes.history') {
        raw = await storage.read(key: 'yonke.quotes.history');
      }
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => YonkeQuote.fromStoredJson(Map<String, dynamic>.from(m)))
          .where((q) => q.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveCached(List<YonkeQuote> items) async {
    final storage = _storage ?? const FlutterSecureStorage();
    try {
      final key = await _resolveQuotesKey();
      await storage.write(
        key: key,
        value: jsonEncode(items.map((i) => i.toJson()).toList()),
      );
    } catch (_) {}
  }

  @override
  Future<YonkeQuotesPageResult> getMyQuotes({
    required int page,
    required int pageSize,
    String? search,
    YonkeQuoteFilters filters = const YonkeQuoteFilters(),
  }) async {
    final safePage = page < 1 ? 1 : page;
    final cleanSearch = search?.trim().isEmpty == true ? null : search?.trim();
    final cached = await _loadCached();
    List<YonkeQuote>? serverItems;

    try {
      final serverPage = yonkeQuotesPageFromResponse(
        await _quotesApi.getYonkeQuotes(
          page: safePage,
          pageSize: pageSize.clamp(1, 50),
          search: cleanSearch,
        ),
      );
      if (serverPage != null && serverPage.items.isNotEmpty) {
        serverItems = serverPage.items;
      }
    } catch (_) {
      // Si el endpoint de cotizaciones falla o no devuelve datos, consultar fallback
    }

    if (serverItems == null) {
      try {
        serverItems = yonkeQuotesPageFromResponse(await _dashboardApi.getMyQuotes())
            ?.items;
      } catch (_) {
        serverItems = null;
      }
    }

    final registry = _registry;
    if (serverItems == null && registry != null) {
      try {
        serverItems = await knownYonkeQuotes(registry, _quotesApi);
      } catch (_) {
        serverItems = const [];
      }
    }

    // Fusión con el historial guardado en el teléfono por cuenta
    final map = <String, YonkeQuote>{};
    for (final q in cached) {
      map[q.id] = q;
    }
    if (serverItems != null) {
      for (final q in serverItems) {
        map[q.id] = q;
      }
    }

    final allItems = map.values.toList();
    if (allItems.isNotEmpty) {
      await _saveCached(allItems);
    }

    final listToReturn = allItems.isNotEmpty ? allItems : (serverItems ?? const []);

    return _filterAndPage(
      listToReturn,
      page: page,
      pageSize: pageSize,
      search: search,
      filters: filters,
    );
  }

  @override
  Future<YonkeQuote> getById(String quoteId) async {
    try {
      final response = await _quotesApi.getById(quoteId);
      final quote = yonkeQuoteFromResponse(response);
      if (quote != null) {
        final cached = await _loadCached();
        final map = <String, YonkeQuote>{for (final q in cached) q.id: q};
        map[quote.id] = quote;
        await _saveCached(map.values.toList());
        return quote;
      }
    } catch (_) {}

    final cached = await _loadCached();
    for (final q in cached) {
      if (q.id.toLowerCase() == quoteId.toLowerCase()) return q;
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
