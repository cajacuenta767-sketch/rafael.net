import 'package:app_yonke/app/router/app_router.dart';
import 'package:app_yonke/features/orders/data/client_orders_repository.dart';
import 'package:app_yonke/features/orders/domain/client_order.dart';
import 'package:app_yonke/features/orders/domain/client_order_creation.dart';
import 'package:app_yonke/features/orders/presentation/client_order_pages.dart';
import 'package:app_yonke/features/quotes/domain/client_quote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('cliente confirma una cotización y crea una orden', (
    tester,
  ) async {
    final repository = _TrackingRepository();
    final router = GoRouter(
      initialLocation: '/confirmar',
      routes: [
        GoRoute(
          path: '/confirmar',
          builder: (context, state) => ClientOrderConfirmationPage(
            args: const ClientOrderConfirmationArgs(quote: _quote),
            repository: repository,
          ),
        ),
        GoRoute(
          path: AppRoutes.clientOrderSuccess,
          builder: (context, state) => ClientOrderSuccessPage(
            args: state.extra! as ClientOrderSuccessArgs,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Revisa tu selección'), findsOneWidget);
    expect(find.text('Yonke Norte'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('client-confirm-order')),
      250,
    );
    await tester.tap(find.byKey(const Key('client-confirm-order')));
    await tester.pumpAndSettle();

    expect(repository.createdFor, ['quote-norte']);
    expect(find.text('Orden creada'), findsAtLeastNWidgets(1));
    expect(find.textContaining('order-quote-norte'), findsOneWidget);
  });

  testWidgets('cliente consulta y cancela una orden', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClientOrderTrackingPage(
            args: const ClientOrderTrackingArgs(
              quote: _quote,
              orderId: 'order-quote-norte',
            ),
            repository: _TrackingRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu orden está registrada'), findsOneWidget);
    expect(find.byKey(const Key('client-pay-order')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('client-cancel-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('client-cancel-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('client-confirm-cancel-order')));
    await tester.pumpAndSettle();

    expect(find.text('Orden cancelada'), findsOneWidget);
  });
}

const _quote = ClientQuote(
  id: 'quote-norte',
  requestId: 'request-alternador',
  yonkeId: 'yonke-norte',
  yonkeName: 'Yonke Norte',
  price: 1700,
  available: true,
  isNew: false,
  hasWarranty: true,
  warrantyDays: 15,
  shippingAvailable: true,
  shippingCost: 120,
  deliveryDays: 2,
  active: true,
  status: 'Enviada',
  imageUrls: [],
  comments: 'Pieza usada, probada y en buen estado.',
);

class _TrackingRepository implements ClientOrdersRepository {
  final createdFor = <String>[];

  @override
  Future<ClientOrder> cancel(ClientOrder order) async =>
      order.copyWith(status: 'Cancelada', isCancelled: true, canCancel: false);

  @override
  Future<ClientOrderCreationResult> createOrder(String quoteId) async {
    createdFor.add(quoteId);
    return ClientOrderCreationResult(
      orderId: 'order-$quoteId',
      responseContractPending: false,
    );
  }

  @override
  Future<ClientOrder> getById(String orderId, {String? quoteId}) async =>
      ClientOrder(
        id: orderId,
        quoteId: quoteId ?? '',
        status: 'Confirmada',
        createdAt: null,
        isCancelled: false,
        canCancel: true,
        responseContractPending: false,
      );

  @override
  Future<ClientOrder?> getForQuote(String quoteId) async => null;
}
