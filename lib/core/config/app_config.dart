import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: 'voghc370q9c4u041pric7f2lqvb606kg.apps.googleusercontent.com',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://refanetwebapi-a4dhhqd0d7hseqds.westus2-01.azurewebsites.net',
  );

  static const environmentName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static bool get enableNetworkLogs =>
      kDebugMode && const bool.fromEnvironment('ENABLE_NETWORK_LOGS');

  static bool get enableMockAuth =>
      kDebugMode && const bool.fromEnvironment('MOCK_AUTH', defaultValue: true);

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 30);
}
