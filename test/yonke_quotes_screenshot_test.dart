import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_yonke/app/theme/yonke_theme.dart';
import 'package:app_yonke/features/yonke_quotes/data/yonke_quotes_repository.dart';
import 'package:app_yonke/features/yonke_quotes/domain/yonke_quote.dart';
import 'package:app_yonke/features/yonke_quotes/presentation/yonke_quotes_page.dart';

class _ScreenshotQuotesRepo implements YonkeQuotesRepository {
  @override
  Future<YonkeQuotesPageResult> getMyQuotes({
    required int page,
    required int pageSize,
    String? search,
    YonkeQuoteFilters filters = const YonkeQuoteFilters(),
  }) async {
    return YonkeQuotesPageResult(
      items: [
        YonkeQuote(
          id: 'q-1',
          requestId: 'req-1',
          requestYonkeId: 'ry-1',
          part: 'Faro delantero izquierdo',
          brand: 'Toyota',
          model: 'Corolla',
          year: 2020,
          price: 1850.0,
          folio: 'COT-2024-015',
          status: YonkeQuoteStatus.accepted,
          available: true,
          active: true,
          isNew: false,
          hasWarranty: true,
          warrantyDays: 30,
          shippingAvailable: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          imageUrls: const [],
        ),
        YonkeQuote(
          id: 'q-2',
          requestId: 'req-2',
          requestYonkeId: 'ry-2',
          part: 'Alternador',
          brand: 'Chevrolet',
          model: 'Silverado',
          year: 2018,
          price: 2400.0,
          folio: 'COT-2024-014',
          status: YonkeQuoteStatus.sent,
          available: true,
          active: true,
          isNew: false,
          hasWarranty: true,
          warrantyDays: 60,
          shippingAvailable: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          imageUrls: const [],
        ),
        YonkeQuote(
          id: 'q-3',
          requestId: 'req-3',
          requestYonkeId: 'ry-3',
          part: 'Transmisión automática',
          brand: 'Nissan',
          model: 'Versa',
          year: 2019,
          price: 9500.0,
          folio: 'COT-2024-012',
          status: YonkeQuoteStatus.viewed,
          available: true,
          active: true,
          isNew: false,
          hasWarranty: true,
          warrantyDays: 90,
          shippingAvailable: false,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          imageUrls: const [],
        ),
      ],
      page: 1,
      hasMore: false,
    );
  }

  @override
  Future<YonkeQuote> getById(String quoteId) async =>
      throw UnimplementedError();
}

void main() {
  testWidgets('capture YonkeQuotesPage screenshot', (tester) async {
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
            child: YonkeQuotesPage(repository: _ScreenshotQuotesRepo()),
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
        File('build/yonke_quotes_screenshot.png').writeAsBytesSync(bytes);
      }
    });
  });
}
