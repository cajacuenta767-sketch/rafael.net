import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/domain/current_user.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../quotes/data/quotes_api.dart';
import '../../quotes/domain/quote_message.dart';
import '../../yonke_quotes/domain/yonke_quote.dart';
import '../domain/yonke_message.dart';

abstract interface class YonkeMessagesRepository {
  Future<List<YonkeMessagePreview>> getInbox();

  Future<List<YonkeQuoteMessage>> getConversation(String quoteId);

  Future<void> sendMessage({required String quoteId, required String message});
}

/// La API no publica una bandeja global de mensajes: se construye a partir
/// de las cotizaciones del yonke (`DashboardSuscriptores/mis-cotizaciones`)
/// y la conversación de cada una (`SolicitudCotizacionMensajes/{id}`).
class ApiYonkeMessagesRepository implements YonkeMessagesRepository {
  const ApiYonkeMessagesRepository(
    this._quotesApi,
    this._dashboardApi,
    this._tokenStore,
  );

  final QuotesApi _quotesApi;
  final DashboardApi _dashboardApi;
  final TokenStore _tokenStore;

  /// Conversaciones consultadas por carga de bandeja, de la más reciente a
  /// la más antigua, para no disparar una llamada por cada cotización vieja.
  static const inboxLimit = 20;

  @override
  Future<List<YonkeMessagePreview>> getInbox() async {
    // `mis-cotizaciones` es del rol Cliente en el API publicado; si lo
    // rechaza para el yonke, la bandeja queda como contrato pendiente.
    final dynamic response;
    try {
      response = await _dashboardApi.getMyQuotes();
    } on ApiException catch (error) {
      if (error.statusCode == 403 || error.statusCode == 404) {
        throw const YonkeMessagesInboxContractPendingException();
      }
      rethrow;
    }
    final page = yonkeQuotesPageFromResponse(response);
    if (page == null) throw const YonkeMessagesInboxContractPendingException();
    final quotes = [...page.items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final viewerUserId = await currentUserIdFrom(_tokenStore);

    final previews = await Future.wait(
      quotes.take(inboxLimit).map((quote) async {
        List<QuoteMessageRecord> messages;
        try {
          messages = quoteMessagesFromResponse(
            await _quotesApi.getConversation(quote.id),
          );
        } catch (_) {
          messages = const [];
        }
        final last = messages.isEmpty ? null : messages.last;
        final unread = messages
            .where(
              (message) =>
                  !message.read &&
                  message.isFromClient(
                    viewerUserId: viewerUserId,
                    viewerIsClient: false,
                  ),
            )
            .length;
        return YonkeMessagePreview(
          quote: quote,
          clientLabel: quote.folio == null
              ? 'Cliente'
              : 'Cliente · ${quote.folio}',
          lastMessage: last?.text ?? 'Sin mensajes todavía',
          lastMessageAt: last?.sentAt ?? quote.createdAt,
          unreadCount: unread,
        );
      }),
    );
    previews.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return previews;
  }

  @override
  Future<List<YonkeQuoteMessage>> getConversation(String quoteId) async {
    final response = await _quotesApi.getConversation(quoteId);
    final viewerUserId = await currentUserIdFrom(_tokenStore);
    final messages = quoteMessagesFromResponse(response)
        .map(
          (record) => YonkeQuoteMessage(
            id: record.id,
            text: record.text,
            sentAt: record.sentAt,
            fromClient: record.isFromClient(
              viewerUserId: viewerUserId,
              viewerIsClient: false,
            ),
            read: record.read,
          ),
        )
        .toList(growable: false);
    try {
      await _quotesApi.markMessagesRead(quoteId);
    } catch (_) {
      // El marcado de lectura no bloquea la conversación.
    }
    return messages;
  }

  @override
  Future<void> sendMessage({
    required String quoteId,
    required String message,
  }) => _quotesApi.sendMessage(quoteId: quoteId, message: message);
}

class YonkeMessagesInboxContractPendingException implements Exception {
  const YonkeMessagesInboxContractPendingException();
}
