enum QuotePaymentStatus {
  pending(1, 'Pendiente'),
  processing(2, 'Procesando'),
  paid(3, 'Pagada'),
  failed(4, 'Fallida'),
  canceled(5, 'Cancelada'),
  refunded(6, 'Reembolsada'),
  unknown(0, 'Desconocido');

  const QuotePaymentStatus(this.code, this.label);

  final int code;
  final String label;

  static QuotePaymentStatus fromValue(dynamic value) {
    if (value == null) return QuotePaymentStatus.pending;
    if (value is bool) {
      return value ? QuotePaymentStatus.paid : QuotePaymentStatus.pending;
    }
    if (value is num) {
      return switch (value.toInt()) {
        1 => QuotePaymentStatus.pending,
        2 => QuotePaymentStatus.processing,
        3 => QuotePaymentStatus.paid,
        4 => QuotePaymentStatus.failed,
        5 => QuotePaymentStatus.canceled,
        6 => QuotePaymentStatus.refunded,
        _ => QuotePaymentStatus.unknown,
      };
    }
    final str = value.toString().toLowerCase().trim();
    return switch (str) {
      '3' || 'pagado' || 'pagada' || 'paid' => QuotePaymentStatus.paid,
      '2' || 'procesando' || 'processing' => QuotePaymentStatus.processing,
      '4' || 'fallido' || 'failed' => QuotePaymentStatus.failed,
      '5' || 'cancelado' || 'canceled' => QuotePaymentStatus.canceled,
      '6' || 'reembolsado' || 'refunded' => QuotePaymentStatus.refunded,
      '1' || 'pendiente' || 'pending' => QuotePaymentStatus.pending,
      _ => QuotePaymentStatus.unknown,
    };
  }
}
