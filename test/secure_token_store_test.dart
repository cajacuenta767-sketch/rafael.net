import 'package:app_yonke/core/storage/secure_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('nueva sesión cliente elimina metadatos del yonke anterior', () async {
    final store = SecureTokenStore();
    await store.writeTokens(
      accessToken: 'yonke-token',
      refreshToken: 'old-refresh',
      expiresAt: DateTime.utc(2030),
      yonkeGuidId: 'old-yonke',
    );
    await store.writeTokens(accessToken: 'client-token');
    expect(await store.readAccessToken(), 'client-token');
    expect(await store.readRefreshToken(), isNull);
    expect(await store.readExpiresAt(), isNull);
    expect(await store.readYonkeGuidId(), isNull);
  });

  test('guarda la sesión completa y clear elimina todos los campos', () async {
    final store = SecureTokenStore();
    final expires = DateTime.utc(2030);
    await store.writeTokens(
      accessToken: 'new-token',
      refreshToken: 'new-refresh',
      expiresAt: expires,
      yonkeGuidId: 'new-yonke',
    );
    expect(await store.readExpiresAt(), expires);
    expect(await store.readYonkeGuidId(), 'new-yonke');
    await store.clear();
    expect(await store.readAccessToken(), isNull);
    expect(await store.readRefreshToken(), isNull);
    expect(await store.readExpiresAt(), isNull);
    expect(await store.readYonkeGuidId(), isNull);
  });

  test('rechaza token vacío sin alterar sesión existente', () async {
    final store = SecureTokenStore();
    await store.writeTokens(accessToken: 'existing');
    await expectLater(store.writeTokens(accessToken: ' '), throwsArgumentError);
    expect(await store.readAccessToken(), 'existing');
  });
}
