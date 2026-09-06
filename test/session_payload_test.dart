import 'package:app_yonke/features/auth/domain/client_auth_repository.dart';
import 'package:app_yonke/features/auth/domain/session_payload.dart';
import 'package:app_yonke/features/auth/domain/yonke_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// JWT de prueba: sub `user-42`, role `Cliente`, exp 2030-01-01T00:00:00Z.
/// La firma es texto cualquiera; el parser nunca la valida, eso es del backend.
const _jwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJzdWIiOiJ1c2VyLTQyIiwicm9sZSI6IkNsaWVudGUiLCJleHAiOjE4OTM0NTYwMDB9.'
    'ZmFrZS1zaWduYXR1cmU';

final _jwtExpiry = DateTime.utc(2030, 1, 1);

void main() {
  group('SessionResponseParser', () {
    test('reads the token from the documented ApiResponseGlobal envelope', () {
      final payload = SessionResponseParser.parse({
        'success': true,
        'message': 'Acceso correcto',
        'data': {
          'accessToken': _jwt,
          'refreshToken': 'refresh-1',
          'expiresIn': 3600,
          'yonkeGuidId': 'yonke-guid-1',
        },
        'statusCode': 200,
      });

      expect(payload.accessToken, _jwt);
      expect(payload.refreshToken, 'refresh-1');
      expect(payload.yonkeGuidId, 'yonke-guid-1');
      expect(payload.serverMessage, 'Acceso correcto');
      expect(payload.isUsable, isTrue);
      expect(
        payload.expiresAt!.difference(DateTime.now().toUtc()).inMinutes,
        closeTo(60, 2),
      );
    });

    test('reads a token placed directly at the root', () {
      final payload = SessionResponseParser.parse({'token': _jwt});
      expect(payload.accessToken, _jwt);
      expect(payload.isUsable, isTrue);
    });

    test('accepts data carrying the bare token string', () {
      final payload = SessionResponseParser.parse({
        'success': true,
        'data': _jwt,
      });
      expect(payload.accessToken, _jwt);
    });

    test('accepts a bare token as the whole response', () {
      expect(SessionResponseParser.parse(_jwt).accessToken, _jwt);
    });

    test('finds a token nested two levels deep', () {
      final payload = SessionResponseParser.parse({
        'success': true,
        'data': {
          'usuario': {'jwt': _jwt, 'usuarioId': 'u-9'},
        },
      });
      expect(payload.accessToken, _jwt);
      expect(payload.userId, 'u-9');
    });

    test('matches snake_case keys and absolute ISO expiry', () {
      final payload = SessionResponseParser.parse({
        'data': {
          'access_token': _jwt,
          'refresh_token': 'refresh-2',
          'expires_at': '2031-03-04T05:06:07Z',
        },
      });
      expect(payload.accessToken, _jwt);
      expect(payload.refreshToken, 'refresh-2');
      expect(payload.expiresAt, DateTime.utc(2031, 3, 4, 5, 6, 7));
    });

    test('falls back to the exp claim when no expiry key is present', () {
      final payload = SessionResponseParser.parse({
        'data': {'token': _jwt},
      });
      expect(payload.expiresAt, _jwtExpiry);
      expect(payload.userId, 'user-42');
      expect(payload.role, 'Cliente');
    });

    test('tells an absolute epoch from a relative lifetime', () {
      final absolute = SessionResponseParser.parse({
        'data': {'token': _jwt, 'expiresAt': 1893456000},
      });
      expect(absolute.expiresAt, _jwtExpiry);

      final relative = SessionResponseParser.parse({
        'data': {'token': _jwt, 'expiresAt': 120},
      });
      expect(
        relative.expiresAt!.difference(DateTime.now().toUtc()).inSeconds,
        closeTo(120, 5),
      );
    });

    test('rescues a token stored under an unexpected key', () {
      final payload = SessionResponseParser.parse({
        'data': {'miTokenSecreto': _jwt},
      });
      expect(payload.accessToken, _jwt);
    });

    test('reports the received keys when no token arrives', () {
      final payload = SessionResponseParser.parse({
        'success': false,
        'message': 'Código incorrecto',
        'data': null,
        'statusCode': 400,
      });

      expect(payload.hasAccessToken, isFalse);
      expect(payload.serverMessage, 'Código incorrecto');
      expect(payload.availableKeys, contains('statusCode'));
      expect(payload.keysSummary, contains('message'));
    });

    test('treats an already expired session as unusable', () {
      final payload = SessionResponseParser.parse({
        'data': {'token': _jwt, 'expiresAt': '2001-01-01T00:00:00Z'},
      });
      expect(payload.hasAccessToken, isTrue);
      expect(payload.isExpired, isTrue);
      expect(payload.isUsable, isFalse);
    });

    test('survives shapes it cannot read', () {
      expect(SessionResponseParser.parse(null).hasAccessToken, isFalse);
      expect(SessionResponseParser.parse('OK').hasAccessToken, isFalse);
      expect(SessionResponseParser.parse(<int>[1, 2]).hasAccessToken, isFalse);
      expect(SessionResponseParser.parse({}).hasAccessToken, isFalse);
    });
  });

  group('ClientOtpVerification.fromResponse', () {
    test('builds a usable session from the envelope', () {
      final result = ClientOtpVerification.fromResponse({
        'success': true,
        'data': {'accessToken': _jwt},
      });

      expect(result.hasUsableSession, isTrue);
      expect(result.sessionContractPending, isFalse);
      expect(result.accessToken, _jwt);
    });

    test('stays pending and keeps the keys when no token arrives', () {
      final result = ClientOtpVerification.fromResponse({
        'success': true,
        'data': {'usuarioId': 'u-1'},
      });

      expect(result.hasUsableSession, isFalse);
      expect(result.sessionContractPending, isTrue);
      expect(result.keysSummary, contains('data.usuarioId'));
    });

    test('refuses to reuse the Google idToken the app just sent', () {
      final result = ClientOtpVerification.fromResponse({
        'success': true,
        'data': {'idToken': _jwt},
      }, ignoreToken: _jwt);

      expect(result.hasUsableSession, isFalse);
      expect(result.sessionContractPending, isTrue);
    });
  });

  group('YonkeLoginResult.fromResponse', () {
    test('keeps the yonke guid that profile and coverage need', () {
      final result = YonkeLoginResult.fromResponse({
        'success': true,
        'data': {'token': _jwt, 'yonkeGuidId': 'yonke-7'},
      });

      expect(result.hasUsableSession, isTrue);
      expect(result.yonkeId, 'yonke-7');
      expect(result.expiresAt, _jwtExpiry);
    });

    test('stays pending when the response has no token', () {
      final result = YonkeLoginResult.fromResponse({
        'success': false,
        'message': 'Credenciales inválidas',
      });

      expect(result.hasUsableSession, isFalse);
      expect(result.sessionContractPending, isTrue);
    });
  });
}
