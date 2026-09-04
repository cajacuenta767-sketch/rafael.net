import '../../yonke_quotes/domain/yonke_quote.dart';

class YonkeMessagePreview {
  const YonkeMessagePreview({
    required this.quote,
    required this.clientLabel,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final YonkeQuote quote;
  final String clientLabel;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
}

class YonkeQuoteMessage {
  const YonkeQuoteMessage({
    required this.id,
    required this.text,
    required this.sentAt,
    required this.fromClient,
    this.localOnly = false,
  });

  final String id;
  final String text;
  final DateTime sentAt;
  final bool fromClient;

  /// Indica un mensaje enviado por la app que aún no puede reconciliarse con
  /// el historial hasta que el backend documente su respuesta.
  final bool localOnly;
}

class YonkeConversationResult {
  const YonkeConversationResult({
    required this.messages,
    required this.historyContractPending,
  });

  final List<YonkeQuoteMessage> messages;
  final bool historyContractPending;
}
