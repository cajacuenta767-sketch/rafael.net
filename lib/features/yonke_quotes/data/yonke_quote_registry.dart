import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/token_store.dart';
import '../../quotes/data/quotes_api.dart';
import '../domain/yonke_quote.dart';

/// Cotizaciones conocidas del yonke de la sesión, guardadas en el teléfono.
///
/// El API no publica una lista de cotizaciones del yonke (solo
/// `MisCotizaciones/Total`, y `mis-cotizaciones` es del rol Cliente). Sin
/// ella el yonke no podía abrir sus conversaciones. Se registran las
/// cotizaciones que envía desde la app (`POST /api/CotizacionYonke` devuelve
/// su guid) y las que llegan en avisos de mensaje nuevo; cada una se consulta
/// con `GET /api/CotizacionYonke/{guid}`, que sí acepta al yonke.
class YonkeQuoteRegistry {
  YonkeQuoteRegistry(this._tokens, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final TokenStore _tokens;
  final FlutterSecureStorage _storage;

  static const _limit = 200;

  /// Guids del más reciente al más antiguo.
  Future<List<String>> ids() async {
    final key = await _key();
    if (key == null) return const [];
    try {
      final raw = await _storage.read(key: key);
      final decoded = raw == null ? null : jsonDecode(raw);
      return decoded is List
          ? decoded.map((id) => id.toString()).toList(growable: false)
          : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(String quoteId) async {
    final id = quoteId.trim();
    final key = await _key();
    if (id.isEmpty || key == null) return;
    try {
      final current = await ids();
      final next = [
        id,
        ...current.where((known) => known.toLowerCase() != id.toLowerCase()),
      ].take(_limit).toList();
      await _storage.write(key: key, value: jsonEncode(next));
    } catch (_) {
      // Sin registro la cotización solo no aparece en la bandeja local.
    }
  }

  Future<String?> _key() async {
    final yonkeId = await _tokens.readYonkeGuidId();
    return yonkeId == null || yonkeId.isEmpty ? null : 'yonke.quotes.$yonkeId';
  }
}

/// Guid de la cotización creada: `ApiResponseGlobal<Guid>` en `data`.
String? createdQuoteId(Object? response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data is String && data.trim().isNotEmpty) return data.trim();
  if (data is Map) {
    final id = data['guidId']?.toString().trim();
    if (id != null && id.isNotEmpty) return id;
  }
  return null;
}

/// Cotizaciones registradas en el teléfono, consultadas en el API. Las que ya
/// no existen o fallan se omiten; `null` si no hay ninguna registrada.
Future<List<YonkeQuote>?> knownYonkeQuotes(
  YonkeQuoteRegistry registry,
  QuotesApi quotesApi, {
  int limit = 30,
}) async {
  final ids = await registry.ids();
  if (ids.isEmpty) return null;
  final quotes = await Future.wait(
    ids.take(limit).map((id) async {
      try {
        return yonkeQuoteFromResponse(await quotesApi.getById(id));
      } catch (_) {
        return null;
      }
    }),
  );
  return quotes.whereType<YonkeQuote>().toList(growable: false);
}
