import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_yonke/core/network/api_endpoints.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/core/network/dio_api_client.dart';
import 'package:app_yonke/core/session/session_events.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/requests/domain/client_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hasActiveSession', () {
    final now = DateTime.utc(2026, 9, 25, 12);

    test('sin token no hay sesión', () async {
      expect(await hasActiveSession(_MemoryTokenStore(), now: now), isFalse);
    });

    test('token sin expiración informada sigue activo', () async {
      final store = _MemoryTokenStore(token: 'jwt');
      expect(await hasActiveSession(store, now: now), isTrue);
    });

    test('token vencido se borra', () async {
      final store = _MemoryTokenStore(
        token: 'jwt',
        expiresAt: now.subtract(const Duration(minutes: 1)),
      );
      expect(await hasActiveSession(store, now: now), isFalse);
      expect(store.token, isNull);
    });

    test('token vigente sigue activo', () async {
      final store = _MemoryTokenStore(
        token: 'jwt',
        expiresAt: now.add(const Duration(hours: 1)),
      );
      expect(await hasActiveSession(store, now: now), isTrue);
    });
  });

  group('401 del servidor', () {
    Dio dioReturning(int status) =>
        Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = _StatusAdapter(status);

    test('con token enviado cierra la sesión y avisa', () async {
      final store = _MemoryTokenStore(token: 'jwt');
      final client = DioApiClient(store, dio: dioReturning(401));
      final expired = SessionEvents.expired.first.timeout(
        const Duration(seconds: 1),
      );

      await expectLater(
        client.get(ApiEndpoints.dashboardRequests),
        throwsA(
          isA<ApiException>().having((e) => e.isUnauthorized, '401', isTrue),
        ),
      );
      await expired;
      expect(store.token, isNull);
    });

    test('un login rechazado no borra nada', () async {
      final store = _MemoryTokenStore(token: 'jwt');
      final client = DioApiClient(store, dio: dioReturning(401));
      var notified = false;
      final subscription = SessionEvents.expired.listen((_) => notified = true);

      await expectLater(
        client.post(ApiEndpoints.yonkeLogin, data: const {}),
        throwsA(isA<ApiException>()),
      );
      await subscription.cancel();
      expect(notified, isFalse);
      expect(store.token, 'jwt');
    });

    test('otros errores no cierran la sesión', () async {
      final store = _MemoryTokenStore(token: 'jwt');
      final client = DioApiClient(store, dio: dioReturning(500));

      await expectLater(
        client.get(ApiEndpoints.dashboardRequests),
        throwsA(isA<ApiException>()),
      );
      expect(store.token, 'jwt');
    });
  });

  test('las imágenes de la solicitud exponen su guid por URL', () {
    expect(
      requestImageIdsFromResponse({
        'data': [
          {'guidId': 'img-1', 'urlImagen': 'https://cdn.example.com/1.jpg'},
          {'urlImagen': 'https://cdn.example.com/2.jpg'},
        ],
      }),
      {'https://cdn.example.com/1.jpg': 'img-1'},
    );
  });
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'message': 'Error $status'}),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore({this.token, this.expiresAt});

  String? token;
  DateTime? expiresAt;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<DateTime?> readExpiresAt() async => expiresAt;

  @override
  Future<String?> readYonkeGuidId() async => null;

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async {
    token = accessToken;
    this.expiresAt = expiresAt;
  }

  @override
  Future<void> clear() async {
    token = null;
    expiresAt = null;
  }
}
