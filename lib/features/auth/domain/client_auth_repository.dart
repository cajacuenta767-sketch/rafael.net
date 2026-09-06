import '../data/auth_api.dart';
import 'session_payload.dart';

class ClientOtpVerification {
  const ClientOtpVerification({
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.userId,
    this.sessionContractPending = false,
    this.availableKeys = const <String>[],
  });

  /// Interpreta la respuesta cruda del login.
  ///
  /// [ignoreToken] evita aceptar como sesión un valor que la propia app acaba
  /// de enviar. En el login de Google el request lleva `idToken`; si el
  /// servidor lo devolviera tal cual, tomarlo por token de sesión daría una
  /// sesión falsa que fallaría en el primer endpoint protegido.
  factory ClientOtpVerification.fromResponse(
    Object? response, {
    String? ignoreToken,
  }) {
    final payload = SessionResponseParser.parse(response);
    final token = payload.accessToken;
    final usable =
        payload.hasAccessToken &&
        (ignoreToken == null || token!.trim() != ignoreToken.trim());

    if (!usable) {
      return ClientOtpVerification(
        sessionContractPending: true,
        availableKeys: payload.availableKeys,
      );
    }

    return ClientOtpVerification(
      accessToken: token,
      refreshToken: payload.refreshToken,
      expiresAt: payload.expiresAt,
      userId: payload.userId,
      availableKeys: payload.availableKeys,
    );
  }

  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? userId;
  final bool sessionContractPending;

  /// Claves que traía la respuesta. Solo para diagnóstico: permite ver el
  /// nombre real del token la primera vez que se prueba contra el servidor.
  final List<String> availableKeys;

  bool get hasUsableSession => accessToken?.isNotEmpty == true;

  String get keysSummary =>
      availableKeys.isEmpty ? 'ninguna' : availableKeys.join(', ');
}

abstract interface class ClientAuthRepository {
  Future<ClientOtpVerification> loginWithGoogle(String idToken);

  Future<void> requestOtp(String phone);

  Future<ClientOtpVerification> verifyOtp({
    required String phone,
    required String code,
  });
}

class ApiClientAuthRepository implements ClientAuthRepository {
  const ApiClientAuthRepository(this._api);

  final AuthApi _api;

  @override
  Future<ClientOtpVerification> loginWithGoogle(String idToken) async {
    final response = await _api.loginClientWithGoogle(idToken);
    return ClientOtpVerification.fromResponse(response, ignoreToken: idToken);
  }

  @override
  Future<void> requestOtp(String phone) async {
    await _api.requestOtp(phone);
  }

  @override
  Future<ClientOtpVerification> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final response = await _api.verifyOtp(phone: phone, code: code);
    return ClientOtpVerification.fromResponse(response);
  }
}
