import '../../quotes/domain/client_quote.dart';

class ClientMessagePreview {
  const ClientMessagePreview({
    required this.quote,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.historyAvailable,
  });

  final ClientQuote quote;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool historyAvailable;
}

class ClientQuoteMessage {
  const ClientQuoteMessage({
    required this.id,
    required this.text,
    required this.sentAt,
    required this.fromClient,
    this.read = true,
  });

  final String id;
  final String text;
  final DateTime sentAt;
  final bool fromClient;
  final bool read;
}
