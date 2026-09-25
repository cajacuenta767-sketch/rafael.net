import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '827459519810-buquild6jnjmi2nr5g4hhg25kqv3ck2j.apps.googleusercontent.com',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://refanetwebapi-a4dhhqd0d7hseqds.westus2-01.azurewebsites.net',
  );

  /// Ruta del hub de SignalR (`SignalR:HubPath` en el API).
  static const signalRHubPath = String.fromEnvironment(
    'SIGNALR_HUB_PATH',
    defaultValue: '/hubs/notificaciones',
  );

  /// Configuración de Firebase para las notificaciones push. Se pasa con
  /// `--dart-define` (ver docs/INTEGRACION_API.md); sin ella la app funciona
  /// y solo desactiva el push.
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseIosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.refanet.app',
  );

  static bool get pushConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  static const environmentName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static bool get enableNetworkLogs =>
      kDebugMode && const bool.fromEnvironment('ENABLE_NETWORK_LOGS');

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 30);
  static const sendTimeout = Duration(seconds: 60);

  static bool get isProduction => environmentName == 'production';
}
