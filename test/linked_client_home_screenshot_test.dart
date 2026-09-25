import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/home/presentation/role_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders client home with the requests from the API', (
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
          tokenStoreProvider.overrideWithValue(_DemoTokenStore('jwt')),
          apiClientProvider.overrideWithValue(_DashboardApi()),
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
  Future<String?> readYonkeGuidId() async => null;
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

/// `mis-solicitudes` del cliente con la forma de `Solicitud_Busqueda_DTO`.
class _DashboardApi implements ApiClient {
  static Map<String, Object> _request(String id, String part, int day) => {
    'guidId': id,
    'piezaBuscada': part,
    'marca': 'Nissan',
    'modelo': 'Sentra',
    'año': 2015,
    'estatusSolicitud': 'Enviada',
    'folio': 'SOL-2026090$day',
    'fechaCreacion': '2026-09-0${day}T10:00:00Z',
    'totalCotizaciones': 1,
  };

  static final _requests = {
    'success': true,
    'data': {
      'data': [
        _request('s1', 'Alternador', 3),
        _request('s2', 'Compresor A/C', 2),
        _request('s3', 'Transmisión automática', 1),
      ],
    },
  };

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => switch (path) {
    '/api/DashboardSuscriptores/mis-solicitudes' => _requests,
    _ => {'success': true, 'data': <Object>[]},
  };

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => {'success': true};

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => {'success': true};

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => {'success': true};

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) async => {'success': true};
}
