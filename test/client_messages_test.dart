import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/messages/presentation/client_conversation_page.dart';
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
    if (path == '/api/SolicitudCotizacionMensajes/quote-norte') {
      return _ok(List<Map<String, dynamic>>.from(_history));
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
