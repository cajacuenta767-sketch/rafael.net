import '../../../core/storage/token_store.dart';
import '../../auth/domain/current_user.dart';
import '../../quotes/data/quotes_api.dart';
import '../../quotes/domain/quote_message.dart';
import '../domain/client_message.dart';

abstract interface class ClientMessagesRepository {
  Future<List<ClientQuoteMessage>> getConversation(String quoteId);

  Future<void> sendMessage({required String quoteId, required String message});
}

/// Conversación por cotización sobre `SolicitudCotizacionMensajes`.
///
/// Al abrir la conversación se marca como leída con
/// `PUT /api/SolicitudCotizacionMensajes/{id}/leer`; si esa llamada falla no
/// impide mostrar los mensajes.
class ApiClientMessagesRepository implements ClientMessagesRepository {
  const ApiClientMessagesRepository(this._quotesApi, this._tokenStore);

  final QuotesApi _quotesApi;
  final TokenStore _tokenStore;

  @override
  Future<List<ClientQuoteMessage>> getConversation(String quoteId) async {
    final response = await _quotesApi.getConversation(quoteId);
    final viewerUserId = await currentUserIdFrom(_tokenStore);
    final messages = quoteMessagesFromResponse(response)
        .map(
          (record) => ClientQuoteMessage(
            id: record.id,
            text: record.text,
            sentAt: record.sentAt,
            fromClient: record.isFromClient(
              viewerUserId: viewerUserId,
              viewerIsClient: true,
            ),
            read: record.read,
          ),
        )
        .toList(growable: false);
    try {
      await _quotesApi.markMessagesRead(quoteId);
    } catch (_) {
      // La lectura ya se mostró; el marcado se reintenta en la próxima visita.
    }
    return messages;
  }

  @override
  Future<void> sendMessage({
    required String quoteId,
    required String message,
  }) => _quotesApi.sendMessage(quoteId: quoteId, message: message);
}
