class ClientOrderCreationResult {
  const ClientOrderCreationResult({
    required this.orderId,
    required this.responseContractPending,
  });

  /// Puede ser nulo porque el endpoint CrearOrden no documenta su respuesta.
  final String? orderId;
  final bool responseContractPending;
}
