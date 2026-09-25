/// Datos del cliente que el yonke ve en la bandeja y en el chat, igual que
/// el cliente ve el nombre, el logo y el teléfono del yonke.
class QuoteClient {
  const QuoteClient({this.name, this.phone, this.photoUrl});

  final String? name;
  final String? phone;
  final String? photoUrl;

  bool get isEmpty => name == null && phone == null && photoUrl == null;
}

/// Lee al cliente de `GET /api/CotizacionYonke/{guid}`.
///
/// El API publicado todavía no incluye al cliente (ver
/// `docs/BACKEND_ISSUES.md`, "Pedido para el API: cliente en la
/// cotización"). Se aceptan los nombres propuestos ahí para que la app lo
/// muestre en cuanto el servidor lo entregue, sin otra versión.
QuoteClient? quoteClientFromResponse(dynamic response) {
  final data = response is Map ? response['data'] ?? response : null;
  if (data is! Map) return null;
  final assignment = data['solicitudYonkes'];
  final request = assignment is Map ? assignment['solicitudes'] : null;
  final sources = <Map>[
    for (final holder in [data, assignment, request])
      if (holder is Map) ...[
        for (final key in const ['cliente', 'clientes'])
          if (holder[key] is Map) holder[key] as Map,
      ],
  ];

  String? pick(List<String> nested, List<String> flat) {
    for (final source in sources) {
      for (final key in nested) {
        final value = _text(source[key]);
        if (value != null) return value;
      }
    }
    for (final key in flat) {
      final value = _text(data[key]);
      if (value != null) return value;
    }
    return null;
  }

  final name = pick(const ['nombre'], const ['nombreCliente']);
  final client = QuoteClient(
    // El login por OTP crea al cliente con este nombre de relleno.
    name: name == null || name.toLowerCase() == 'cliente refanet' ? null : name,
    phone: pick(const ['telefono'], const ['telefonoCliente']),
    photoUrl: _safeImage(
      pick(const ['fotoPerfil', 'foto'], const ['fotoCliente']),
    ),
  );
  return client.isEmpty ? null : client;
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String? _safeImage(String? url) {
  final uri = Uri.tryParse(url ?? '');
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
      ? url
      : null;
}
