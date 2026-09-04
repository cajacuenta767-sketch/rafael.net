import '../../quotes/data/quotes_api.dart';
import '../domain/client_message.dart';

abstract interface class ClientMessagesRepository {
  bool get usesDemoData;

  Future<ClientConversationResult> getConversation(String quoteId);

  Future<void> sendMessage({required String quoteId, required String message});
}

/// El backend expone la conversación por cotización y el envío de mensajes,
/// pero Swagger todavía no describe el JSON del historial. No se inventa una
/// conversión de campos: se permite enviar y se indica claramente la espera.
class ApiClientMessagesRepository implements ClientMessagesRepository {
  const ApiClientMessagesRepository(this._quotesApi);

  final QuotesApi _quotesApi;

  @override
  bool get usesDemoData => false;

  @override
  Future<ClientConversationResult> getConversation(String quoteId) async {
    await _quotesApi.getConversation(quoteId);
    return const ClientConversationResult(
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

class DemoClientMessagesRepository implements ClientMessagesRepository {
  const DemoClientMessagesRepository();

  @override
  bool get usesDemoData => true;

  @override
  Future<ClientConversationResult> getConversation(String quoteId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return ClientConversationResult(
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

final _demoMessages = <String, List<ClientQuoteMessage>>{
  'mock-quote-norte': [
    ClientQuoteMessage(
      id: 'demo-client-message-1',
      text: 'Hola, ¿la pieza incluye garantía?',
      sentAt: DateTime(2026, 8, 31, 12, 10),
      fromClient: true,
    ),
    ClientQuoteMessage(
      id: 'demo-client-message-2',
      text: 'Sí, cuenta con 15 días de garantía.',
      sentAt: DateTime(2026, 8, 31, 12, 14),
      fromClient: false,
    ),
  ],
  'mock-quote-centro': [
    ClientQuoteMessage(
      id: 'demo-client-message-3',
      text: '¿El alternador ya fue probado?',
      sentAt: DateTime(2026, 8, 30, 17, 20),
      fromClient: true,
    ),
    ClientQuoteMessage(
      id: 'demo-client-message-4',
      text: 'Sí, está probado y listo para entrega.',
      sentAt: DateTime(2026, 8, 30, 17, 28),
      fromClient: false,
    ),
  ],
};
