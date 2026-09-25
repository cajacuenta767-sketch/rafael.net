import 'dart:convert';
import 'dart:io';

import 'package:app_yonke/core/network/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cada ruta que usa la app debe existir en el contrato publicado
/// (`docs/openapi_v1.json`) con el mismo método. Así un 404 por una ruta mal
/// escrita o retirada del API falla en CI y no en el teléfono.
void main() {
  final spec = jsonDecode(
    File('docs/openapi_v1.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  // Lista y no mapa: dos plantillas con distinto nombre de parámetro generan
  // la misma expresión y deben conservarse ambas.
  final paths = [
    for (final MapEntry(key: template, value: operations)
        in (spec['paths'] as Map<String, dynamic>).entries)
      (
        RegExp('^${template.replaceAll(RegExp(r'\{[^}]+\}'), '[^/]+')}\$'),
        (operations as Map<String, dynamic>).keys.toSet(),
      ),
  ];

  const id = 'guid';
  final used = <(String, String)>[
    ('post', ApiEndpoints.clientGoogleLogin),
    ('post', ApiEndpoints.requestOtp),
    ('post', ApiEndpoints.verifyOtp),
    ('post', ApiEndpoints.registerClientDevice),
    ('post', ApiEndpoints.quotes),
    ('get', ApiEndpoints.quote(id)),
    ('put', ApiEndpoints.quote(id)),
    ('get', ApiEndpoints.yonkeQuotesTotal),
    ('get', ApiEndpoints.dashboardSummary),
    ('get', ApiEndpoints.dashboardRequests),
    ('get', ApiEndpoints.dashboardQuotes),
    ('get', ApiEndpoints.dashboardRecentRequest),
    ('get', ApiEndpoints.order(id)),
    ('get', ApiEndpoints.orderByQuote(id)),
    ('post', ApiEndpoints.orders),
    ('post', ApiEndpoints.cancelOrder(id)),
    ('get', ApiEndpoints.requestCities(id)),
    ('post', ApiEndpoints.quoteMessages),
    ('get', ApiEndpoints.quoteConversation(id)),
    ('put', ApiEndpoints.markQuoteMessagesRead(id)),
    ('get', ApiEndpoints.unreadQuoteMessages(id)),
    ('post', ApiEndpoints.requests),
    ('get', ApiEndpoints.request(id)),
    ('delete', ApiEndpoints.request(id)),
    ('post', ApiEndpoints.addRequestImage(id)),
    ('get', ApiEndpoints.requestImages(id)),
    ('delete', ApiEndpoints.requestImage(id)),
    ('post', ApiEndpoints.sendRequestToYonkes(id)),
    ('put', ApiEndpoints.markYonkeRequestViewed(id)),
    ('get', ApiEndpoints.yonkeAssignedRequests),
    ('get', ApiEndpoints.yonkeNewRequestsTotal),
    ('get', ApiEndpoints.states),
    ('get', ApiEndpoints.citiesByState(1)),
    ('get', ApiEndpoints.brands),
    ('get', ApiEndpoints.models),
    ('post', ApiEndpoints.yonkeLogin),
    ('get', ApiEndpoints.pagedYonkes),
    ('get', ApiEndpoints.yonke(id)),
    ('put', ApiEndpoints.updateYonke(id)),
    ('put', ApiEndpoints.updateYonkeLogo),
    ('post', ApiEndpoints.ratings),
    ('get', ApiEndpoints.yonkeRatings(id)),
    ('get', ApiEndpoints.yonkeCoverage(id)),
    ('put', ApiEndpoints.coverage),
    ('post', ApiEndpoints.yonkeDevices),
  ];

  for (final (method, path) in used) {
    test('${method.toUpperCase()} $path existe en el contrato', () {
      final methods = paths
          .where((entry) => entry.$1.hasMatch(path))
          .expand((entry) => entry.$2)
          .toSet();
      expect(methods, isNotEmpty, reason: 'La ruta no está publicada');
      expect(methods, contains(method), reason: 'Método no publicado');
    });
  }
}
