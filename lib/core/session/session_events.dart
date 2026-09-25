import 'dart:async';

import '../storage/token_store.dart';

/// Avisa a la app cuando el servidor deja de aceptar la sesión guardada.
abstract final class SessionEvents {
  static final _expired = StreamController<void>.broadcast();

  static Stream<void> get expired => _expired.stream;

  static void notifyExpired() => _expired.add(null);
}

/// Sesión utilizable: hay token y, si el servidor informó expiración, aún no
/// vence. Una sesión vencida se borra para que el login empiece limpio.
Future<bool> hasActiveSession(TokenStore tokens, {DateTime? now}) async {
  final token = await tokens.readAccessToken();
  if (token == null || token.isEmpty) return false;
  final expiresAt = await tokens.readExpiresAt();
  if (expiresAt != null &&
      !expiresAt.isAfter((now ?? DateTime.now()).toUtc())) {
    await tokens.clear();
    return false;
  }
  return true;
}
