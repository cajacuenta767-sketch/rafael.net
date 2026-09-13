import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_yonke/app/theme/yonke_theme.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_requests_repository.dart';
import 'package:app_yonke/features/yonke_requests/domain/yonke_request_summary.dart';
import 'package:app_yonke/features/yonke_requests/presentation/yonke_requests_page.dart';

class _ScreenshotRequestsRepo implements YonkeRequestsRepository {
  @override
  Future<YonkeRequestsPageResult> getAssignedRequests({
    required int page,
    required int pageSize,
    String? search,
    YonkeRequestFilters filters = const YonkeRequestFilters(),
  }) async {
    return YonkeRequestsPageResult(
      items: [
        YonkeRequestSummary(
          requestId: 'req-1',
          requestYonkeId: 'ry-1',
          part: 'Faro delantero izquierdo',
          brand: 'Toyota',
          model: 'Corolla',
          year: 2020,
          city: 'Guadalajara, Jal.',
          folio: 'SOL-2024-001',
          status: YonkeRequestStatus.newRequest,
          receivedAt: DateTime.now().subtract(const Duration(minutes: 15)),
          photoCount: 2,
        ),
        YonkeRequestSummary(
          requestId: 'req-2',
          requestYonkeId: 'ry-2',
          part: 'Alternador',
          brand: 'Chevrolet',
          model: 'Silverado',
          year: 2018,
          city: 'Zapopan, Jal.',
          folio: 'SOL-2024-002',
          status: YonkeRequestStatus.newRequest,
          receivedAt: DateTime.now().subtract(const Duration(hours: 1)),
          photoCount: 1,
        ),
        YonkeRequestSummary(
          requestId: 'req-3',
          requestYonkeId: 'ry-3',
          part: 'Bomba de gasolina',
          brand: 'Nissan',
          model: 'Versa',
          year: 2019,
          city: 'Tlaquepaque, Jal.',
          folio: 'SOL-2024-003',
          status: YonkeRequestStatus.viewed,
          receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
          photoCount: 3,
        ),
        YonkeRequestSummary(
          requestId: 'req-4',
          requestYonkeId: 'ry-4',
          part: 'Espejo lateral derecho',
          brand: 'Honda',
          model: 'Civic',
          year: 2021,
          city: 'Guadalajara, Jal.',
          folio: 'SOL-2024-004',
          status: YonkeRequestStatus.quoted,
          receivedAt: DateTime.now().subtract(const Duration(hours: 4)),
          photoCount: 1,
        ),
      ],
      page: 1,
      hasMore: false,
    );
  }

  @override
  Future<void> markAsViewed(String requestYonkeId) async {}
}

void main() {
  testWidgets('capture YonkeRequestsPage screenshot', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repaintBoundaryKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: YonkeColors.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: YonkeColors.primaryNavy,
              primary: YonkeColors.primaryNavy,
              surface: Colors.white,
            ),
          ),
          home: RepaintBoundary(
            key: repaintBoundaryKey,
            child: YonkeRequestsPage(repository: _ScreenshotRequestsRepo()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary =
          repaintBoundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        File('build/yonke_requests_screenshot.png').writeAsBytesSync(bytes);
      }
    });
  });
}
