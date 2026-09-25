import '../session/session_events.dart';
import 'token_store.dart';

/// Envuelve el almacén de tokens y avisa cuando la sesión empieza o termina,
/// para que el registro de push y la conexión en tiempo real sigan a la
/// sesión sin que cada pantalla de login o de perfil tenga que llamarlos.
class NotifyingTokenStore implements TokenStore {
  const NotifyingTokenStore(this._inner);

  final TokenStore _inner;

  @override
  Future<String?> readAccessToken() => _inner.readAccessToken();

  @override
  Future<String?> readRefreshToken() => _inner.readRefreshToken();

  @override
  Future<DateTime?> readExpiresAt() => _inner.readExpiresAt();

  @override
  Future<String?> readYonkeGuidId() => _inner.readYonkeGuidId();

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async {
    await _inner.writeTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      yonkeGuidId: yonkeGuidId,
    );
    SessionEvents.notifySignedIn();
  }

  @override
  Future<void> clear() async {
    await _inner.clear();
    SessionEvents.notifySignedOut();
  }
}
