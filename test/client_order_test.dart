import 'package:app_yonke/app/router/app_router.dart';
import 'package:app_yonke/features/orders/presentation/client_order_pages.dart';
import 'package:app_yonke/features/orders/data/client_orders_repository.dart';
import 'package:app_yonke/features/orders/domain/client_order.dart';
import 'package:app_yonke/features/orders/domain/client_order_creation.dart';
import 'package:app_yonke/features/quotes/domain/client_quote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('cliente confirma una cotización y crea una orden de prueba', (
    tester,
  ) async {
    final quote = mockQuoteById('mock-quote-norte')!;
    final router = GoRouter(
      initialLocation: '/confirmar',
      routes: [
        GoRoute(
          path: '/confirmar',
          builder: (context, state) => ClientOrderConfirmationPage(
            args: ClientOrderConfirmationArgs(quote: quote, isDemo: true),
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

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Revisa tu selección'), findsOneWidget);
    expect(find.text('Yonke de prueba Norte'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('client-confirm-order')),
      250,
    );
    await tester.tap(find.byKey(const Key('client-confirm-order')));
    await tester.pumpAndSettle();

    expect(find.text('Orden de prueba creada'), findsOneWidget);
    expect(find.textContaining('demo-order-mock-quote-norte'), findsOneWidget);
  });

  testWidgets('cliente consulta y cancela una orden de prueba', (tester) async {
    final quote = mockQuoteById('mock-quote-norte')!;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClientOrderTrackingPage(
            args: ClientOrderTrackingArgs(
              quote: quote,
              isDemo: true,
              orderId: 'demo-order-mock-quote-norte',
            ),
            repository: _TrackingRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu orden está registrada'), findsOneWidget);
    await tester.tap(find.byKey(const Key('client-cancel-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('client-confirm-cancel-order')));
    await tester.pumpAndSettle();

    expect(find.text('Orden cancelada'), findsOneWidget);
  });
}

class _TrackingRepository implements ClientOrdersRepository {
  @override
  Future<ClientOrder> cancel(ClientOrder order) async => order.copyWith(
    status: 'Cancelada',
    isCancelled: true,
    canCancel: false,
  );

  @override
  Future<ClientOrderCreationResult> createOrder(String quoteId) =>
      throw UnimplementedError();

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
