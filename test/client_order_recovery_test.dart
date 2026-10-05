import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/features/orders/data/client_orders_repository.dart';
import 'package:app_yonke/features/orders/data/orders_api.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client implements ApiClient {
  int posts = 0;
  int gets = 0;
  int status = 1;
  bool allowCancel = true;
  ApiException? createError;
  bool confirmCancel = false;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    gets++;
    return {
      'data': {
        'guidId': 'order-test',
        'cotizacionGuidId': 'quote-test',
        'estatusOrdenId': status,
        'puedeCancelar': allowCancel,
      },
    };
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    posts++;
    if (path.endsWith('/cancelar')) {
      if (confirmCancel) status = 9;
      return null;
    }
    if (createError != null) throw createError!;
    return {
      'data': {'guidId': 'order-test'},
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('recupera orden persistida tras timeout sin repetir POST', () async {
    final api = _Client()..createError = const ApiException(message: 'timeout');
    final repository = ApiClientOrdersRepository(OrdersApi(api));
    final result = await repository.createOrder('quote-test');
    expect(result.orderId, 'order-test');
    expect(api.posts, 1);
    expect(api.gets, 1);
  });
  test(
    'un rechazo definitivo no se convierte en creación recuperada',
    () async {
      final api = _Client()
        ..createError = const ApiException(
          message: 'prohibido',
          statusCode: 403,
        );
      final repository = ApiClientOrdersRepository(OrdersApi(api));
      await expectLater(
        repository.createOrder('quote-test'),
        throwsA(isA<ApiException>()),
      );
      expect(api.gets, 0);
      expect(api.posts, 1);
    },
  );
  test('estado desconocido no se transforma en pendiente de pago', () async {
    final api = _Client()
      ..status = 99
      ..allowCancel = false;
    final order = await ApiClientOrdersRepository(OrdersApi(api))
        .getById('order-test');
    expect(order.status, 'Estado no reconocido (99)');
    expect(order.responseContractPending, isTrue);
    expect(order.canCancel, isFalse);
  });
  test(
    'orden pagada no muestra cancelar como sustituto de reembolso',
    () async {
      final api = _Client()..status = 3;
      final order = await ApiClientOrdersRepository(OrdersApi(api))
          .getById('order-test');
      expect(order.canCancel, isFalse);
    },
  );
  test('200 sin estado exige confirmar cancelación con consulta', () async {
    final api = _Client();
    final repository = ApiClientOrdersRepository(OrdersApi(api));
    final order = await repository.getById('order-test');
    await expectLater(repository.cancel(order), throwsA(isA<ApiException>()));
    expect(api.posts, 1);
    api.confirmCancel = true;
    final cancelled = await repository.cancel(order);
    expect(cancelled.isCancelled, isTrue);
    expect(cancelled.canCancel, isFalse);
  });
}
