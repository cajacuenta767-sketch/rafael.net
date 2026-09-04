import '../../quotes/data/quotes_api.dart';
import '../../yonke_quotes/data/yonke_quotes_repository.dart';
import '../domain/yonke_message.dart';

abstract interface class YonkeMessagesRepository {
  bool get usesDemoData;

  Future<List<YonkeMessagePreview>> getInbox();

  Future<YonkeConversationResult> getConversation(String quoteId);

  Future<void> sendMessage({required String quoteId, required String message});
}

/// La API expone conversaciones por cotización, pero no una bandeja global ni
/// el esquema de sus respuestas. Se conserva la operación de envío confirmada
/// y se evita convertir JSON desconocido en mensajes que podrían ser erróneos.
class ApiYonkeMessagesRepository implements YonkeMessagesRepository {
  const ApiYonkeMessagesRepository(this._quotesApi);

  final QuotesApi _quotesApi;

  @override
  bool get usesDemoData => false;

  @override
  Future<List<YonkeMessagePreview>> getInbox() async =>
      throw const YonkeMessagesInboxContractPendingException();

  @override
  Future<YonkeConversationResult> getConversation(String quoteId) async {
    await _quotesApi.getConversation(quoteId);
    return const YonkeConversationResult(
      messages: [],
      historyContractPending: true,
    );
  }

  @override
  Future<void> sendMessage({
    required String quoteId,
    required String message,
  }) => _quotesApi.sendMessage(quoteId: quoteId, message: message);
}

class DemoYonkeMessagesRepository implements YonkeMessagesRepository {
  const DemoYonkeMessagesRepository();

  @override
  bool get usesDemoData => true;

  @override
  Future<List<YonkeMessagePreview>> getInbox() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _demoPreviews;
  }

  @override
  Future<YonkeConversationResult> getConversation(String quoteId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return YonkeConversationResult(
      messages: _demoMessages[quoteId] ?? const [],
      historyContractPending: false,
    );
  }

  @override
  Future<void> sendMessage({
    required String quoteId,
    required String message,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}

class YonkeMessagesInboxContractPendingException implements Exception {
  const YonkeMessagesInboxContractPendingException();
}

final _demoPreviews = <YonkeMessagePreview>[
  YonkeMessagePreview(
    quote: demoYonkeQuotes[0],
    clientLabel: 'Cliente de prueba',
    lastMessage: '¿La pieza incluye garantía?',
    lastMessageAt: DateTime(2026, 8, 31, 12, 10),
    unreadCount: 1,
  ),
  YonkeMessagePreview(
    quote: demoYonkeQuotes[2],
    clientLabel: 'Cliente de prueba',
    lastMessage: 'Perfecto, revisaré tu propuesta.',
    lastMessageAt: DateTime(2026, 8, 30, 17, 20),
    unreadCount: 0,
  ),
];

final _demoMessages = <String, List<YonkeQuoteMessage>>{
  'demo-quote-alternador': [
    YonkeQuoteMessage(
      id: 'demo-message-1',
      text: 'Hola, ¿la pieza incluye garantía?',
      sentAt: DateTime(2026, 8, 31, 12, 10),
      fromClient: true,
    ),
    YonkeQuoteMessage(
      id: 'demo-message-2',
      text: 'Sí, cuenta con 30 días de garantía.',
      sentAt: DateTime(2026, 8, 31, 12, 14),
      fromClient: false,
    ),
  ],
  'demo-quote-transmision': [
    YonkeQuoteMessage(
      id: 'demo-message-3',
      text: 'Perfecto, revisaré tu propuesta.',
      sentAt: DateTime(2026, 8, 30, 17, 20),
      fromClient: true,
    ),
  ],
};
