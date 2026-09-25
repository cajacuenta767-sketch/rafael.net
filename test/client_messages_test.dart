import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/messages/presentation/client_conversation_page.dart';
import 'package:app_yonke/features/messages/data/client_messages_repository.dart';
import 'package:app_yonke/features/messages/domain/client_message.dart';
import 'package:app_yonke/features/quotes/domain/client_quote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Token con `sub = user-42`, igual al `usuarioId` del mensaje del cliente.
const _jwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJzdWIiOiJ1c2VyLTQyIiwicm9sZSI6IkNsaWVudGUiLCJleHAiOjE4OTM0NTYwMDB9.'
    'ZmFrZS1zaWduYXR1cmU';

void main() {
  testWidgets('un 401 del chat muestra el error, nunca mensajes de ejemplo', (
    tester,
  ) async {
    final api = _FakeApiClient(unauthorizedChat: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          tokenStoreProvider.overrideWithValue(_MemoryTokenStore(_jwt)),
        ],
        child: const MaterialApp(
          home: ClientConversationPage(
            args: ClientConversationArgs(quote: _quote),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pudimos abrir el historial'), findsOneWidget);
    expect(
      find.text('Buen día, tenemos disponible la pieza que buscas.'),
      findsNothing,
    );
    expect(api.sentMessages, isEmpty);
  });

  testWidgets('chat conserva la composición visual de la referencia', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ClientConversationPage(
            args: ClientConversationArgs(quote: _visualQuote),
            repository: _VisualMessagesRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Faro izquierdo'), findsOneWidget);
    expect(find.text('¿Incluye envío a Nogales?'), findsOneWidget);
    await expectLater(
      find.byType(ClientConversationPage),
      matchesGoldenFile('goldens/client_chat_reference.png'),
    );
  });

  testWidgets('bandeja del cliente reúne cotizaciones e historiales del API', (
    tester,
  ) async {
    final api = _FakeApiClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          tokenStoreProvider.overrideWithValue(_MemoryTokenStore(_jwt)),
        ],
        child: const MaterialApp(home: ClientMessagesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conversaciones'), findsOneWidget);
    expect(find.text('Yonke Norte'), findsOneWidget);
    expect(find.text('Alternador · Nissan · SOL-0042/2026'), findsOneWidget);
    expect(find.text('Sí, cuenta con 15 días de garantía.'), findsOneWidget);
    expect(
      api.calls,
      containsAll([
        'GET /api/DashboardSuscriptores/mis-cotizaciones',
        'GET /api/SolicitudCotizacionMensajes/quote-norte',
        'GET /api/SolicitudCotizacionMensajes/quote-norte/no-leidos',
      ]),
    );
  });

  testWidgets('cliente ve la conversación real y envía un mensaje', (
    tester,
  ) async {
    final api = _FakeApiClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          tokenStoreProvider.overrideWithValue(_MemoryTokenStore(_jwt)),
        ],
        child: const MaterialApp(
          home: ClientConversationPage(
            args: ClientConversationArgs(quote: _quote),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hola, ¿la pieza incluye garantía?'), findsOneWidget);
    expect(find.text('Sí, cuenta con 15 días de garantía.'), findsOneWidget);
    expect(
      api.calls,
      containsAll([
        'GET /api/SolicitudCotizacionMensajes/quote-norte',
        'PUT /api/SolicitudCotizacionMensajes/quote-norte/leer',
      ]),
    );

    await tester.enterText(
      find.byKey(const Key('client-message-input')),
      '¿Puedes enviarla mañana?',
    );
    await tester.tap(find.byKey(const Key('client-send-message')));
    await tester.pumpAndSettle();

    expect(api.sentMessages, [
      {
        'solicitudCotizacionGuidId': 'quote-norte',
        'mensaje': '¿Puedes enviarla mañana?',
      },
    ]);
    // El historial se recarga desde la API después de enviar.
    expect(find.text('¿Puedes enviarla mañana?'), findsOneWidget);
    expect(find.text('Mensaje enviado.'), findsOneWidget);
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
  active: true,
  status: 'Enviada',
  imageUrls: [],
);

const _visualQuote = ClientQuote(
  id: 'quote-visual',
  requestId: 'request-visual',
  requestFolio: 'SR-2024-0187',
  yonkeId: 'yonke-norte',
  yonkeName: 'Yonke del Norte',
  partName: 'Faro izquierdo',
  brand: 'Nissan',
  model: 'Versa',
  year: 2020,
  price: 2800,
  available: true,
  isNew: false,
  hasWarranty: true,
  warrantyDays: 15,
  shippingAvailable: true,
  active: true,
  status: 'Enviada',
  imageUrls: [],
);

class _VisualMessagesRepository implements ClientMessagesRepository {
  const _VisualMessagesRepository();

  @override
  Future<List<ClientMessagePreview>> getInbox() async => const [];

  @override
  Future<List<ClientQuoteMessage>> getConversation(String quoteId) async => [
    ClientQuoteMessage(
      id: 'v1',
      text: 'Buen día, tenemos disponible el faro que buscas.',
      sentAt: DateTime(2026, 9, 8, 10, 31),
      fromClient: false,
    ),
    ClientQuoteMessage(
      id: 'v2',
      text: '¿Me puedes enviar más fotos por favor?',
      sentAt: DateTime(2026, 9, 8, 10, 32),
      fromClient: true,
      read: true,
    ),
    ClientQuoteMessage(
      id: 'v3',
      text: 'Claro, la pieza está en buen estado.',
      sentAt: DateTime(2026, 9, 8, 10, 33),
      fromClient: false,
    ),
    ClientQuoteMessage(
      id: 'v4',
      text: '¿Te sirve en \$2,800?',
      sentAt: DateTime(2026, 9, 8, 10, 34),
      fromClient: false,
    ),
    ClientQuoteMessage(
      id: 'v5',
      text: '¿Incluye envío a Nogales?',
      sentAt: DateTime(2026, 9, 8, 10, 34),
      fromClient: true,
      read: true,
    ),
    ClientQuoteMessage(
      id: 'v6',
      text: 'Así es, envío incluido.',
      sentAt: DateTime(2026, 9, 8, 10, 35),
      fromClient: false,
    ),
  ];

  @override
  Future<void> sendMessage({
    required String quoteId,
    required String message,
  }) async {}
}

Map<String, dynamic> _message({
  required String id,
  required String text,
  required String userId,
  required int senderType,
  required String at,
}) => {
  'guidId': id,
  'solicitudCotizacionGuidId': 'quote-norte',
  'usuarioId': userId,
  'tipoRemitenteId': senderType,
  'mensaje': text,
  'leido': false,
  'fechaLectura': null,
  'fechaCreacion': at,
};

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.unauthorizedChat = false});

  final bool unauthorizedChat;
  final calls = <String>[];
  final sentMessages = <Object?>[];
  final _history = <Map<String, dynamic>>[
    _message(
      id: 'm-1',
      text: 'Hola, ¿la pieza incluye garantía?',
      userId: 'user-42',
      senderType: 1,
      at: '2026-08-31T12:10:00Z',
    ),
    _message(
      id: 'm-2',
      text: 'Sí, cuenta con 15 días de garantía.',
      userId: 'yonke-user-7',
      senderType: 2,
      at: '2026-08-31T12:14:00Z',
    ),
  ];

  Map<String, dynamic> _ok(Object? data) => {
    'success': true,
    'message': 'OK',
    'data': data,
    'statusCode': 200,
    'errors': null,
  };

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    calls.add('GET $path');
    if (unauthorizedChat &&
        path.startsWith('/api/SolicitudCotizacionMensajes/')) {
      throw const ApiException(message: 'Unauthorized', statusCode: 401);
    }
    if (path == '/api/DashboardSuscriptores/mis-cotizaciones') {
      return _ok([
        {
          'guidId': 'quote-norte',
          'solicitudYonkeGuidId': 'request-yonke-norte',
          'folio': 'SOL-0042/2026',
          'piezaBuscada': 'Alternador',
          'marca': 'Nissan',
          'precio': 1700,
          'disponible': true,
          'esNueva': false,
          'tieneGarantia': true,
          'diasGarantia': 15,
          'envioDisponible': true,
          'activo': true,
          'fechaCreacionCotizacion': '2026-08-31T12:00:00Z',
          'yonkeNombre': 'Yonke Norte',
        },
      ]);
    }
    if (path == '/api/SolicitudCotizacionMensajes/quote-norte') {
      return _ok(List<Map<String, dynamic>>.from(_history));
    }
    if (path == '/api/SolicitudCotizacionMensajes/quote-norte/no-leidos') {
      return _ok({'cantidad': 1});
    }
    throw ApiException(message: 'Sin ruta $path', statusCode: 404);
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    calls.add('POST $path');
    if (path == '/api/SolicitudCotizacionMensajes' && data is Map) {
      sentMessages.add(data);
      _history.add(
        _message(
          id: 'm-${_history.length + 1}',
          text: data['mensaje'].toString(),
          userId: 'user-42',
          senderType: 1,
          at: '2026-08-31T12:20:00Z',
        ),
      );
      return _ok('ok');
    }
    throw ApiException(message: 'Sin ruta $path', statusCode: 404);
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    calls.add('PUT $path');
    return _ok('ok');
  }

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => throw UnimplementedError();

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) => throw UnimplementedError();
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore(this.accessToken);

  String? accessToken;

  @override
  Future<void> clear() async => accessToken = null;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<DateTime?> readExpiresAt() async => null;

  @override
  Future<String?> readYonkeGuidId() async => null;

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async => this.accessToken = accessToken;
}
