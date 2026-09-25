import 'dart:async';

import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_endpoints.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/push/push_service.dart';
import 'package:app_yonke/core/realtime/realtime_service.dart';
import 'package:app_yonke/core/session/session_events.dart';
import 'package:app_yonke/core/storage/notifying_token_store.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/auth/data/auth_api.dart';
import 'package:app_yonke/features/yonkes/data/yonkes_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('registro de push', () {
    PushService service(
      _RecordingClient client,
      _MemoryTokenStore tokens, {
      _FakePushPlatform? platform,
    }) => PushService(
      platform: platform ?? _FakePushPlatform(),
      tokens: tokens,
      authApi: AuthApi(client),
      yonkesApi: YonkesApi(client),
    );

    test('el cliente usa ClienteAuth/registrar-dispositivo', () async {
      final client = _RecordingClient();
      final push = service(client, _MemoryTokenStore(token: 'jwt'));

      await push.registerCurrentSession();

      expect(client.posts.keys, [ApiEndpoints.registerClientDevice]);
      expect(client.posts.values.single, containsPair('firebaseToken', 'fcm'));
      expect(push.status.value, PushStatus.registered);
    });

    test('el yonke usa YonkesDispositivos con su guid', () async {
      final client = _RecordingClient();
      final push = service(
        client,
        _MemoryTokenStore(token: 'jwt', yonkeGuidId: 'yonke-1'),
      );

      await push.registerCurrentSession();

      expect(client.posts.keys, [ApiEndpoints.yonkeDevices]);
      expect(
        client.posts.values.single,
        containsPair('yonkeGuidId', 'yonke-1'),
      );
    });

    test('sin sesión o con sesión de prueba no registra', () async {
      final client = _RecordingClient();
      await service(client, _MemoryTokenStore()).registerCurrentSession();
      await service(
        client,
        _MemoryTokenStore(token: 'development-client-session'),
      ).registerCurrentSession();

      expect(client.posts, isEmpty);
    });

    test('sin Firebase configurado lo informa sin llamar al API', () async {
      final client = _RecordingClient();
      final push = service(
        client,
        _MemoryTokenStore(token: 'jwt'),
        platform: _FakePushPlatform(configured: false),
      );

      await push.registerCurrentSession();

      expect(client.posts, isEmpty);
      expect(push.status.value, PushStatus.notConfigured);
    });

    test('guarda los avisos recibidos y entrega los tocados', () async {
      final platform = _FakePushPlatform();
      final push = service(
        _RecordingClient(),
        _MemoryTokenStore(token: 'jwt'),
        platform: platform,
      );
      await push.registerCurrentSession();
      final opened = push.openedNotices.first;

      platform.foreground.add(
        PushNotice.fromParts(
          title: 'Nueva solicitud',
          data: {'Tipo': 'NuevaSolicitud', 'SolicitudGuidId': 's1'},
        ),
      );
      platform.opened.add(
        PushNotice.fromParts(
          title: 'Nuevo mensaje del cliente',
          data: {'tipo': 'nuevo_mensaje', 'cotizacionGuidId': 'q1'},
        ),
      );
      final notice = await opened;

      expect(notice.isNewMessage, isTrue);
      expect(notice.targetId, 'q1');
      expect(push.inbox.value.map((n) => n.title), [
        'Nuevo mensaje del cliente',
        'Nueva solicitud',
      ]);
      expect(push.inbox.value.last.isNewRequest, isTrue);
    });
  });

  test('NotifyingTokenStore avisa el inicio y el cierre de sesión', () async {
    final store = NotifyingTokenStore(_MemoryTokenStore());
    final signedIn = SessionEvents.signedIn.first;
    await store.writeTokens(accessToken: 'jwt');
    await signedIn.timeout(const Duration(seconds: 1));

    final signedOut = SessionEvents.signedOut.first;
    await store.clear();
    await signedOut.timeout(const Duration(seconds: 1));
    expect(await store.readAccessToken(), isNull);
  });

  test('NuevoMensaje de SignalR indica la cotización', () {
    expect(
      quoteIdFromHubMessage([
        {'solicitudCotizacionGuidId': 'q1', 'mensaje': 'Hola'},
      ]),
      'q1',
    );
    expect(quoteIdFromHubMessage(null), isNull);
    expect(quoteIdFromHubMessage(['texto']), isNull);
  });
}

class _FakePushPlatform implements PushPlatform {
  _FakePushPlatform({this.configured = true});

  final bool configured;
  final foreground = StreamController<PushNotice>.broadcast();
  final opened = StreamController<PushNotice>.broadcast();

  @override
  Future<bool> initialize() async => configured;

  @override
  Future<String?> requestToken() async => 'fcm';

  @override
  Future<void> deleteToken() async {}

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<PushNotice> get foregroundMessages => foreground.stream;

  @override
  Stream<PushNotice> get openedMessages => opened.stream;

  @override
  Future<PushNotice?> initialMessage() async => null;
}

class _RecordingClient implements ApiClient {
  final posts = <String, Map<dynamic, dynamic>>{};

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    posts[path] = data as Map;
    return {'success': true};
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) =>
      throw UnimplementedError(path);

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => throw UnimplementedError(path);

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => throw UnimplementedError(path);

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) => throw UnimplementedError(path);
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore({this.token, this.yonkeGuidId});

  String? token;
  String? yonkeGuidId;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<DateTime?> readExpiresAt() async => null;

  @override
  Future<String?> readYonkeGuidId() async => yonkeGuidId;

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async {
    token = accessToken;
    this.yonkeGuidId = yonkeGuidId;
  }

  @override
  Future<void> clear() async {
    token = null;
    yonkeGuidId = null;
  }
}
