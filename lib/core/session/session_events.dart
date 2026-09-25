import 'dart:async';

import '../storage/token_store.dart';

/// Avisa a la app cuando el servidor deja de aceptar la sesión guardada.
abstract final class SessionEvents {
  static final _expired = StreamController<void>.broadcast();

  static Stream<void> get expired => _expired.stream;

  static void notifyExpired() => _expired.add(null);

  static final _signedIn = StreamController<void>.broadcast();
  static final _signedOut = StreamController<void>.broadcast();

  /// Se guardó una sesión nueva (login de cliente o de yonke).
  static Stream<void> get signedIn => _signedIn.stream;

  /// Se borró la sesión (cierre de sesión, baja o 401).
  static Stream<void> get signedOut => _signedOut.stream;

  static void notifySignedIn() => _signedIn.add(null);

  static void notifySignedOut() => _signedOut.add(null);
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
