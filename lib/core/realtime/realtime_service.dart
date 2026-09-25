import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';

/// Conexión al hub `/hubs/notificaciones` del API (ChatHub).
///
/// Las conversaciones se suscriben a una cotización con [watchQuote] y
/// reciben un aviso cada vez que el servidor emite `NuevoMensaje`. Si el hub
/// no acepta la conexión (el API publicado no lee el JWT de la query del
/// WebSocket), cada pantalla conserva su sondeo periódico como respaldo.
class RealtimeService {
  RealtimeService(this._tokens, {String? hubUrl})
    : _hubUrl = hubUrl ?? '${AppConfig.apiBaseUrl}${AppConfig.signalRHubPath}';

  final TokenStore _tokens;
  final String _hubUrl;
  final _messages = StreamController<String>.broadcast();
  final _watched = <String, int>{};
  HubConnection? _connection;
  Future<bool>? _connecting;

  /// Cotizaciones con un mensaje nuevo, por `solicitudCotizacionGuidId`.
  Stream<String> get newMessages => _messages.stream;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  /// Se une al grupo de la cotización. Devuelve `false` si no hay conexión
  /// en tiempo real; la pantalla debe seguir con su sondeo.
  Future<bool> watchQuote(String quoteId) async {
    _watched.update(quoteId, (count) => count + 1, ifAbsent: () => 1);
    if (!await _ensureConnected()) return false;
    try {
      await _connection!.invoke('UnirseCotizacion', args: [quoteId]);
      return true;
    } catch (error) {
      _log('No se pudo unir a la cotización: $error');
      return false;
    }
  }

  Future<void> unwatchQuote(String quoteId) async {
    final count = (_watched[quoteId] ?? 1) - 1;
    if (count > 0) {
      _watched[quoteId] = count;
      return;
    }
    _watched.remove(quoteId);
    if (!isConnected) return;
    try {
      await _connection!.invoke('SalirCotizacion', args: [quoteId]);
    } catch (_) {
      // El servidor retira la conexión del grupo al desconectarse.
    }
  }

  /// Cierra la conexión (cierre de sesión o sesión vencida).
  Future<void> stop() async {
    _watched.clear();
    final connection = _connection;
    _connection = null;
    _connecting = null;
    if (connection == null) return;
    try {
      await connection.stop();
    } catch (_) {}
  }

  Future<bool> _ensureConnected() {
    if (isConnected) return Future.value(true);
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<bool> _connect() async {
    final String? token;
    try {
      token = await _tokens.readAccessToken();
    } catch (_) {
      return false;
    }
    if (token == null || token.isEmpty || token.startsWith('development-')) {
      return false;
    }
    final connection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async =>
                await _tokens.readAccessToken() ?? '',
            requestTimeout: AppConfig.receiveTimeout.inMilliseconds,
          ),
        )
        .withAutomaticReconnect()
        .build();
    connection.on('NuevoMensaje', (arguments) {
      final quoteId = quoteIdFromHubMessage(arguments);
      if (quoteId != null) _messages.add(quoteId);
    });
    connection.onreconnected(({connectionId}) => _rejoinWatched());
    try {
      await connection.start();
      _connection = connection;
      return true;
    } catch (error) {
      _log('Tiempo real no disponible, se usa sondeo: $error');
      return false;
    }
  }

  Future<void> _rejoinWatched() async {
    for (final quoteId in _watched.keys) {
      try {
        await _connection?.invoke('UnirseCotizacion', args: [quoteId]);
      } catch (_) {}
    }
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[realtime] $message');
  }
}

/// `NuevoMensaje` envía un `SolicitudCotizacionMensajeDTO`; la cotización
/// está en `solicitudCotizacionGuidId`.
@visibleForTesting
String? quoteIdFromHubMessage(List<Object?>? arguments) {
  final payload = arguments == null || arguments.isEmpty
      ? null
      : arguments.first;
  if (payload is! Map) return null;
  for (final key in const [
    'solicitudCotizacionGuidId',
    'SolicitudCotizacionGuidId',
    'cotizacionGuidId',
  ]) {
    final value = payload[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
