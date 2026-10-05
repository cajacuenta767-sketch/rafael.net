import 'package:flutter_test/flutter_test.dart';
import 'package:app_yonke/features/payments/data/payments_api.dart';

void main() {
  group('PaymentsApi response parsing', () {
    test('accepts a Stripe-hosted HTTPS checkout session', () {
      final session = PaymentsApi.parseCheckout({
        'success': true,
        'data': {
          'sessionId': 'cs_test_123',
          'checkoutUrl': 'https://checkout.stripe.com/c/pay/cs_test_123',
        },
      });

      expect(session?.sessionId, 'cs_test_123');
      expect(session?.checkoutUrl.host, 'checkout.stripe.com');
    });

    test('rejects arbitrary or insecure checkout URLs', () {
      for (final url in [
        'http://checkout.stripe.com/c/pay/test',
        'https://evil.example/checkout',
        'https://checkout.stripe.com.evil.example/c/pay/test',
      ]) {
        expect(
          PaymentsApi.parseCheckout({
            'data': {'sessionId': 'cs_test', 'checkoutUrl': url},
          }),
          isNull,
        );
      }
    });

    test('parses a wrapped payment status response', () {
      expect(
        PaymentsApi.parseResult({
          'success': true,
          'data': {'estado': 'pagado', 'exitoso': true},
        }),
        {'estado': 'pagado', 'exitoso': true},
      );
    });

    test('accepts the paymentStatus field returned by the API', () {
      expect(
        PaymentsApi.parseResult({
          'data': {'paymentStatus': 'paid', 'sessionId': 'cs_test_456'},
        }),
        {'paymentStatus': 'paid', 'sessionId': 'cs_test_456'},
      );
    });
  });
}
