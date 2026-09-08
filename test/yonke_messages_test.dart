import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/yonke_messages/presentation/yonke_messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Token del yonke con `sub = yonke-user-7`.
const _jwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJzdWIiOiJ5b25rZS11c2VyLTciLCJyb2xlIjoiWW9ua2UiLCJleHAiOjE4OTM0NTYwMDB9.'
    'ZmFrZS1zaWduYXR1cmU';

void main() {
  testWidgets('la bandeja del yonke se arma con sus cotizaciones y abre una '
      'conversación', (tester) async {
    final api = _FakeApiClient();
    final router = GoRouter(
      initialLocation: '/yonke/mensajes',
      routes: [
        GoRoute(
          path: '/yonke/mensajes',
          builder: (context, state) => const YonkeMessagesPage(),
        ),
        GoRoute(
          path: '/yonke/mensajes/:quoteId',
          builder: (context, state) => YonkeConversationPage(
            args: state.extra! as YonkeConversationArgs,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          tokenStoreProvider.overrideWithValue(_MemoryTokenStore(_jwt)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mensajes'), findsWidgets);
    expect(
      api.calls,
      contains('GET /api/DashboardSuscriptores/mis-cotizaciones'),
    );
    expect(find.text('Cliente · RF-100'), findsOneWidget);
    expect(find.text('Hola, ¿la pieza incluye garantía?'), findsOneWidget);
    // Un mensaje del cliente sin leer.
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('yonke-conversation-quote-api')));
    await tester.pumpAndSettle();

    expect(find.text('Hola, ¿la pieza incluye garantía?'), findsOneWidget);
    expect(
      api.calls,
      contains('PUT /api/SolicitudCotizacionMensajes/quote-api/leer'),
    );
    await tester.enterText(
      find.byKey(const Key('yonke-message-input')),
      'La garantía está confirmada.',
    );
    await tester.tap(find.byKey(const Key('yonke-send-message')));
    await tester.pumpAndSettle();

    expect(api.sentMessages.single['mensaje'], 'La garantía está confirmada.');
    expect(find.text('La garantía está confirmada.'), findsOneWidget);
    expect(find.text('Mensaje enviado.'), findsOneWidget);
  });
}

Map<String, dynamic> _ok(Object? data) => {
  'success': true,
  'message': 'OK',
  'data': data,
  'statusCode': 200,
  'errors': null,
};

Map<String, dynamic> _message({
  required String id,
  required String text,
  required String userId,
  required int senderType,
  required String at,
  bool read = false,
}) => {
  'guidId': id,
  'solicitudCotizacionGuidId': 'quote-api',
  'usuarioId': userId,
  'tipoRemitenteId': senderType,
  'mensaje': text,
  'leido': read,
  'fechaLectura': null,
  'fechaCreacion': at,
};

const _quoteRecord = {
  'guidId': 'quote-api',
  'fechaCreacion': '2026-08-31T11:25:00Z',
  'solicitudYonkeGuidId': 'assignment-api',
  'precio': 1850.0,
  'disponible': true,
  'esNueva': false,
  'tieneGarantia': true,
  'diasGarantia': 30,
  'envioDisponible': true,
  'costoEnvio': 120.0,
  'activo': true,
  'solicitudCotizacionEstatus': {'descripcion': 'Vista'},
  'solicitudYonkes': {
    'guidId': 'assignment-api',
    'solicitudGuidId': 'request-api',
    'solicitudes': {
      'piezaBuscada': 'Alternador',
      'año': 2018,
      'folio': 'RF-100',
      'marcas': {'marca': 'Nissan'},
      'modelos': {'modelo': 'Sentra'},
    },
  },
  'solicitudCotizacionesImagenes': <Map<String, dynamic>>[],
};

class _FakeApiClient implements ApiClient {
  final calls = <String>[];
  final sentMessages = <Map<dynamic, dynamic>>[];
  final _history = <Map<String, dynamic>>[
    _message(
      id: 'm-1',
      text: 'Hola, ¿la pieza incluye garantía?',
      userId: 'user-42',
      senderType: 1,
      at: '2026-08-31T12:10:00Z',
    ),
  ];

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    calls.add('GET $path');
    return switch (path) {
      '/api/DashboardSuscriptores/mis-cotizaciones' => _ok([_quoteRecord]),
      '/api/SolicitudCotizacionMensajes/quote-api' => _ok(
        List<Map<String, dynamic>>.from(_history),
      ),
      _ => throw ApiException(message: 'Sin ruta $path', statusCode: 404),
    };
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
          userId: 'yonke-user-7',
          senderType: 2,
          at: '2026-08-31T12:30:00Z',
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
  Future<String?> readYonkeGuidId() async => 'yonke-1';

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async => this.accessToken = accessToken;
}
