import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/network/development_api_client.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/quotes/presentation/client_quotes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el cliente conserva y muestra las cotizaciones recibidas', (
    tester,
  ) async {
    final tokens = _MemoryTokenStore('development-client-session');
    final api = DevelopmentApiClient(_UnexpectedRemote(), tokens);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          tokenStoreProvider.overrideWithValue(tokens),
        ],
        child: const MaterialApp(home: ClientQuotesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cotizaciones recibidas'), findsOneWidget);
    expect(find.text('Alternador'), findsWidgets);
    expect(find.text('Yonke El Profe'), findsWidgets);
    expect(
      find.byKey(const Key('client-global-quote-demo-quote-1')),
      findsOneWidget,
    );
  });
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
  Future<String?> readYonkeGuidId() async => 'demo-yonke';

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async => this.accessToken = accessToken;
}

class _UnexpectedRemote implements ApiClient {
  Never _unexpected() => throw StateError('No debe usar la API remota');

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => _unexpected();

  @override
  Future<dynamic> get(
    String path, {
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
}
