/// El historial y la confirmación de lectura son operaciones distintas.
/// Un fallo de lectura no oculta mensajes ni se presenta como sincronizado.
mixin ReadReceiptTracking {
  final Map<String, Object> _readErrors = {};

  bool readReceiptPending(String quoteId) => _readErrors.containsKey(quoteId);

  Future<void> synchronizeReadReceipt(
    String quoteId,
    Future<dynamic> Function() markRead,
  ) async {
    try {
      await markRead();
      _readErrors.remove(quoteId);
    } catch (error) {
      _readErrors[quoteId] = error;
    }
  }
}
