import '../../../core/storage/token_store.dart';
import '../../auth/domain/current_user.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../quotes/data/quotes_api.dart';
import '../../quotes/domain/client_quote.dart';
import '../../quotes/domain/quote_message.dart';
import '../domain/client_message.dart';

abstract interface class ClientMessagesRepository {
  Future<List<ClientMessagePreview>> getInbox();

  Future<List<ClientQuoteMessage>> getConversation(String quoteId);

  Future<void> sendMessage({required String quoteId, required String message});
}

/// Conversación por cotización sobre `SolicitudCotizacionMensajes`.
///
/// La bandeja se arma con `DashboardSuscriptores/mis-cotizaciones` y el
/// historial de cada cotización. Al abrir la conversación se marca como leída
/// con `PUT /api/SolicitudCotizacionMensajes/{id}/leer`; si esa llamada falla
/// no impide mostrar los mensajes.
class ApiClientMessagesRepository implements ClientMessagesRepository {
  const ApiClientMessagesRepository(
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
  Future<List<ClientMessagePreview>> getInbox() async {
    final quotes = clientQuotesFromDashboard(await _dashboardApi.getMyQuotes());
    final ordered = [...quotes]
      ..sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
    final viewerUserId = await currentUserIdFrom(_tokenStore);

    final previews = await Future.wait(
      ordered.take(inboxLimit).map((quote) async {
        try {
          final messages = quoteMessagesFromResponse(
            await _quotesApi.getConversation(quote.id),
          );
          final last = messages.isEmpty ? null : messages.last;
          var unread = messages
              .where(
                (message) =>
                    !message.read &&
                    !message.isFromClient(
                      viewerUserId: viewerUserId,
                      viewerIsClient: true,
                    ),
              )
              .length;
          try {
            unread =
                _unreadCount(await _quotesApi.getUnreadCount(quote.id)) ??
                unread;
          } catch (_) {
            // El historial permite conservar un contador aproximado.
          }
          return ClientMessagePreview(
            quote: quote,
            lastMessage: last?.text ?? 'Sin mensajes todavía',
            lastMessageAt:
                last?.sentAt ??
                quote.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0),
            unreadCount: unread,
            historyAvailable: true,
          );
        } catch (_) {
          return ClientMessagePreview(
            quote: quote,
            lastMessage: 'Sin mensajes todavía',
            lastMessageAt:
                quote.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            unreadCount: 0,
            historyAvailable: false,
          );
        }
      }),
    );
    previews.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return previews;
  }

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

int? _unreadCount(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data is num) return data.toInt();
  if (data is Map) {
    for (final key in const ['cantidad', 'count', 'noLeidos', 'total']) {
      final value = data[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
  }
  return int.tryParse(data?.toString() ?? '');
}
