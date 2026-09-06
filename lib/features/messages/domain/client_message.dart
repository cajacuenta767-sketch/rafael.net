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
