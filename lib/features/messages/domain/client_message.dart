class ClientQuoteMessage {
  const ClientQuoteMessage({
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

  /// Mensaje confirmado como enviado, pero que aún no puede reconciliarse con
  /// el historial hasta que el backend publique el contrato de respuesta.
  final bool localOnly;
}

class ClientConversationResult {
  const ClientConversationResult({
    required this.messages,
    required this.historyContractPending,
  });

  final List<ClientQuoteMessage> messages;
  final bool historyContractPending;
}
