import 'package:flutter/foundation.dart';

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

abstract interface class DevelopmentMessagesStatus {
  bool get usingDevelopmentFallback;
}

/// Conversación por cotización sobre `SolicitudCotizacionMensajes`.
///
/// Al abrir la conversación se marca como leída con
/// `PUT /api/SolicitudCotizacionMensajes/{id}/leer`; si esa llamada falla no
/// impide mostrar los mensajes.
class ApiClientMessagesRepository
    implements ClientMessagesRepository, DevelopmentMessagesStatus {
  ApiClientMessagesRepository(
    this._quotesApi,
    this._dashboardApi,
    this._tokenStore,
  );

  final QuotesApi _quotesApi;
  final DashboardApi _dashboardApi;
  final TokenStore _tokenStore;

  static const inboxLimit = 20;
  static const _developmentToken = 'development-client-session';
  final Map<String, List<ClientQuoteMessage>> _developmentMessages = {};
  bool _developmentChatUnavailable = false;

  @override
  bool get usingDevelopmentFallback =>
      kDebugMode && _developmentChatUnavailable;

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
          if (await _isDevelopmentSession()) {
            _developmentChatUnavailable = true;
            final messages = _developmentConversation(quote.id);
            final last = messages.last;
            return ClientMessagePreview(
              quote: quote,
              lastMessage: last.text,
              lastMessageAt: last.sentAt,
              unreadCount: messages.where((message) => !message.read).length,
              historyAvailable: true,
            );
          }
          return ClientMessagePreview(
            quote: quote,
            lastMessage: 'Historial no disponible',
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
    if (_developmentChatUnavailable && await _isDevelopmentSession()) {
      return _developmentConversation(quoteId);
    }
    try {
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
    } catch (_) {
      if (!await _isDevelopmentSession()) rethrow;
      _developmentChatUnavailable = true;
      return _developmentConversation(quoteId);
    }
  }

  @override
  Future<void> sendMessage({
    required String quoteId,
    required String message,
  }) async {
    if (_developmentChatUnavailable && await _isDevelopmentSession()) {
      _developmentConversation(quoteId).add(
        ClientQuoteMessage(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          text: message,
          sentAt: DateTime.now(),
          fromClient: true,
          read: false,
        ),
      );
      return;
    }
    await _quotesApi.sendMessage(quoteId: quoteId, message: message);
  }

  Future<bool> _isDevelopmentSession() async =>
      kDebugMode && await _tokenStore.readAccessToken() == _developmentToken;

  List<ClientQuoteMessage> _developmentConversation(String quoteId) =>
      _developmentMessages.putIfAbsent(quoteId, () {
        final now = DateTime.now();
        return [
          ClientQuoteMessage(
            id: 'demo-$quoteId-1',
            text: 'Buen día, tenemos disponible la pieza que buscas.',
            sentAt: now.subtract(const Duration(minutes: 5)),
            fromClient: false,
            read: true,
          ),
          ClientQuoteMessage(
            id: 'demo-$quoteId-2',
            text: '¿Me puedes compartir más información?',
            sentAt: now.subtract(const Duration(minutes: 3)),
            fromClient: true,
            read: true,
          ),
          ClientQuoteMessage(
            id: 'demo-$quoteId-3',
            text: 'Claro, la pieza está disponible para cotizar.',
            sentAt: now.subtract(const Duration(minutes: 1)),
            fromClient: false,
            read: false,
          ),
        ];
      });
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
