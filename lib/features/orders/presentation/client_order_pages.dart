import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/network/api_exception.dart';
import '../../payments/data/client_payments_repository.dart';
import '../../payments/domain/payment_checkout.dart';
import '../../quotes/domain/client_quote.dart';
import '../../ratings/presentation/client_rating_page.dart';
import '../data/client_orders_repository.dart';
import '../domain/client_order_creation.dart';
import '../domain/client_order.dart';

class ClientOrderConfirmationArgs {
  const ClientOrderConfirmationArgs({required this.quote});

  final ClientQuote quote;
}

class ClientOrderSuccessArgs {
  const ClientOrderSuccessArgs({required this.quote, required this.result});

  final ClientQuote quote;
  final ClientOrderCreationResult result;
}

class ClientOrderTrackingArgs {
  const ClientOrderTrackingArgs({required this.quote, this.orderId});

  final ClientQuote quote;
  final String? orderId;
}

class ClientOrderConfirmationPage extends ConsumerStatefulWidget {
  const ClientOrderConfirmationPage({
    super.key,
    required this.args,
    this.repository,
  });

  final ClientOrderConfirmationArgs args;
  final ClientOrdersRepository? repository;

  @override
  ConsumerState<ClientOrderConfirmationPage> createState() =>
      _ClientOrderConfirmationPageState();
}

class _ClientOrderConfirmationPageState
    extends ConsumerState<ClientOrderConfirmationPage> {
  late final ClientOrdersRepository _repository;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ref.read(clientOrdersRepositoryProvider);
  }

  Future<void> _createOrder() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final result = await _repository.createOrder(widget.args.quote.id);
      if (!mounted) return;
      context.pushReplacement(
        AppRoutes.clientOrderSuccess,
        extra: ClientOrderSuccessArgs(quote: widget.args.quote, result: result),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo crear la orden. Inténtalo nuevamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.args.quote;
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCFCFC),
        surfaceTintColor: const Color(0xFFFCFCFC),
        centerTitle: true,
        title: const Text('Aceptar cotización'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 54,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Revisa tu selección',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Al aceptar, confirmaremos esta cotización y crearemos tu orden.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF596276)),
                ),
                const SizedBox(height: 22),
                _SummaryCard(
                  children: [
                    _SummaryRow(label: 'Yonke', value: quote.yonkeName),
                    _SummaryRow(
                      label: 'Precio',
                      value: formatQuotePrice(quote.price),
                    ),
                    _SummaryRow(
                      label: 'Disponibilidad',
                      value: quote.availability,
                    ),
                    _SummaryRow(label: 'Condición', value: quote.condition),
                    _SummaryRow(label: 'Garantía', value: quote.warranty),
                    _SummaryRow(
                      label: 'Envío',
                      value: quote.shippingAvailable
                          ? quote.shippingCost == null
                                ? 'Disponible'
                                : 'Disponible · ${formatQuotePrice(quote.shippingCost!)}'
                          : 'No disponible',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Revisa los datos antes de registrar tu orden.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF596276), fontSize: 12),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  key: const Key('client-confirm-order'),
                  onPressed: _creating ? null : _createOrder,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF00695C),
                  ),
                  child: _creating
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Aceptar y crear orden'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ClientOrderSuccessPage extends StatelessWidget {
  const ClientOrderSuccessPage({super.key, required this.args});

  final ClientOrderSuccessArgs args;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFCFCFC),
    appBar: AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFFCFCFC),
      surfaceTintColor: const Color(0xFFFCFCFC),
      centerTitle: true,
      title: const Text('Orden creada'),
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5EA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 56,
                      color: Color(0xFF147A1D),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Orden creada',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tu selección de ${args.quote.yonkeName} fue registrada.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF596276)),
                  ),
                  if (args.result.orderId != null) ...[
                    const SizedBox(height: 16),
                    SelectableText(
                      'Orden: ${args.result.orderId}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _OrderStatusInfoCard(
                    contractPending: args.result.responseContractPending,
                  ),
                  const SizedBox(height: 24),
                  if (args.result.orderId != null) ...[
                    FilledButton.icon(
                      key: const Key('client-track-order'),
                      onPressed: () => context.push(
                        AppRoutes.clientOrderTracking(args.quote.id),
                        extra: ClientOrderTrackingArgs(
                          quote: args.quote,
                          orderId: args.result.orderId,
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Ver seguimiento de la orden'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: const Color(0xFF00695C),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    key: const Key('client-rate-yonke'),
                    onPressed: () => context.push(
                      AppRoutes.clientRating(args.quote.id),
                      extra: ClientRatingArgs(quote: args.quote),
                    ),
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Calificar al yonke'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.clientRequests),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF00695C),
                    ),
                    child: const Text('Ver mis solicitudes'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.clientHome),
                    child: const Text('Ir al inicio'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE1E6EC)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: children),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF596276))),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _OrderStatusInfoCard extends StatelessWidget {
  const _OrderStatusInfoCard({required this.contractPending});
  final bool contractPending;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF1FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: Color(0xFF114EB0)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            contractPending
                ? 'La orden fue aceptada, pero la API aún no documenta todos sus datos. Podrás consultarla cuando el contrato esté completo.'
                : 'Puedes consultar el estado de tu orden y cancelarla si aún aplica.',
          ),
        ),
      ],
    ),
  );
}

class ClientOrderTrackingPage extends ConsumerStatefulWidget {
  const ClientOrderTrackingPage({
    super.key,
    required this.args,
    this.repository,
    this.paymentsRepository,
    this.openUrl,
  });

  final ClientOrderTrackingArgs args;
  final ClientOrdersRepository? repository;
  final ClientPaymentsRepository? paymentsRepository;

  /// Abre la URL de Stripe en el navegador. Inyectable para pruebas.
  final Future<bool> Function(Uri url)? openUrl;

  @override
  ConsumerState<ClientOrderTrackingPage> createState() =>
      _ClientOrderTrackingPageState();
}

class _ClientOrderTrackingPageState
    extends ConsumerState<ClientOrderTrackingPage> {
  late final ClientOrdersRepository _repository;
  late final ClientPaymentsRepository _payments;
  ClientOrder? _order;
  Object? _error;
  bool _loading = true;
  bool _cancelling = false;
  bool _paying = false;
  bool _checkingPayment = false;
  PaymentCheckout? _checkout;
  PaymentResult? _paymentResult;
  String? _paymentError;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ref.read(clientOrdersRepositoryProvider);
    _payments =
        widget.paymentsRepository ?? ref.read(clientPaymentsRepositoryProvider);
    _load();
  }

  /// Crea la sesión de Stripe Checkout y abre el navegador. El resultado se
  /// consulta después con [_verifyPayment], porque la app no recibe el
  /// retorno de Stripe (`/pago/exitoso` es una página del servidor).
  Future<void> _pay() async {
    final order = _order;
    final orderId = order?.id;
    if (order == null || orderId == null || _paying) return;
    setState(() {
      _paying = true;
      _paymentError = null;
    });
    try {
      final checkout = await _payments.createCheckout(orderId);
      if (!mounted) return;
      setState(() => _checkout = checkout);
      final opened = await (widget.openUrl ?? _launchExternal)(checkout.url);
      if (!opened && mounted) {
        setState(
          () => _paymentError =
              'No se pudo abrir el navegador. Copia el enlace de pago: '
              '${checkout.url}',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _paymentError = error is ApiException
            ? error.message
            : 'No se pudo iniciar el pago. Revisa tu conexión.',
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _verifyPayment() async {
    final sessionId = _checkout?.sessionId;
    if (sessionId == null || _checkingPayment) return;
    setState(() {
      _checkingPayment = true;
      _paymentError = null;
    });
    try {
      final result = await _payments.getResult(sessionId);
      if (mounted) setState(() => _paymentResult = result);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _paymentError = error is ApiException
            ? error.message
            : 'No se pudo consultar el pago. Inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _checkingPayment = false);
    }
  }

  static Future<bool> _launchExternal(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = widget.args.orderId == null
          ? await _repository.getForQuote(widget.args.quote.id)
          : await _repository.getById(
              widget.args.orderId!,
              quoteId: widget.args.quote.id,
            );
      if (mounted) setState(() => _order = order);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    final order = _order;
    if (order == null || _cancelling || !order.canCancel) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar orden?'),
        content: const Text(
          'Esta acción se enviará al servidor y puede no poder deshacerse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: const Key('client-confirm-cancel-order'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            child: const Text('Cancelar orden'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final cancelled = await _repository.cancel(order);
      if (mounted) {
        setState(() => _order = cancelled);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La cancelación fue enviada.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo cancelar la orden. Inténtalo nuevamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFCFCFC),
    appBar: AppBar(
      backgroundColor: const Color(0xFFFCFCFC),
      surfaceTintColor: const Color(0xFFFCFCFC),
      centerTitle: true,
      title: const Text('Seguimiento de orden'),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _TrackingError(onRetry: _load)
              : _order == null
              ? const _NoOrder()
              : _TrackingContent(
                  quote: widget.args.quote,
                  order: _order!,
                  cancelling: _cancelling,
                  onCancel: _cancel,
                  payment: _PaymentState(
                    paying: _paying,
                    checking: _checkingPayment,
                    checkout: _checkout,
                    result: _paymentResult,
                    error: _paymentError,
                    onPay: _pay,
                    onVerify: _verifyPayment,
                  ),
                ),
        ),
      ),
    ),
  );
}

class _TrackingContent extends StatelessWidget {
  const _TrackingContent({
    required this.quote,
    required this.order,
    required this.cancelling,
    required this.onCancel,
    required this.payment,
  });

  final ClientQuote quote;
  final ClientOrder order;
  final bool cancelling;
  final VoidCallback onCancel;
  final _PaymentState payment;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
    children: [
      Icon(
        order.isCancelled
            ? Icons.cancel_outlined
            : Icons.local_shipping_outlined,
        size: 58,
        color: order.isCancelled
            ? const Color(0xFFB3261E)
            : const Color(0xFF00695C),
      ),
      const SizedBox(height: 12),
      Text(
        order.isCancelled ? 'Orden cancelada' : 'Tu orden está registrada',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      Text(
        quote.yonkeName,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF596276)),
      ),
      const SizedBox(height: 24),
      _SummaryCard(
        children: [
          _SummaryRow(
            label: 'Estado',
            value: order.status ?? 'Pendiente de confirmar',
          ),
          _SummaryRow(label: 'Yonke', value: quote.yonkeName),
          _SummaryRow(
            label: quote.requestFolio?.isNotEmpty == true
                ? 'Folio'
                : 'Cotización',
            value: quote.requestFolio?.isNotEmpty == true
                ? quote.requestFolio!
                : _shortId(quote.id),
          ),
          if (order.id != null)
            _SummaryRow(label: 'Orden', value: _shortId(order.id!)),
          if (order.createdAt != null)
            _SummaryRow(label: 'Creada', value: _formatDate(order.createdAt!)),
        ],
      ),
      if (order.responseContractPending) ...[
        const SizedBox(height: 16),
        const _OrderStatusInfoCard(contractPending: true),
      ],
      if (order.id != null && !order.isCancelled) ...[
        const SizedBox(height: 22),
        _PaymentSection(state: payment, price: quote.price),
      ],
      const SizedBox(height: 22),
      if (payment.result?.paid == true)
        const Text(
          key: Key('client-order-paid-lock'),
          'La orden ya está pagada. Para cancelarla, acuerda el reembolso '
          'con el yonke desde Mensajes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF596276)),
        )
      else if (order.canCancel)
        OutlinedButton.icon(
          key: const Key('client-cancel-order'),
          onPressed: cancelling ? null : onCancel,
          icon: cancelling
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cancel_outlined),
          label: Text(cancelling ? 'Cancelando...' : 'Cancelar orden'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB3261E),
            side: const BorderSide(color: Color(0xFFB3261E)),
            minimumSize: const Size.fromHeight(52),
          ),
        )
      else
        const Text(
          'Esta orden ya no puede cancelarse desde la aplicación.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF596276)),
        ),
    ],
  );
}

class _NoOrder extends StatelessWidget {
  const _NoOrder();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFF596276)),
        SizedBox(height: 16),
        Text(
          'Aún no hay una orden para esta cotización',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _TrackingError extends StatelessWidget {
  const _TrackingError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 64,
          color: Color(0xFF596276),
        ),
        const SizedBox(height: 16),
        const Text(
          'No se pudo consultar la orden.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

/// Los GUID completos no le dicen nada al usuario; se muestran los últimos
/// caracteres para poder citarlos en soporte sin llenar la pantalla.
String _shortId(String id) =>
    id.length <= 12 ? id : '…${id.substring(id.length - 12)}';

class _PaymentState {
  const _PaymentState({
    required this.paying,
    required this.checking,
    required this.checkout,
    required this.result,
    required this.error,
    required this.onPay,
    required this.onVerify,
  });

  final bool paying;
  final bool checking;
  final PaymentCheckout? checkout;
  final PaymentResult? result;
  final String? error;
  final VoidCallback onPay;
  final VoidCallback onVerify;
}

/// Pago con Stripe Checkout: `POST /api/Pagos/checkout/{orden}` abre el
/// navegador y `GET /api/Pagos/resultado/{sessionId}` confirma el cobro.
class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.state, required this.price});

  final _PaymentState state;
  final double price;

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    final paid = result?.paid == true;
    return _SummaryCard(
      children: [
        Row(
          children: [
            Icon(
              paid ? Icons.verified_outlined : Icons.payment_outlined,
              color: paid ? const Color(0xFF147A1D) : const Color(0xFF00695C),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                paid ? 'Pago confirmado' : 'Pago de la orden',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              formatQuotePrice(price),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (result != null) ...[
          _SummaryRow(label: 'Estado del pago', value: result.label),
          if (result.message != null)
            _SummaryRow(label: 'Detalle', value: result.message!),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 6),
          SelectableText(
            state.error!,
            key: const Key('client-payment-error'),
            style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13),
          ),
        ],
        const SizedBox(height: 10),
        if (!paid)
          FilledButton.icon(
            key: const Key('client-pay-order'),
            onPressed: state.paying ? null : state.onPay,
            icon: state.paying
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_outline),
            label: Text(
              state.checkout == null
                  ? 'Pagar con Stripe'
                  : 'Volver a abrir el pago',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF635BFF),
            ),
          ),
        if (state.checkout?.sessionId != null && !paid) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('client-verify-payment'),
            onPressed: state.checking ? null : state.onVerify,
            icon: state.checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Ya pagué, verificar pago'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
        if (state.checkout != null && state.checkout!.sessionId == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'El servidor no devolvió el identificador de la sesión; el '
              'resultado del pago se verá cuando el yonke lo confirme.',
              style: TextStyle(color: Color(0xFF596276), fontSize: 12),
            ),
          ),
      ],
    );
  }
}
