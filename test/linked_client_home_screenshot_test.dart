import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/home/presentation/role_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders client home with the same linked demo requests', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(
            _DemoTokenStore('development-client-session'),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: boundaryKey,
            child: const RoleHomePage.client(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Solicitudes recientes'), findsOneWidget);
    expect(find.text('Alternador'), findsOneWidget);
    expect(find.text('Compresor A/C'), findsOneWidget);
    expect(find.text('Transmisión automática'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/linked_client_home_screenshot.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
    });
  });
}

class _DemoTokenStore implements TokenStore {
  _DemoTokenStore(this.accessToken);
  String? accessToken;

  @override
  Future<String?> readAccessToken() async => accessToken;
  @override
  Future<String?> readRefreshToken() async => null;
  @override
  Future<DateTime?> readExpiresAt() async => null;
  @override
  Future<String?> readYonkeGuidId() async => 'demo-yonke';
  @override
  Future<void> clear() async => accessToken = null;
  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async => this.accessToken = accessToken;
}
