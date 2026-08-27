import '../data/auth_api.dart';

class ClientOtpVerification {
  const ClientOtpVerification({
    this.accessToken,
    this.refreshToken,
    this.sessionContractPending = false,
  });

  final String? accessToken;
  final String? refreshToken;
  final bool sessionContractPending;

  bool get hasUsableSession => accessToken?.isNotEmpty == true;
}

abstract interface class ClientAuthRepository {
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
  Future<void> requestOtp(String phone) async {
    await _api.requestOtp(phone);
  }

  @override
  Future<ClientOtpVerification> verifyOtp({
    required String phone,
    required String code,
  }) async {
    await _api.verifyOtp(phone: phone, code: code);

    // El OpenAPI actual no define el JSON de respuesta ni el nombre del token.
    // No se inspeccionan claves supuestas para evitar crear una sesión falsa.
    return const ClientOtpVerification(sessionContractPending: true);
  }
}
