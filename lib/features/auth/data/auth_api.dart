import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_file.dart';

class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  Future<dynamic> getClientProfile(String clientId) =>
      _client.get(ApiEndpoints.clientProfile(clientId));

  Future<dynamic> getOwnClientProfile() =>
      _client.get(ApiEndpoints.ownClientProfile);

  Future<dynamic> updateOwnClientProfile({
    required String name,
    String? email,
    Uint8List? photoBytes,
    String? photoFileName,
    String? photoUrl,
  }) {
    if (photoBytes != null && photoBytes.isNotEmpty) {
      return _client.multipart(
        ApiEndpoints.updateOwnClientProfile,
        method: 'PUT',
        fields: {
          'nombre': name.trim(),
          if (email != null && email.trim().isNotEmpty) 'correo': email.trim(),
          if (photoUrl != null && photoUrl.trim().isNotEmpty)
            'fotoPerfil': photoUrl.trim(),
        },
        files: [
          ApiFile(
            fieldName: 'foto',
            fileName: photoFileName ?? 'perfil.jpg',
            bytes: photoBytes,
          ),
        ],
      );
    }
    return _client.put(
      ApiEndpoints.updateOwnClientProfile,
      data: {
        'nombre': name.trim(),
        if (email != null && email.trim().isNotEmpty) 'correo': email.trim(),
        if (photoUrl != null && photoUrl.trim().isNotEmpty)
          'fotoPerfil': photoUrl.trim(),
      },
    );
  }

  Future<dynamic> loginClientWithGoogle(String idToken) =>
      _client.post(ApiEndpoints.clientGoogleLogin, data: {'idToken': idToken});

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

  Future<dynamic> forgotPasswordYonke(String email) => _client.post(
    ApiEndpoints.yonkeForgotPassword,
    data: {'email': email.trim().toLowerCase()},
  );
}
