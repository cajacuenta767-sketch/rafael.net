import '../../../core/network/api_client.dart';
import '../../../core/session/session_events.dart';
import '../../../core/network/api_endpoints.dart';
import '../../quotes/data/quotes_api.dart';
import '../domain/quote_client.dart';

/// Obtiene el cliente de una cotización para el yonke.
///
/// Se comparte entre pantallas: la misma cotización no se pide dos veces en
/// la sesión. Nunca falla; sin respuesta del API se devuelve `null`.
class QuoteClientResolver {
  QuoteClientResolver(this._quotesApi, [this._apiClient]);

  final QuotesApi _quotesApi;
  final ApiClient? _apiClient;

  final _clients = <String, Future<QuoteClient?>>{};
  int _sessionRevision = SessionEvents.revision;

  Future<QuoteClient?> resolve(String quoteId) async {
    if (_sessionRevision != SessionEvents.revision) {
      _clients.clear();
      _sessionRevision = SessionEvents.revision;
    }
    if (quoteId.isEmpty) return null;
    final revision = _sessionRevision;
    final client = await (_clients[quoteId] ??= _load(quoteId));
    if (revision != SessionEvents.revision) return null;
    // Sin datos todavía: se vuelve a preguntar en la siguiente carga, por si
    // el servidor ya los entrega.
    if (client == null) _clients.remove(quoteId);
    return client;
  }

  Future<QuoteClient?> _load(String quoteId) async {
    try {
      final response = await _quotesApi.getById(quoteId);
      var client = quoteClientFromResponse(response);
      if ((client == null || client.name == null) && _apiClient != null) {
        final clientId = extractClientIdFromQuoteResponse(response);
        if (clientId != null && clientId.isNotEmpty) {
          try {
            final profileResp = await _apiClient.get(
              ApiEndpoints.clientProfile(clientId),
            );
            final profileData = profileResp is Map
                ? profileResp['data'] ?? profileResp
                : null;
            if (profileData is Map) {
              final name = profileData['nombre']?.toString().trim();
              final phone = profileData['telefono']?.toString().trim();
              final photo = profileData['fotoPerfil']?.toString().trim();
              final resolvedName =
                  (name != null &&
                      name.isNotEmpty &&
                      name.toLowerCase() != 'cliente refanet')
                  ? name
                  : client?.name;
              final resolvedPhone = (phone != null && phone.isNotEmpty)
                  ? phone
                  : client?.phone;
              final resolvedPhoto = (photo != null && photo.isNotEmpty)
                  ? photo
                  : client?.photoUrl;
              client = QuoteClient(
                name: resolvedName,
                phone: resolvedPhone,
                photoUrl: resolvedPhoto,
              );
            }
          } catch (_) {}
        }
      }
      return client;
    } catch (_) {
      return null;
    }
  }
}
