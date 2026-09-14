import '../../../core/storage/token_store.dart';
import '../domain/session_payload.dart';

/// Indica si hay una sesión guardada y todavía vigente.
///
/// La expiración sale de la fecha que informó el servidor al iniciar sesión
/// o, en su defecto, del claim `exp` del propio JWT. Una sesión vencida se
/// borra del almacenamiento seguro para que la app vuelva al inicio de sesión
/// en lugar de recibir 401 en cada pantalla.
Future<bool> hasUsableSession(TokenStore tokenStore) async {
  final token = await tokenStore.readAccessToken();
  if (token == null || token.trim().isEmpty) return false;

  final expiresAt =
      await tokenStore.readExpiresAt() ??
      SessionResponseParser.expiryFromClaims(token);
  if (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc())) {
    await tokenStore.clear();
    return false;
  }
  return true;
}
