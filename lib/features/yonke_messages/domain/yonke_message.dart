import '../../yonke_quotes/domain/yonke_quote.dart';
import 'quote_client.dart';

class YonkeMessagePreview {
  const YonkeMessagePreview({
    required this.quote,
    required this.clientLabel,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    this.client,
  });

  final YonkeQuote quote;
  final String clientLabel;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final QuoteClient? client;
}

class YonkeQuoteMessage {
  const YonkeQuoteMessage({
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
