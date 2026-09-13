import 'package:app_yonke/features/auth/presentation/session_check.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/recording_api_client.dart';

/// JWT con `exp` 2030-01-01 (vigente) y otro ya vencido (2020-01-01).
const _validJwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJzdWIiOiJ1c2VyLTQyIiwicm9sZSI6IkNsaWVudGUiLCJleHAiOjE4OTM0NTYwMDB9.'
    'ZmFrZS1zaWduYXR1cmU';
const _expiredJwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJzdWIiOiJ1c2VyLTQyIiwiZXhwIjoxNTc3ODM2ODAwfQ.'
    'ZmFrZS1zaWduYXR1cmU';

void main() {
  test('sin token no hay sesión', () async {
    expect(await hasUsableSession(MemoryTokenStore()), isFalse);
  });

  test('un token vigente mantiene la sesión', () async {
    final store = MemoryTokenStore(accessToken: _validJwt);
    expect(await hasUsableSession(store), isTrue);
    expect(store.clears, 0);
  });

  test(
    'una expiración informada por el servidor y ya pasada cierra la sesión',
    () async {
      final store = MemoryTokenStore(
        accessToken: 'token-opaco',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );
      expect(await hasUsableSession(store), isFalse);
      expect(store.clears, 1);
      expect(store.accessToken, isNull);
    },
  );

  test('un JWT vencido por su claim exp cierra la sesión', () async {
    final store = MemoryTokenStore(accessToken: _expiredJwt);
    expect(await hasUsableSession(store), isFalse);
    expect(store.clears, 1);
  });

  test('un token opaco sin expiración conocida se conserva', () async {
    final store = MemoryTokenStore(accessToken: 'token-opaco');
    expect(await hasUsableSession(store), isTrue);
  });
}
