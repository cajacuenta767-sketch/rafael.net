import '../../../core/storage/token_store.dart';
import 'session_payload.dart';

/// Identificador del usuario autenticado, leído de los claims del token
/// guardado (`sub`, `nameid` o `NameIdentifier`). `null` si no hay sesión o
/// el token no lo incluye.
Future<String?> currentUserIdFrom(TokenStore tokenStore) async {
  final token = await tokenStore.readAccessToken();
  if (token == null || token.isEmpty) return null;
  return SessionResponseParser.subjectFromToken(token);
}
