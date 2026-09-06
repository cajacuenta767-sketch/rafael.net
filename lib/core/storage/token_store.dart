abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();

  /// Expiración en UTC de la sesión guardada, si el servidor la informó.
  Future<DateTime?> readExpiresAt();

  /// Identificador del yonke autenticado. Perfil, cobertura y registro de
  /// dispositivo lo requieren en la ruta o en el cuerpo.
  Future<String?> readYonkeGuidId();

  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  });

  Future<void> clear();
}
