import '../data/auth_api.dart';

class YonkeLoginResult {
  const YonkeLoginResult({required this.sessionContractPending});

  final bool sessionContractPending;

  bool get hasUsableSession => !sessionContractPending;
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
    await _api.loginYonke(email: email, password: password);

    // OpenAPI no documenta el modelo de respuesta ni el nombre del token.
    // No se inspeccionan claves supuestas ni se crea una sesión ficticia.
    return const YonkeLoginResult(sessionContractPending: true);
  }
}
