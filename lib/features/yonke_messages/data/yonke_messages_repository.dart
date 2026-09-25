import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/domain/current_user.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../quotes/data/quotes_api.dart';
import '../../quotes/domain/quote_message.dart';
import '../../yonke_quotes/data/yonke_quote_registry.dart';
import '../../yonke_quotes/domain/yonke_quote.dart';
import '../domain/quote_client.dart';
import '../domain/yonke_message.dart';
import 'quote_client_resolver.dart';

abstract interface class YonkeMessagesRepository {
  Future<List<YonkeMessagePreview>> getInbox();

  Future<List<YonkeQuoteMessage>> getConversation(String quoteId);

  /// Nombre, teléfono y foto del cliente de la cotización, si el API los
  /// entrega.
  Future<QuoteClient?> getClient(String quoteId);

  Future<void> sendMessage({required String quoteId, required String message});
}

/// La API no publica una bandeja global de mensajes: se construye a partir
/// de las cotizaciones del yonke (`DashboardSuscriptores/mis-cotizaciones`)
/// y la conversación de cada una (`SolicitudCotizacionMensajes/{id}`).
class ApiYonkeMessagesRepository implements YonkeMessagesRepository {
  const ApiYonkeMessagesRepository(
    this._quotesApi,
    this._dashboardApi,
    this._tokenStore, [
    this._registry,
    this._clients,
  ]);

  final QuotesApi _quotesApi;
  final DashboardApi _dashboardApi;
  final TokenStore _tokenStore;
  final YonkeQuoteRegistry? _registry;
  final QuoteClientResolver? _clients;

  /// Conversaciones consultadas por carga de bandeja, de la más reciente a
  /// la más antigua, para no disparar una llamada por cada cotización vieja.
  static const inboxLimit = 20;

  @override
  Future<List<YonkeMessagePreview>> getInbox() async {
    // `mis-cotizaciones` es del rol Cliente en el API publicado. Si lo
    // rechaza, la bandeja se arma con las cotizaciones registradas en el
    // teléfono (enviadas desde la app o recibidas en avisos de mensaje).
    List<YonkeQuote>? known;
    try {
      known = yonkeQuotesPageFromResponse(await _dashboardApi.getMyQuotes())
          ?.items;
    } on ApiException catch (error) {
      if (error.statusCode != 403 && error.statusCode != 404) rethrow;
    }
    final registry = _registry;
    if (known == null && registry != null) {
      known = await knownYonkeQuotes(registry, _quotesApi);
    }
    if (known == null) throw const YonkeMessagesInboxContractPendingException();
    final quotes = [...known]
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
        final known =
            _latestContact(messages, viewerUserId) ?? await getClient(quote.id);
        final name = known?.name ?? 'Cliente';
        return YonkeMessagePreview(
          quote: quote,
          client: known,
          clientLabel: quote.folio == null ? name : '$name · ${quote.folio}',
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
            contact: _clientContact(record, viewerUserId),
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
  Future<QuoteClient?> getClient(String quoteId) async =>
      await _clients?.resolve(quoteId);

  @override
  Future<void> sendMessage({
    required String quoteId,
    required String message,
  }) => _quotesApi.sendMessage(quoteId: quoteId, message: message);
}

/// Contacto de un mensaje, solo si lo escribió el cliente.
QuoteClient? _clientContact(QuoteMessageRecord record, String? viewerUserId) =>
    record.isFromClient(viewerUserId: viewerUserId, viewerIsClient: false)
    ? record.contact
    : null;

QuoteClient? _latestContact(
  List<QuoteMessageRecord> messages,
  String? viewerUserId,
) => messages.reversed
    .map((record) => _clientContact(record, viewerUserId))
    .firstWhere((contact) => contact != null, orElse: () => null);

class YonkeMessagesInboxContractPendingException implements Exception {
  const YonkeMessagesInboxContractPendingException();
}
