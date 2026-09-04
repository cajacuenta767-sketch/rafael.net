class ClientOrder {
  const ClientOrder({
    required this.id,
    required this.quoteId,
    required this.status,
    required this.createdAt,
    required this.isCancelled,
    required this.canCancel,
    required this.responseContractPending,
  });

  /// Puede ser nulo mientras la API no exponga el identificador en su respuesta.
  final String? id;
  final String quoteId;
  final String? status;
  final DateTime? createdAt;
  final bool isCancelled;
  final bool canCancel;
  final bool responseContractPending;

  ClientOrder copyWith({
    String? id,
    String? status,
    DateTime? createdAt,
    bool? isCancelled,
    bool? canCancel,
    bool? responseContractPending,
  }) => ClientOrder(
    id: id ?? this.id,
    quoteId: quoteId,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    isCancelled: isCancelled ?? this.isCancelled,
    canCancel: canCancel ?? this.canCancel,
    responseContractPending:
        responseContractPending ?? this.responseContractPending,
  );
}
