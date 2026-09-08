import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_yonke/app/theme/yonke_theme.dart';
import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/features/auth/presentation/yonke_login_page.dart';
import 'package:app_yonke/features/auth/presentation/yonke_register_page.dart';
import 'package:app_yonke/features/catalogs/data/catalogs_api.dart';
import 'package:app_yonke/features/yonkes/data/yonkes_api.dart';

class _FakeCatalogsApi implements CatalogsApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<dynamic> getStates() async => {
    'data': [
      {'id': 26, 'entidad': 'Sonora'},
      {'id': 2, 'entidad': 'Baja California'},
    ],
  };

  @override
  Future<dynamic> getCitiesByState(int stateId) async => {
    'data': [
      {'id': 1, 'ciudad': 'Nogales'},
      {'id': 2, 'ciudad': 'Hermosillo'},
      {'id': 3, 'ciudad': 'Ciudad Obregón'},
    ],
  };
}

class _FakeYonkesApi implements YonkesApi {
  Map<String, dynamic>? lastRegisteredFields;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<dynamic> register({
    required Map<String, dynamic> fields,
    List<ApiFile> files = const [],
  }) async {
    lastRegisteredFields = fields;
    return {'success': true};
  }
}

void main() {
  testWidgets('renders YonkeRegisterPage and captures screenshot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeCatalogs = _FakeCatalogsApi();
    final fakeYonkes = _FakeYonkesApi();
    final key = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogsApiProvider.overrideWithValue(fakeCatalogs),
          yonkesApiProvider.overrideWithValue(fakeYonkes),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: YonkeColors.background,
          ),
          home: RepaintBoundary(key: key, child: const YonkeRegisterPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify fields exist
    expect(find.byKey(const Key('yonke-register-name')), findsOneWidget);
    expect(find.byKey(const Key('yonke-register-manager')), findsOneWidget);
    expect(find.byKey(const Key('yonke-register-phone')), findsOneWidget);
    expect(find.byKey(const Key('yonke-register-email')), findsOneWidget);
    expect(find.byKey(const Key('yonke-register-address')), findsOneWidget);
    expect(find.byKey(const Key('yonke-register-cp')), findsOneWidget);
    expect(find.byKey(const Key('yonke-register-password')), findsOneWidget);
    expect(
      find.byKey(const Key('yonke-register-confirm-password')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('yonke-register-submit')), findsOneWidget);

    // Save screenshot
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        File(
          r'C:\Users\PC\.gemini\antigravity\brain\8634c568-fc25-4f30-afbb-baf7c18b270e\yonke_register_screenshot.png',
        ).writeAsBytesSync(byteData.buffer.asUint8List());
      }
    });

    // Test form submission
    await tester.enterText(
      find.byKey(const Key('yonke-register-name')),
      'Yonke El Profe',
    );
    await tester.enterText(
      find.byKey(const Key('yonke-register-manager')),
      'Roberto Gomez',
    );
    await tester.enterText(
      find.byKey(const Key('yonke-register-phone')),
      '6621234567',
    );
    await tester.enterText(
      find.byKey(const Key('yonke-register-email')),
      'contacto@elprofe.com',
    );
    await tester.enterText(
      find.byKey(const Key('yonke-register-address')),
      'Av. Tecnologico 123',
    );
    await tester.enterText(find.byKey(const Key('yonke-register-cp')), '84000');
    await tester.enterText(
      find.byKey(const Key('yonke-register-password')),
      'Password123!',
    );
    await tester.enterText(
      find.byKey(const Key('yonke-register-confirm-password')),
      'Password123!',
    );

    await tester.ensureVisible(find.byKey(const Key('yonke-register-submit')));
    await tester.tap(find.byKey(const Key('yonke-register-submit')));
    await tester.pumpAndSettle();

    expect(find.text('¡Yonke registrado!'), findsOneWidget);
  });

  testWidgets('renders YonkeLoginPage with cropped logo and register button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFFAFBFD),
          ),
          home: RepaintBoundary(key: key, child: const YonkeLoginPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('yonke-go-register-button')), findsOneWidget);
    expect(find.text('Registra tu Yonke'), findsOneWidget);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        File(
          r'C:\Users\PC\.gemini\antigravity\brain\8634c568-fc25-4f30-afbb-baf7c18b270e\yonke_login_screenshot.png',
        ).writeAsBytesSync(byteData.buffer.asUint8List());
      }
    });
  });
}
