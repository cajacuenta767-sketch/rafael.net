import '../data/auth_api.dart';
import 'session_payload.dart';

class YonkeLoginResult {
  const YonkeLoginResult({
    required this.sessionContractPending,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.yonkeId,
    this.availableKeys = const <String>[],
  });

  factory YonkeLoginResult.fromResponse(Object? response) {
    final payload = SessionResponseParser.parse(response);
    if (!payload.hasAccessToken) {
      return YonkeLoginResult(
        sessionContractPending: true,
        availableKeys: payload.availableKeys,
      );
    }
    return YonkeLoginResult(
      sessionContractPending: false,
      accessToken: payload.accessToken,
      refreshToken: payload.refreshToken,
      expiresAt: payload.expiresAt,
      yonkeId: payload.yonkeGuidId,
      availableKeys: payload.availableKeys,
    );
  }

  final bool sessionContractPending;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  /// Necesario para perfil, cobertura y registro de dispositivo del yonke.
  final String? yonkeId;

  final List<String> availableKeys;

  bool get hasUsableSession =>
      !sessionContractPending && accessToken?.isNotEmpty == true;

  String get keysSummary =>
      availableKeys.isEmpty ? 'ninguna' : availableKeys.join(', ');
}

abstract interface class YonkeAuthRepository {
  Future<YonkeLoginResult> login({
    required String email,
    required String password,
  });
}

class ApiYonkeAuthRepository implements YonkeAuthRepository {
  const ApiYonkeAuthRepository(this._api);

  final AuthApi _api;

  @override
  Future<YonkeLoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.loginYonke(email: email, password: password);
    return YonkeLoginResult.fromResponse(response);
  }
}
