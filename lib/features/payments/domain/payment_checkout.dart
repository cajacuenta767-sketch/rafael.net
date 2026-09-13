/// Sesión de pago creada por `POST /api/Pagos/checkout/{ordenGuidId}`.
///
/// El servidor genera una sesión de Stripe Checkout y devuelve la URL que el
/// cliente debe abrir en el navegador. El identificador de sesión permite
/// consultar después el resultado con `GET /api/Pagos/resultado/{sessionId}`.
class PaymentCheckout {
  const PaymentCheckout({required this.url, this.sessionId});

  final Uri url;

  /// Nulo cuando el servidor no lo informa por separado; en ese caso se intenta
  /// leerlo de la propia URL (`cs_...`).
  final String? sessionId;
}

/// Resultado de una sesión de pago consultado al servidor.
class PaymentResult {
  const PaymentResult({
    required this.status,
    required this.paid,
    this.message,
    this.amount,
  });

  /// Estado tal como lo devolvió el servidor (`paid`, `open`, `pendiente`...).
  final String status;

  /// `true` cuando el servidor confirma el cobro.
  final bool paid;
  final String? message;
  final double? amount;

  String get label {
    if (paid) return 'Pago confirmado';
    switch (status.toLowerCase()) {
      case 'open':
      case 'unpaid':
      case 'pending':
      case 'pendiente':
      case 'abierto':
        return 'Pago pendiente';
      case 'expired':
      case 'expirado':
      case 'cancelled':
      case 'canceled':
      case 'cancelado':
        return 'Sesión de pago vencida';
      default:
        return status.isEmpty ? 'Estado desconocido' : status;
    }
  }
}
