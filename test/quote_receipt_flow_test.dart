import 'package:app_yonke/features/messages/data/client_messages_repository.dart';
import 'package:app_yonke/features/messages/domain/client_message.dart';
import 'package:app_yonke/features/messages/presentation/client_conversation_page.dart';
import 'package:app_yonke/features/quotes/domain/client_quote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra banner para confirmar recepcion cuando cotizacion es Aceptada', (tester) async {
    final mockRepo = _TestMessagesRepo();
    final quote = _testQuote(status: 'Aceptada');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClientConversationPage(
            args: ClientConversationArgs(quote: quote),
            repository: mockRepo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pedido en camino / Aceptado'), findsOneWidget);
    expect(find.byKey(const Key('chat-mark-received-btn')), findsOneWidget);
    expect(find.text('Confirmar que recibí la pieza'), findsOneWidget);

    // Tocar el botón para abrir el diálogo
    await tester.tap(find.byKey(const Key('chat-mark-received-btn')));
    await tester.pumpAndSettle();

    expect(find.text('¿Recibiste tu refacción?'), findsOneWidget);
    expect(find.byKey(const Key('confirm-received-dialog-btn')), findsOneWidget);

    // Confirmar en el diálogo
    await tester.tap(find.byKey(const Key('confirm-received-dialog-btn')));
    await tester.pumpAndSettle();

    expect(mockRepo.markedReceivedQuoteId, equals('quote-123'));
    expect(find.text('Refacción recibida'), findsOneWidget);
    expect(find.byKey(const Key('chat-rate-yonke-btn')), findsOneWidget);
  });

  testWidgets('muestra banner de calificar cuando cotizacion ya es Recibida', (tester) async {
    final mockRepo = _TestMessagesRepo();
    final quote = _testQuote(status: 'Recibida');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClientConversationPage(
            args: ClientConversationArgs(quote: quote),
            repository: mockRepo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Refacción recibida'), findsOneWidget);
    expect(find.byKey(const Key('chat-rate-yonke-btn')), findsOneWidget);
    expect(find.text('Calificar al yonke'), findsOneWidget);
  });
}

ClientQuote _testQuote({required String status}) => ClientQuote(
      id: 'quote-123',
      requestId: 'req-456',
      yonkeId: 'yonke-789',
      yonkeName: 'Yonke El Pariente',
      price: 1500.0,
      available: true,
      isNew: false,
      hasWarranty: true,
      warrantyDays: 30,
      shippingAvailable: true,
      active: true,
      status: status,
      imageUrls: const [],
    );

class _TestMessagesRepo implements ClientMessagesRepository {
  String? markedReceivedQuoteId;

  @override
  Future<List<ClientMessagePreview>> getInbox() async => const [];

  @override
  Future<List<ClientQuoteMessage>> getConversation(String quoteId) async => const [];

  @override
  Future<void> sendMessage({required String quoteId, required String message}) async {}

  @override
  Future<void> markAsReceived(String quoteId) async {
    markedReceivedQuoteId = quoteId;
  }
}
