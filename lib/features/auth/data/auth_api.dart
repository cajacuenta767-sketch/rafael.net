import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  Future<dynamic> loginClientWithGoogle(String idToken) =>
      _client.post(ApiEndpoints.clientGoogleLogin, data: {'idToken': idToken});

  Future<dynamic> loginClientWithApple({
    required String identityToken,
    required String authorizationCode,
    required String userIdentifier,
    String? firstName,
    String? lastName,
  }) => _client.post(
    ApiEndpoints.clientAppleLogin,
    data: {
      'identityToken': identityToken,
      'authorizationCode': authorizationCode,
      'userIdentifier': userIdentifier,
      'nombre': firstName,
      'apellido': lastName,
    },
  );

  Future<dynamic> requestOtp(String phone) =>
      _client.post(ApiEndpoints.requestOtp, data: {'telefono': phone});

  Future<dynamic> verifyOtp({required String phone, required String code}) =>
      _client.post(
        ApiEndpoints.verifyOtp,
        data: {'telefono': phone, 'codigo': code},
      );

  Future<dynamic> registerClientDevice({
    required String firebaseToken,
    required String platform,
    required String model,
  }) => _client.post(
    ApiEndpoints.registerClientDevice,
    data: {
      'firebaseToken': firebaseToken,
      'plataforma': platform,
      'modelo': model,
    },
  );

  Future<dynamic> loginYonke({
    required String email,
    required String password,
  }) => _client.post(
    ApiEndpoints.yonkeLogin,
    data: {'correo': email, 'password': password},
  );
}
