import '../../../core/session/session_events.dart';
import '../../yonkes/data/yonkes_api.dart';
import '../../yonkes/domain/client_yonke.dart';
import '../domain/client_quote.dart';
import 'quotes_api.dart';

/// Completa el nombre, el logo y el teléfono del yonke de una cotización.
///
/// `DashboardSuscriptores/mis-cotizaciones` no trae el yonke, así que el
/// cliente veía "Yonke asignado". `GET /api/CotizacionYonke/{guid}` incluye
/// `solicitudYonkes.yonkeGuidId` y `GET /api/Yonkes/{guid}` da el nombre y el
/// logo que el yonke registró. Ambas aceptan el JWT del cliente.
class QuoteYonkeResolver {
  QuoteYonkeResolver(this._quotesApi, this._yonkesApi);

  final QuotesApi _quotesApi;
  final YonkesApi _yonkesApi;

  /// Se comparten entre pantallas: la misma cotización y el mismo yonke no
  /// se piden dos veces en la sesión.
  final _yonkeIdByQuote = <String, String>{};
  final _yonkes = <String, Future<ClientYonke?>>{};
  int _sessionRevision = SessionEvents.revision;

  Future<List<ClientQuote>> resolveAll(List<ClientQuote> quotes) =>
      Future.wait(quotes.map(resolve));

  /// Nunca falla: si el API no responde se conserva la cotización tal cual.
  Future<ClientQuote> resolve(ClientQuote quote) async {
    if (_sessionRevision != SessionEvents.revision) {
      _yonkeIdByQuote.clear();
      _yonkes.clear();
      _sessionRevision = SessionEvents.revision;
    }
    if (quote.hasYonkeIdentity &&
        quote.logoUrl != null &&
        quote.yonkeId.isNotEmpty) {
      return quote;
    }
    try {
      final revision = _sessionRevision;
      final yonkeId = await _yonkeIdFor(quote, revision);
      if (revision != SessionEvents.revision) return quote;
      if (yonkeId == null) return quote;
      final yonke = await (_yonkes[yonkeId] ??= _loadYonke(yonkeId));
      if (revision != SessionEvents.revision) return quote;
      if (yonke == null) return quote;
      return quote.withYonke(
        yonkeId: yonke.id,
        yonkeName: yonke.name,
        logoUrl: _safeLogo(yonke.logoUrl),
        phone: yonke.phone,
      );
    } catch (_) {
      return quote;
    }
  }

  Future<String?> _yonkeIdFor(ClientQuote quote, int revision) async {
    if (quote.yonkeId.isNotEmpty) return quote.yonkeId;
    final cached = _yonkeIdByQuote[quote.id];
    if (cached != null) return cached;
    final response = await _quotesApi.getById(quote.id);
    final data = response is Map ? response['data'] ?? response : null;
    final assignment = data is Map
        ? (data['solicitudYonkes'] ?? data['SolicitudYonkes'])
        : null;
    final yonkeId = assignment is Map
        ? (assignment['yonkeGuidId'] ?? assignment['YonkeGuidId'])
              ?.toString()
              .trim()
        : null;
    if (yonkeId == null || yonkeId.isEmpty) return null;
    if (revision == SessionEvents.revision) _yonkeIdByQuote[quote.id] = yonkeId;
    return yonkeId;
  }

  Future<ClientYonke?> _loadYonke(String yonkeId) async {
    try {
      return clientYonkeFromResponse(await _yonkesApi.getById(yonkeId));
    } catch (_) {
      _yonkes.remove(yonkeId);
      return null;
    }
  }

  static String? _safeLogo(String? url) {
    final uri = Uri.tryParse(url ?? '');
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? url
        : null;
  }
}
