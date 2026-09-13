import '../../../core/network/paged_response.dart';

/// Mensaje de la conversación de una cotización, según el esquema
/// `SolicitudCotizacionMensajes` del OpenAPI: `guidId`,
/// `solicitudCotizacionGuidId`, `usuarioId`, `tipoRemitenteId`, `mensaje`,
/// `leido`, `fechaLectura` y `fechaCreacion`.
class QuoteMessageRecord {
  const QuoteMessageRecord({
    required this.id,
    required this.quoteId,
    required this.text,
    required this.sentAt,
    required this.read,
    this.senderUserId,
    this.senderTypeId,
  });

  final String id;
  final String quoteId;
  final String text;
  final DateTime sentAt;
  final bool read;

  /// `usuarioId` del remitente. Es la forma fiable de saber quién escribió.
  final String? senderUserId;

  /// `tipoRemitenteId`. El catálogo no está documentado; se asume que
  /// [clientSenderType] identifica al cliente cuando no se puede comparar el
  /// `usuarioId` con el usuario que consulta.
  final int? senderTypeId;

  /// Indica si el mensaje lo escribió el cliente de la solicitud.
  ///
  /// Con [viewerUserId] conocido compara `usuarioId`; el cliente ve como
  /// propios los suyos y el yonke como propios los que no son del cliente.
  bool isFromClient({
    required String? viewerUserId,
    required bool viewerIsClient,
  }) {
    if (viewerUserId != null && senderUserId != null) {
      final mine = senderUserId == viewerUserId;
      return viewerIsClient ? mine : !mine;
    }
    return senderTypeId == clientSenderType;
  }
}

/// Valor supuesto de `tipoRemitenteId` para el cliente. Pendiente de
/// confirmar con el backend (ver docs/BACKEND_CONTRACT_CHECKLIST.md).
const clientSenderType = 1;

/// Interpreta la respuesta de `GET /api/SolicitudCotizacionMensajes/{id}`.
/// Devuelve los mensajes ordenados del más antiguo al más reciente.
List<QuoteMessageRecord> quoteMessagesFromResponse(dynamic response) {
  final records = pagedRecords(response);
  final messages = records
      .whereType<Map>()
      .map(quoteMessageFromJson)
      .whereType<QuoteMessageRecord>()
      .toList();
  messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
  return messages;
}

QuoteMessageRecord? quoteMessageFromJson(Map<dynamic, dynamic> json) {
  final text = _text(json['mensaje']);
  final id = _text(json['guidId']) ?? _text(json['id']);
  if (text == null || id == null) return null;
  final senderType = json['tipoRemitenteId'];
  return QuoteMessageRecord(
    id: id,
    quoteId: _text(json['solicitudCotizacionGuidId']) ?? '',
    text: text,
    sentAt:
        DateTime.tryParse(json['fechaCreacion']?.toString() ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    read: json['leido'] == true,
    senderUserId: _text(json['usuarioId']),
    senderTypeId: senderType is num
        ? senderType.toInt()
        : int.tryParse('$senderType'),
  );
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
