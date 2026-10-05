import 'dart:async';

import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/session/session_events.dart';
import 'package:app_yonke/features/quotes/data/quotes_api.dart';
import 'package:app_yonke/features/yonke_messages/data/quote_client_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client implements ApiClient {
  String name = 'Cliente A';
  int calls = 0;
  Completer<dynamic>? pending;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    calls++;
    if (pending != null) return pending!.future;
    return {
      'data': {'nombreCliente': name},
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('caché reutilizada se limpia al cambiar la sesión', () async {
    final api = _Client();
    final resolver = QuoteClientResolver(QuotesApi(api));
    expect((await resolver.resolve('quote'))?.name, 'Cliente A');
    expect((await resolver.resolve('quote'))?.name, 'Cliente A');
    expect(api.calls, 1);
    SessionEvents.notifySignedOut();
    SessionEvents.notifySignedIn();
    api.name = 'Cliente B';
    expect((await resolver.resolve('quote'))?.name, 'Cliente B');
    expect(api.calls, 2);
  });

  test('respuesta en vuelo de la sesión anterior no se entrega', () async {
    final api = _Client()..pending = Completer<dynamic>();
    final resolver = QuoteClientResolver(QuotesApi(api));
    final result = resolver.resolve('quote');
    SessionEvents.notifySignedOut();
    api.pending!.complete({
      'data': {'nombreCliente': 'Dato anterior'},
    });
    expect(await result, isNull);
  });
}
