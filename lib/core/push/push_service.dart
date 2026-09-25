import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/data/auth_api.dart';
import '../../features/yonkes/data/yonkes_api.dart';
import '../config/app_config.dart';
import '../storage/token_store.dart';

/// Aviso recibido por push. `type` y `targetId` salen del bloque `data` que
/// manda el API: `NuevaSolicitud` + `SolicitudGuidId` para el yonke y
/// `nuevo_mensaje` + `cotizacionGuidId` para ambos roles.
class PushNotice {
  const PushNotice({
    required this.title,
    required this.body,
    required this.receivedAt,
    this.type,
    this.targetId,
  });

  final String title;
  final String body;
  final DateTime receivedAt;
  final String? type;
  final String? targetId;

  bool get isNewRequest => type?.toLowerCase() == 'nuevasolicitud';
  bool get isNewMessage => type?.toLowerCase() == 'nuevo_mensaje';

  factory PushNotice.fromParts({
    String? title,
    String? body,
    Map<String, dynamic> data = const {},
    DateTime? receivedAt,
  }) {
    String? read(List<String> keys) {
      for (final key in keys) {
        final value = data[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    return PushNotice(
      title: title?.trim().isNotEmpty == true ? title!.trim() : 'Refanet',
      body: body?.trim() ?? '',
      receivedAt: receivedAt ?? DateTime.now(),
      type: read(const ['Tipo', 'tipo', 'type']),
      targetId: read(const [
        'cotizacionGuidId',
        'CotizacionGuidId',
        'SolicitudGuidId',
        'solicitudGuidId',
      ]),
    );
  }
}

/// Lo que la app necesita del proveedor de push. La implementación real usa
/// Firebase Cloud Messaging; las pruebas usan una falsa.
abstract interface class PushPlatform {
  /// Inicializa el proveedor. `false` si no está configurado o falla.
  Future<bool> initialize();

  /// Pide permiso y devuelve el token del dispositivo, o `null`.
  Future<String?> requestToken();

  Future<void> deleteToken();

  Stream<String> get tokenRefreshes;
  Stream<PushNotice> get foregroundMessages;
  Stream<PushNotice> get openedMessages;
  Future<PushNotice?> initialMessage();
}

/// Registra el dispositivo en el API según el rol de la sesión y reparte los
/// avisos recibidos a la app.
class PushService {
  PushService({
    required this._platform,
    required this._tokens,
    required this._authApi,
    required this._yonkesApi,
  });

  final PushPlatform _platform;
  final TokenStore _tokens;
  final AuthApi _authApi;
  final YonkesApi _yonkesApi;

  /// Avisos recibidos en esta ejecución, del más reciente al más antiguo.
  final inbox = ValueNotifier<List<PushNotice>>(const []);
  final _opened = StreamController<PushNotice>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  Future<bool>? _ready;
  String? _registeredToken;

  /// Estado para la pantalla de notificaciones.
  final status = ValueNotifier<PushStatus>(PushStatus.unknown);

  /// Avisos que el usuario tocó; la app navega a su pantalla.
  Stream<PushNotice> get openedNotices => _opened.stream;

  Future<bool> _ensureReady() => _ready ??= _start();

  Future<bool> _start() async {
    if (!await _platform.initialize()) {
      status.value = PushStatus.notConfigured;
      return false;
    }
    _subscriptions
      ..add(_platform.foregroundMessages.listen(_remember))
      ..add(
        _platform.openedMessages.listen((notice) {
          _remember(notice);
          _opened.add(notice);
        }),
      )
      ..add(_platform.tokenRefreshes.listen((_) => registerCurrentSession()));
    final initial = await _platform.initialMessage();
    if (initial != null) {
      _remember(initial);
      // Se entrega después de que la app monte su navegación.
      scheduleMicrotask(() => _opened.add(initial));
    }
    return true;
  }

  /// Registra el token del dispositivo para la sesión guardada: el yonke en
  /// `POST /api/YonkesDispositivos` y el cliente en
  /// `POST /api/ClienteAuth/registrar-dispositivo`. Nunca interrumpe el
  /// flujo de la app: un fallo solo deja el push sin registrar.
  Future<void> registerCurrentSession() async {
    try {
      final accessToken = await _tokens.readAccessToken();
      if (accessToken == null || accessToken.isEmpty) return;
      if (!await _ensureReady()) return;
      final token = await _platform.requestToken();
      if (token == null || token.isEmpty) {
        status.value = PushStatus.permissionDenied;
        return;
      }
      final platformName = devicePlatformName();
      final yonkeId = await _tokens.readYonkeGuidId();
      if (yonkeId != null && yonkeId.isNotEmpty) {
        await _yonkesApi.registerDevice(
          yonkeId: yonkeId,
          firebaseToken: token,
          platform: platformName,
          model: 'Refanet $platformName',
        );
      } else {
        await _authApi.registerClientDevice(
          firebaseToken: token,
          platform: platformName,
          model: 'Refanet $platformName',
        );
      }
      _registeredToken = token;
      status.value = PushStatus.registered;
    } catch (error) {
      status.value = PushStatus.registrationFailed;
      if (kDebugMode) {
        debugPrint('[push] No se registró el dispositivo: $error');
      }
    }
  }

  /// Al cerrar sesión se invalida el token para que el servidor deje de
  /// enviar avisos de esa cuenta a este dispositivo (el API no publica una
  /// operación para dar de baja el dispositivo).
  Future<void> unregister() async {
    inbox.value = const [];
    if (_registeredToken == null) return;
    _registeredToken = null;
    try {
      await _platform.deleteToken();
    } catch (_) {}
    status.value = PushStatus.unknown;
  }

  void _remember(PushNotice notice) {
    inbox.value = [notice, ...inbox.value].take(50).toList(growable: false);
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _opened.close();
  }
}

enum PushStatus {
  unknown,
  notConfigured,
  permissionDenied,
  registrationFailed,
  registered,
}

String devicePlatformName() => switch (defaultTargetPlatform) {
  TargetPlatform.iOS => 'iOS',
  TargetPlatform.android => 'Android',
  _ => defaultTargetPlatform.name,
};

/// Firebase Cloud Messaging con las opciones de `--dart-define`.
class FirebasePushPlatform implements PushPlatform {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<bool> initialize() async {
    if (!AppConfig.pushConfigured || kIsWeb) return false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: AppConfig.firebaseApiKey,
            appId: AppConfig.firebaseAppId,
            messagingSenderId: AppConfig.firebaseSenderId,
            projectId: AppConfig.firebaseProjectId,
            iosBundleId: AppConfig.firebaseIosBundleId,
          ),
        );
      }
      return true;
    } catch (error) {
      if (kDebugMode) debugPrint('[push] Firebase no inicializó: $error');
      return false;
    }
  }

  @override
  Future<String?> requestToken() async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    return _messaging.getToken();
  }

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Stream<PushNotice> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(_notice);

  @override
  Stream<PushNotice> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map(_notice);

  @override
  Future<PushNotice?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _notice(message);
  }

  static PushNotice _notice(RemoteMessage message) => PushNotice.fromParts(
    title: message.notification?.title,
    body: message.notification?.body,
    data: message.data,
    receivedAt: message.sentTime,
  );
}
