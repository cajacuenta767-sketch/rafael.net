import 'dart:typed_data';

import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_endpoints.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/network/development_api_client.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/orders/data/client_orders_repository.dart';
import 'package:app_yonke/features/orders/data/orders_api.dart';
import 'package:app_yonke/features/yonke_home/presentation/yonke_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'links a client request and a yonke quote in development mode',
    () async {
      final tokens = _MemoryTokenStore('development-client-session');
      final api = DevelopmentApiClient(
        _UnexpectedRemote(),
        tokens,
        seedDemoData: true,
      );

      final initialClient =
          await api.get(ApiEndpoints.dashboardRequests) as Map;
      final clientRows = initialClient['data'] as List;
      expect(clientRows.length, greaterThanOrEqualTo(4));
      expect(
        clientRows.first['solicitudesImagenes'][0]['urlImagen'],
        startsWith('asset://assets/images/'),
      );

      final created = await api.post(
        ApiEndpoints.requests,
        data: {
          'marcaId': 1,
          'modeloId': 1,
          'año': 2022,
          'piezaBuscada': 'Puerta delantera derecha',
        },
      ) as Map;
      final requestId = created['data']['guidId'] as String;
      await api.post(ApiEndpoints.sendRequestToYonkes(requestId));

      final imagesBeforeUpload =
          await api.get(ApiEndpoints.requestImages(requestId)) as Map;
      expect(imagesBeforeUpload['data'], isEmpty);

      await api.multipart(
        ApiEndpoints.addRequestImage(requestId),
        method: 'POST',
        files: [
          ApiFile(
            fieldName: 'Imagenes',
            fileName: 'foto-cliente.jpg',
            bytes: Uint8List.fromList([255, 216, 255, 217]),
          ),
        ],
      );

      tokens.accessToken = 'development-yonke-session';
      final yonkeInbox = await api.get(ApiEndpoints.dashboardRequests) as Map;
      final assignments = yonkeInbox['data'] as List;
      expect(assignments.length, clientRows.length + 1);
      final assignment = assignments.firstWhere(
        (item) => item['solicitudGuidId'] == requestId,
      ) as Map;
      expect(
        assignment['solicitudes']['piezaBuscada'],
        'Puerta delantera derecha',
      );
      expect(
        assignment['solicitudes']['solicitudesImagenes'][0]['urlImagen'],
        startsWith('data:image/jpeg;base64,'),
      );

      await api.multipart(
        ApiEndpoints.quotes,
        method: 'POST',
        fields: {
          'Precio': 2750,
          'Disponible': true,
          'TieneGarantia': true,
          'DiasGarantia': 30,
        },
        queryParameters: {'solicitudYonkeGuidId': assignment['guidId']},
      );

      tokens.accessToken = 'development-client-session';
      final clientQuotes = await api.get(ApiEndpoints.dashboardQuotes) as Map;
      final linkedQuote = (clientQuotes['data'] as List).firstWhere(
        (item) => item['solicitudYonkes']['solicitudGuidId'] == requestId,
      ) as Map;
      expect(linkedQuote['precio'], 2750);
      expect(
        linkedQuote['solicitudCotizacionesImagenes'][0]['urlImagen'],
        assignment['solicitudes']['solicitudesImagenes'][0]['urlImagen'],
      );
      expect(
        linkedQuote['solicitudYonkes']['yonkes']['nombre'],
        'Yonke El Profe',
      );

      final quoteId = linkedQuote['guidId'] as String;
      final ordersRepository = ApiClientOrdersRepository(OrdersApi(api));
      expect(await ordersRepository.getForQuote(quoteId), isNull);
      await api.post(
        ApiEndpoints.quoteMessages,
        data: {
          'solicitudCotizacionGuidId': quoteId,
          'mensaje': '¿Incluye envío?',
        },
      );

      tokens.accessToken = 'development-yonke-session';
      var unread =
          await api.get(ApiEndpoints.unreadQuoteMessages(quoteId)) as Map;
      expect(unread['data']['cantidad'], 1);
      await api.get(ApiEndpoints.quoteConversation(quoteId));
      await api.put(ApiEndpoints.markQuoteMessagesRead(quoteId));
      unread = await api.get(ApiEndpoints.unreadQuoteMessages(quoteId)) as Map;
      expect(unread['data']['cantidad'], 0);

      await api.post(
        ApiEndpoints.quoteMessages,
        data: {
          'solicitudCotizacionGuidId': quoteId,
          'mensaje': 'Sí, el envío está incluido.',
        },
      );

      tokens.accessToken = 'development-client-session';
      unread = await api.get(ApiEndpoints.unreadQuoteMessages(quoteId)) as Map;
      expect(unread['data']['cantidad'], 1);
      await api.put(ApiEndpoints.markQuoteMessagesRead(quoteId));
      unread = await api.get(ApiEndpoints.unreadQuoteMessages(quoteId)) as Map;
      expect(unread['data']['cantidad'], 0);

      final quotesAfterConversation =
          await api.get(ApiEndpoints.dashboardQuotes) as Map;
      expect(
        (quotesAfterConversation['data'] as List).any(
          (item) => item['guidId'] == quoteId,
        ),
        isTrue,
      );

      final createdOrder = await api.post(
        ApiEndpoints.orders,
        data: {'cotizacionGuidId': quoteId},
      ) as Map;
      final orderId = createdOrder['data']['guidId'] as String;
      expect(orderId, isNotEmpty);
      final orderByQuote =
          await api.get(ApiEndpoints.orderByQuote(quoteId)) as Map;
      expect(orderByQuote['data']['cotizacionGuidId'], quoteId);
      expect((await ordersRepository.getForQuote(quoteId))?.id, orderId);
      final acceptedForClient =
          await api.get(ApiEndpoints.quote(quoteId)) as Map;
      expect(
        acceptedForClient['data']['solicitudCotizacionEstatus']['descripcion'],
        'Aceptada',
      );

      tokens.accessToken = 'development-yonke-session';
      final acceptedForYonke =
          await api.get(ApiEndpoints.dashboardQuotes) as Map;
      final acceptedQuote = (acceptedForYonke['data'] as List).firstWhere(
        (item) => item['guidId'] == quoteId,
      ) as Map;
      expect(
        acceptedQuote['solicitudCotizacionEstatus']['descripcion'],
        'Aceptada',
      );
      await api.put(
        ApiEndpoints.quote(quoteId),
        data: {'precio': 2890.0, 'diasGarantia': 45},
      );
      final updated = await api.get(ApiEndpoints.quote(quoteId)) as Map;
      expect(updated['data']['precio'], 2890.0);
      expect(updated['data']['diasGarantia'], 45);

      await api.put(
        ApiEndpoints.updateYonke('demo-yonke'),
        data: {'telefono': '+52 631 999 0000', 'responsable': 'Noé Demo'},
      );
      final profile = await api.get(ApiEndpoints.yonke('demo-yonke')) as Map;
      expect(profile['data']['telefono'], '+52 631 999 0000');
      expect(profile['data']['responsable'], 'Noé Demo');

      tokens.accessToken = 'development-client-session';
      await api.delete(ApiEndpoints.request(requestId));
      final clientAfterCancel =
          await api.get(ApiEndpoints.dashboardRequests) as Map;
      expect(
        (clientAfterCancel['data'] as List).any(
          (item) => item['guidId'] == requestId,
        ),
        isFalse,
      );

      tokens.accessToken = 'development-yonke-session';
      final yonkeAfterCancel =
          await api.get(ApiEndpoints.dashboardRequests) as Map;
      expect(
        (yonkeAfterCancel['data'] as List).any(
          (item) => item['solicitudGuidId'] == requestId,
        ),
        isFalse,
      );
    },
  );

  testWidgets('shows the linked demo data on the yonke home', (tester) async {
    final tokens = _MemoryTokenStore('development-yonke-session');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(tokens)],
        child: const MaterialApp(home: YonkeHomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('¡Hola, Yonke El Profe! 👋'), findsOneWidget);
    expect(find.text('Solicitudes recientes'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Aumenta tus ventas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore(this.accessToken);
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
  }) async {
    this.accessToken = accessToken;
  }
}

class _UnexpectedRemote implements ApiClient {
  Never _unexpected() => throw StateError('The remote API must not be called');
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => _unexpected();
  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => _unexpected();
  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => _unexpected();
  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => _unexpected();
  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) async => _unexpected();
}
