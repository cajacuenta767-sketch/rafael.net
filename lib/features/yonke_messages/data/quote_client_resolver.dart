import '../../quotes/data/quotes_api.dart';
import '../domain/quote_client.dart';

/// Obtiene el cliente de una cotización para el yonke.
///
/// Se comparte entre pantallas: la misma cotización no se pide dos veces en
/// la sesión. Nunca falla; sin respuesta del API se devuelve `null`.
class QuoteClientResolver {
  QuoteClientResolver(this._quotesApi);

  final QuotesApi _quotesApi;

  static final _clients = <String, Future<QuoteClient?>>{};

  Future<QuoteClient?> resolve(String quoteId) async {
    if (quoteId.isEmpty) return null;
    final client = await (_clients[quoteId] ??= _load(quoteId));
    // Sin datos todavía: se vuelve a preguntar en la siguiente carga, por si
    // el servidor ya los entrega.
    if (client == null) _clients.remove(quoteId);
    return client;
  }

  Future<QuoteClient?> _load(String quoteId) async {
    try {
      return quoteClientFromResponse(await _quotesApi.getById(quoteId));
    } catch (_) {
      return null;
    }
  }
}
