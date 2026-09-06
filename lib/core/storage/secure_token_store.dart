import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'auth.access_token';
  static const _refreshTokenKey = 'auth.refresh_token';
  static const _expiresAtKey = 'auth.expires_at';
  static const _yonkeGuidIdKey = 'auth.yonke_guid_id';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<DateTime?> readExpiresAt() async {
    final stored = await _storage.read(key: _expiresAtKey);
    if (stored == null || stored.isEmpty) return null;
    return DateTime.tryParse(stored)?.toUtc();
  }

  @override
  Future<String?> readYonkeGuidId() => _storage.read(key: _yonkeGuidIdKey);

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
    if (expiresAt != null) {
      await _storage.write(
        key: _expiresAtKey,
        value: expiresAt.toUtc().toIso8601String(),
      );
    }
    if (yonkeGuidId != null && yonkeGuidId.isNotEmpty) {
      await _storage.write(key: _yonkeGuidIdKey, value: yonkeGuidId);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiresAtKey);
    await _storage.delete(key: _yonkeGuidIdKey);
  }
}
