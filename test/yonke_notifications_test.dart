import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/yonke_notifications/presentation/yonke_notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sin configuración de Firebase lo informa sin simular avisos', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(
            _MemoryTokenStore(accessToken: 'token', yonkeGuidId: 'yonke-1'),
          ),
        ],
        child: const MaterialApp(home: YonkeNotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Avisos push no configurados'), findsOneWidget);
  });

  testWidgets('sin guid del yonke pide volver a iniciar sesión', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(
            _MemoryTokenStore(accessToken: 'token'),
          ),
        ],
        child: const MaterialApp(home: YonkeNotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notificaciones pendientes de sesión'), findsOneWidget);
  });
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore({this.accessToken, this.yonkeGuidId});

  String? accessToken;
  String? yonkeGuidId;

  @override
  Future<void> clear() async {
    accessToken = null;
    yonkeGuidId = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

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
    this.accessToken = accessToken;
    this.yonkeGuidId = yonkeGuidId;
  }
}
