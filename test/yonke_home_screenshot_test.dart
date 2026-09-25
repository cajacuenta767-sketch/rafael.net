import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_yonke/features/yonke_home/presentation/yonke_home_page.dart';
import 'package:app_yonke/features/yonke_requests/domain/yonke_request_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the complete yonke home dashboard', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    final requests = [
      YonkeRequestSummary(
        requestId: 'request-1',
        requestYonkeId: 'assigned-1',
        part: 'Alternador Nissan Sentra 2018',
        status: YonkeRequestStatus.newRequest,
        receivedAt: DateTime(2026, 9, 8, 9, 30),
        brand: 'Nissan',
        model: 'Sentra',
        year: 2018,
        city: 'Nogales, Sonora',
      ),
      YonkeRequestSummary(
        requestId: 'request-2',
        requestYonkeId: 'assigned-2',
        part: 'Compresor A/C Chevrolet Aveo 2016',
        status: YonkeRequestStatus.viewed,
        receivedAt: DateTime(2026, 9, 8, 8, 45),
        city: 'Hermosillo, Sonora',
      ),
      YonkeRequestSummary(
        requestId: 'request-3',
        requestYonkeId: 'assigned-3',
        part: 'Motor de arranque Toyota Corolla 2015',
        status: YonkeRequestStatus.quoted,
        receivedAt: DateTime(2026, 9, 7, 16, 15),
        city: 'Agua Prieta, Sonora',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: boundaryKey,
            child: YonkeHomePage(
              dataLoader: () async => YonkeHomeData(
                requests: requests,
                quoteCount: 14,
                unreadMessages: 5,
                businessName: 'Yonke El Profe',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('¡Hola, Yonke El Profe! 👋'), findsOneWidget);
    expect(find.text('Solicitudes recientes'), findsOneWidget);
    expect(find.text('Aumenta tus ventas'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/yonke_home_screenshot.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(data!.buffer.asUint8List());
    });
  });
}
