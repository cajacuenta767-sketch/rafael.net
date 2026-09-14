import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_yonke/app/theme/yonke_theme.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/yonke_messages/data/yonke_messages_repository.dart';
import 'package:app_yonke/features/yonke_messages/domain/yonke_message.dart';
import 'package:app_yonke/features/yonke_messages/presentation/yonke_messages_page.dart';
import 'package:app_yonke/features/yonke_profile/data/yonke_profile_repository.dart';
import 'package:app_yonke/features/yonke_profile/domain/yonke_profile.dart';
import 'package:app_yonke/features/yonke_profile/presentation/yonke_profile_page.dart';
import 'package:app_yonke/features/yonke_quotes/domain/yonke_quote.dart';

class _ScreenshotMessagesRepo implements YonkeMessagesRepository {
  @override
  Future<List<YonkeMessagePreview>> getInbox() async {
    final now = DateTime.now();
    return [
      YonkeMessagePreview(
        quote: YonkeQuote(
          id: 'q-1',
          requestId: 'r-1',
          requestYonkeId: 'ry-1',
          part: 'Faro delantero izquierdo',
          brand: 'Toyota',
          model: 'Corolla',
          year: 2020,
          price: 1850,
          folio: 'COT-015',
          status: YonkeQuoteStatus.accepted,
          available: true,
          active: true,
          isNew: false,
          hasWarranty: true,
          warrantyDays: 30,
          shippingAvailable: true,
          createdAt: now.subtract(const Duration(hours: 2)),
          imageUrls: const [],
        ),
        clientLabel: 'Carlos Mendoza',
        lastMessage: '¿Aceptas transferencia bancaria?',
        lastMessageAt: now.subtract(const Duration(minutes: 18)),
        unreadCount: 2,
      ),
      YonkeMessagePreview(
        quote: YonkeQuote(
          id: 'q-2',
          requestId: 'r-2',
          requestYonkeId: 'ry-2',
          part: 'Alternador',
          brand: 'Chevrolet',
          model: 'Silverado',
          year: 2018,
          price: 2400,
          folio: 'COT-014',
          status: YonkeQuoteStatus.sent,
          available: true,
          active: true,
          isNew: false,
          hasWarranty: true,
          warrantyDays: 60,
          shippingAvailable: true,
          createdAt: now.subtract(const Duration(hours: 5)),
          imageUrls: const [],
        ),
        clientLabel: 'Taller Mecánico El Rayo',
        lastMessage: 'Perfecto, hoy paso por él a las 3 pm.',
        lastMessageAt: now.subtract(const Duration(hours: 1)),
        unreadCount: 0,
      ),
      YonkeMessagePreview(
        quote: YonkeQuote(
          id: 'q-3',
          requestId: 'r-3',
          requestYonkeId: 'ry-3',
          part: 'Bomba de gasolina',
          brand: 'Nissan',
          model: 'Versa',
          year: 2019,
          price: 1500,
          folio: 'COT-010',
          status: YonkeQuoteStatus.viewed,
          available: true,
          active: true,
          isNew: false,
          hasWarranty: true,
          warrantyDays: 30,
          shippingAvailable: false,
          createdAt: now.subtract(const Duration(days: 1)),
          imageUrls: const [],
        ),
        clientLabel: 'Alejandro Ramos',
        lastMessage: '¿La bomba incluye el flotador completo?',
        lastMessageAt: now.subtract(const Duration(hours: 4)),
        unreadCount: 1,
      ),
    ];
  }

  @override
  Future<List<YonkeQuoteMessage>> getConversation(String quoteId) async => [];

  @override
  Future<void> sendMessage({
    required String quoteId,
    required String message,
  }) async {}
}

class _ScreenshotProfileRepo implements YonkeProfileRepository {
  @override
  Future<YonkeProfileSnapshot> load() async {
    return const YonkeProfileSnapshot(
      availability: YonkeProfileAvailability.available,
      profile: YonkeProfile(
        guidId: 'yonke-guid-1',
        name: 'Yonke El Profe',
        phone: '+52 631 123 4567',
        address: 'Periférico Luis Donaldo Colosio #1420',
        email: 'contacto@yonkelprofe.com',
        city: 'Nogales, Sonora',
        postalCode: 84000,
      ),
    );
  }
}

class _FakeTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> readAccessToken() async => 'test';
  @override
  Future<DateTime?> readExpiresAt() async => null;
  @override
  Future<String?> readRefreshToken() async => null;
  @override
  Future<String?> readYonkeGuidId() async => 'yonke-1';
  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async {}
}

void main() {
  testWidgets('capture YonkeMessagesPage screenshot', (tester) async {
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
            scaffoldBackgroundColor: YonkeColors.background,
          ),
          home: RepaintBoundary(
            key: key,
            child: YonkeMessagesPage(repository: _ScreenshotMessagesRepo()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final output = File('build/yonke_messages_screenshot.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(byteData.buffer.asUint8List());
      }
    });
  });

  testWidgets('capture YonkeProfilePage screenshot', (tester) async {
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
            scaffoldBackgroundColor: YonkeColors.background,
          ),
          home: RepaintBoundary(
            key: key,
            child: YonkeProfilePage(
              repository: _ScreenshotProfileRepo(),
              tokenStore: _FakeTokenStore(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final output = File('build/yonke_profile_screenshot.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(byteData.buffer.asUint8List());
      }
    });
  });
}
