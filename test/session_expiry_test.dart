import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_yonke/core/network/api_endpoints.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/core/network/dio_api_client.dart';
import 'package:app_yonke/core/session/session_events.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/auth/domain/session_payload.dart';
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

  group('la sesión no se cierra sin confirmar que el token venció', () {
    DioApiClient clientWith(
      _MemoryTokenStore store,
      _ScriptedAdapter adapter,
    ) => DioApiClient(
      store,
      dio: Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );

    Future<bool> expiredEmitted(Future<void> Function() action) async {
      var notified = false;
      final subscription = SessionEvents.expired.listen((_) => notified = true);
      try {
        await action();
      } catch (_) {}
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      return notified;
    }

    test('un 302 hacia /Account/Login conserva la sesión', () async {
      final store = _MemoryTokenStore(token: 'jwt');
      final adapter = _ScriptedAdapter({
        ApiEndpoints.request('x'): _Reply(
          302,
          headers: {
            'location': ['https://api.test/Account/Login?ReturnUrl=%2Fapi'],
          },
        ),
      });

      final notified = await expiredEmitted(
        () => clientWith(store, adapter).get(ApiEndpoints.request('x')),
      );

      expect(notified, isFalse);
      expect(store.token, 'jwt');
      expect(adapter.calls, isNot(contains(ApiEndpoints.pagedYonkes)));
    });

    test('401 con invalid_token cierra la sesión sin comprobar', () async {
      final store = _MemoryTokenStore(token: 'jwt');
      final adapter = _ScriptedAdapter({
        ApiEndpoints.dashboardRequests: _Reply(
          401,
          headers: {
            'www-authenticate': [
              'Bearer error="invalid_token", error_description="expired"',
            ],
          },
        ),
      });

      final notified = await expiredEmitted(
        () => clientWith(store, adapter).get(ApiEndpoints.dashboardRequests),
      );

      expect(notified, isTrue);
      expect(store.token, isNull);
      expect(adapter.calls, isNot(contains(ApiEndpoints.pagedYonkes)));
    });

    test('401 de un endpoint pero el token sigue sirviendo', () async {
      final store = _MemoryTokenStore(token: 'jwt');
      final adapter = _ScriptedAdapter({
        ApiEndpoints.registerClientDevice: _Reply(401),
        ApiEndpoints.pagedYonkes: _Reply(200),
      });

      final notified = await expiredEmitted(
        () => clientWith(
          store,
          adapter,
        ).post(ApiEndpoints.registerClientDevice, data: const {}),
      );

      expect(notified, isFalse);
      expect(store.token, 'jwt');
    });

    test('401 confirmado por la comprobación cierra la sesión', () async {
      final store = _MemoryTokenStore(token: 'jwt');
      final adapter = _ScriptedAdapter({
        ApiEndpoints.dashboardRequests: _Reply(401),
        ApiEndpoints.pagedYonkes: _Reply(401),
      });

      final notified = await expiredEmitted(
        () => clientWith(store, adapter).get(ApiEndpoints.dashboardRequests),
      );

      expect(notified, isTrue);
      expect(store.token, isNull);
    });

    test('sin red para comprobar, la sesión se conserva', () async {
      final store = _MemoryTokenStore(token: 'jwt');
      final adapter = _ScriptedAdapter({
        ApiEndpoints.dashboardRequests: _Reply(401),
      }, failUnknown: true);

      final notified = await expiredEmitted(
        () => clientWith(store, adapter).get(ApiEndpoints.dashboardRequests),
      );

      expect(notified, isFalse);
      expect(store.token, 'jwt');
    });

    test('token vencido por exp cierra la sesión', () async {
      final store = _MemoryTokenStore(
        token: 'jwt',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );
      final adapter = _ScriptedAdapter({
        ApiEndpoints.dashboardRequests: _Reply(401),
      });

      final notified = await expiredEmitted(
        () => clientWith(store, adapter).get(ApiEndpoints.dashboardRequests),
      );

      expect(notified, isTrue);
      expect(adapter.calls, isNot(contains(ApiEndpoints.pagedYonkes)));
    });

    test('varios 401 simultáneos hacen una sola comprobación', () async {
      final store = _MemoryTokenStore(token: 'jwt');
      final adapter = _ScriptedAdapter({
        ApiEndpoints.dashboardRequests: _Reply(401),
        ApiEndpoints.dashboardQuotes: _Reply(401),
        ApiEndpoints.pagedYonkes: _Reply(200, delay: true),
      });
      final client = clientWith(store, adapter);

      await Future.wait([
        client.get(ApiEndpoints.dashboardRequests).catchError((_) => null),
        client.get(ApiEndpoints.dashboardQuotes).catchError((_) => null),
      ]);

      expect(
        adapter.calls.where((path) => path == ApiEndpoints.pagedYonkes),
        hasLength(1),
      );
      expect(store.token, 'jwt');
    });

    test('exp del JWT se interpreta en segundos UTC', () {
      final exp = DateTime.utc(2026, 10, 25, 12).millisecondsSinceEpoch ~/ 1000;
      String part(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final token = '${part({'alg': 'HS256'})}.${part({'exp': exp})}.firma';

      expect(
        SessionResponseParser.expiryFromClaims(token),
        DateTime.utc(2026, 10, 25, 12),
      );
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

class _Reply {
  _Reply(this.status, {this.headers = const {}, this.delay = false});

  final int status;
  final Map<String, List<String>> headers;
  final bool delay;
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.replies, {this.failUnknown = false});

  final Map<String, _Reply> replies;
  final bool failUnknown;
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options.path);
    final reply = replies[options.path];
    if (reply == null) {
      if (failUnknown) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'sin red',
        );
      }
      throw StateError('Ruta inesperada: ${options.path}');
    }
    if (reply.delay) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return ResponseBody.fromString(
      jsonEncode({'message': 'Error ${reply.status}'}),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...reply.headers,
      },
    );
  }

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
