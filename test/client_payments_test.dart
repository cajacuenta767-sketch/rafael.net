import 'package:app_yonke/features/payments/data/client_payments_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('checkout de Stripe', () {
    test('lee url y sessionId dentro del sobre ApiResponseGlobal', () {
      final checkout = paymentCheckoutFromResponse({
        'success': true,
        'data': {
          'url': 'https://checkout.stripe.com/c/pay/cs_test_abc',
          'sessionId': 'cs_test_abc',
        },
      });
      expect(checkout, isNotNull);
      expect(checkout!.url.host, 'checkout.stripe.com');
      expect(checkout.sessionId, 'cs_test_abc');
    });

    test('acepta la url pelada y deduce la sesión del enlace', () {
      final checkout = paymentCheckoutFromResponse(
        'https://checkout.stripe.com/c/pay/cs_live_999',
      );
      expect(checkout?.sessionId, 'cs_live_999');
    });

    test('rechaza respuestas sin url o con esquemas no web', () {
      expect(
        paymentCheckoutFromResponse({
          'data': {'id': 'x'},
        }),
        isNull,
      );
      expect(
        paymentCheckoutFromResponse({'url': 'javascript:alert(1)'}),
        isNull,
      );
      expect(paymentCheckoutFromResponse(null), isNull);
    });
  });

  group('resultado del pago', () {
    test('marca pagado por estatus o por bandera', () {
      expect(
        paymentResultFromResponse({
          'data': {'paymentStatus': 'paid'},
        }).paid,
        isTrue,
      );
      expect(
        paymentResultFromResponse({'estatus': 'pendiente', 'pagado': true})
            .paid,
        isTrue,
      );
      expect(paymentResultFromResponse({'status': 'open'}).paid, isFalse);
      expect(
        paymentResultFromResponse({'status': 'open'}).label,
        'Pago pendiente',
      );
      expect(paymentResultFromResponse(true).paid, isTrue);
    });
  });
}
