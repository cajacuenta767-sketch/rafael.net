import 'package:app_yonke/app/router/app_router.dart';
import 'package:app_yonke/features/messages/data/client_messages_repository.dart';
import 'package:app_yonke/features/messages/domain/client_message.dart';
import 'package:app_yonke/features/notifications/presentation/client_notifications_page.dart';
import 'package:app_yonke/features/quotes/domain/client_quote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('un mensaje no leído abre el chat real', (tester) async {
    final repository = _FakeRepository(unread: 2);
    final router = _router(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Mensaje nuevo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('client-notification-q1')));
    await tester.pumpAndSettle();
    expect(find.text('CHAT q1'), findsOneWidget);
  });

  testWidgets('una cotización sin mensaje abre su detalle', (tester) async {
    final repository = _FakeRepository(unread: 0);
    final router = _router(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Nueva cotización recibida'), findsOneWidget);
    await tester.tap(find.byKey(const Key('client-notification-q1')));
    await tester.pumpAndSettle();
    expect(find.text('COTIZACIÓN q1'), findsOneWidget);
  });
}

GoRouter _router(ClientMessagesRepository repository) => GoRouter(
  initialLocation: AppRoutes.clientNotifications,
  routes: [
    GoRoute(
      path: AppRoutes.clientNotifications,
      builder: (_, _) => ClientNotificationsPage(repository: repository),
    ),
    GoRoute(
      path: '/cliente/cotizaciones/:quoteId/mensajes',
      builder: (_, state) =>
          Scaffold(body: Text('CHAT ${state.pathParameters['quoteId']}')),
    ),
    GoRoute(
      path: '/cliente/cotizaciones/:quoteId',
      builder: (_, state) =>
          Scaffold(body: Text('COTIZACIÓN ${state.pathParameters['quoteId']}')),
    ),
    GoRoute(
      path: AppRoutes.clientMessages,
      builder: (_, _) => const Text('MENSAJES'),
    ),
    GoRoute(
      path: AppRoutes.clientHome,
      builder: (_, _) => const Text('INICIO'),
    ),
    GoRoute(
      path: AppRoutes.clientRequests,
      builder: (_, _) => const Text('SOLICITUDES'),
    ),
    GoRoute(
      path: AppRoutes.clientProfile,
      builder: (_, _) => const Text('PERFIL'),
    ),
    GoRoute(
      path: AppRoutes.clientNewRequest,
      builder: (_, _) => const Text('NUEVA'),
    ),
    GoRoute(
      path: AppRoutes.clientYonkes,
      builder: (_, _) => const Text('YONKES'),
    ),
  ],
);

class _FakeRepository implements ClientMessagesRepository {
  _FakeRepository({required this.unread});
  final int unread;

  @override
  Future<List<ClientMessagePreview>> getInbox() async => [
    ClientMessagePreview(
      quote: _quote,
      lastMessage: unread > 0
          ? 'Tenemos disponible la pieza.'
          : 'Sin mensajes todavía',
      lastMessageAt: DateTime.now().subtract(const Duration(minutes: 2)),
      unreadCount: unread,
      historyAvailable: true,
    ),
  ];

  @override
  Future<List<ClientQuoteMessage>> getConversation(String quoteId) async =>
      const [];

  @override
  Future<void> sendMessage({
    required String quoteId,
    required String message,
  }) async {}
}

const _quote = ClientQuote(
  id: 'q1',
  requestId: 'r1',
  yonkeId: 'y1',
  yonkeName: 'Yonke del Norte',
  price: 2800,
  available: true,
  isNew: false,
  hasWarranty: true,
  warrantyDays: 30,
  shippingAvailable: true,
  active: true,
  status: 'Activa',
  imageUrls: [],
  partName: 'Faro izquierdo',
);
