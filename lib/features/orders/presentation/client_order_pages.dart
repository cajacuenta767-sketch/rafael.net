import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../quotes/domain/client_quote.dart';
import '../../ratings/presentation/client_rating_page.dart';
import '../data/client_orders_repository.dart';
import '../domain/client_order_creation.dart';
import '../domain/client_order.dart';

class ClientOrderConfirmationArgs {
  const ClientOrderConfirmationArgs({
    required this.quote,
    required this.isDemo,
  });

  final ClientQuote quote;
  final bool isDemo;
}

class ClientOrderSuccessArgs {
  const ClientOrderSuccessArgs({
    required this.quote,
    required this.result,
    required this.isDemo,
  });

  final ClientQuote quote;
  final ClientOrderCreationResult result;
  final bool isDemo;
}

class ClientOrderTrackingArgs {
  const ClientOrderTrackingArgs({
    required this.quote,
    required this.isDemo,
    this.orderId,
  });

  final ClientQuote quote;
  final bool isDemo;
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
    _repository =
        widget.repository ??
        (widget.args.isDemo
            ? const DemoClientOrdersRepository()
            : ref.read(clientOrdersRepositoryProvider));
  }

  Future<void> _createOrder() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final result = await _repository.createOrder(widget.args.quote.id);
      if (!mounted) return;
      context.pushReplacement(
        AppRoutes.clientOrderSuccess,
        extra: ClientOrderSuccessArgs(
          quote: widget.args.quote,
          result: result,
          isDemo: widget.args.isDemo,
        ),
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
        title: const Text('Confirmar orden'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              children: [
                if (widget.args.isDemo) ...[
                  const _DemoBanner(),
                  const SizedBox(height: 18),
                ],
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
                  'Al confirmar, crearemos una orden para esta cotización.',
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
                      : const Text('Confirmar y crear orden'),
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
                    args.isDemo ? 'Orden de prueba creada' : 'Orden creada',
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
                          isDemo: args.isDemo,
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
                      extra: ClientRatingArgs(
                        quote: args.quote,
                        isDemo: args.isDemo,
                      ),
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

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.science_outlined, color: Color(0xFF8A5A00)),
        SizedBox(width: 10),
        Expanded(child: Text('Orden de prueba: no genera un cobro real.')),
      ],
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
  const ClientOrderTrackingPage({super.key, required this.args, this.repository});

  final ClientOrderTrackingArgs args;
  final ClientOrdersRepository? repository;

  @override
  ConsumerState<ClientOrderTrackingPage> createState() =>
      _ClientOrderTrackingPageState();
}

class _ClientOrderTrackingPageState
    extends ConsumerState<ClientOrderTrackingPage> {
  late final ClientOrdersRepository _repository;
  ClientOrder? _order;
  Object? _error;
  bool _loading = true;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (widget.args.isDemo
            ? const DemoClientOrdersRepository()
            : ref.read(clientOrdersRepositoryProvider));
    _load();
  }

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
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
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
          SnackBar(
            content: Text(
              widget.args.isDemo
                  ? 'Orden de prueba cancelada.'
                  : 'La cancelación fue enviada.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cancelar la orden. Inténtalo nuevamente.')),
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
                  isDemo: widget.args.isDemo,
                  cancelling: _cancelling,
                  onCancel: _cancel,
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
    required this.isDemo,
    required this.cancelling,
    required this.onCancel,
  });

  final ClientQuote quote;
  final ClientOrder order;
  final bool isDemo;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
    children: [
      if (isDemo) ...[
        const _DemoBanner(),
        const SizedBox(height: 18),
      ],
      Icon(
        order.isCancelled ? Icons.cancel_outlined : Icons.local_shipping_outlined,
        size: 58,
        color: order.isCancelled ? const Color(0xFFB3261E) : const Color(0xFF00695C),
      ),
      const SizedBox(height: 12),
      Text(
        order.isCancelled ? 'Orden cancelada' : 'Tu orden está registrada',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
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
          _SummaryRow(label: 'Estado', value: order.status ?? 'Pendiente de confirmar'),
          _SummaryRow(label: 'Yonke', value: quote.yonkeName),
          _SummaryRow(label: 'Cotización', value: quote.id),
          if (order.id != null) _SummaryRow(label: 'Orden', value: order.id!),
          if (order.createdAt != null)
            _SummaryRow(label: 'Creada', value: _formatDate(order.createdAt!)),
        ],
      ),
      if (order.responseContractPending) ...[
        const SizedBox(height: 16),
        const _OrderStatusInfoCard(contractPending: true),
      ],
      const SizedBox(height: 22),
      if (order.canCancel)
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
        Text('Aún no hay una orden para esta cotización', textAlign: TextAlign.center),
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
        const Icon(Icons.cloud_off_outlined, size: 64, color: Color(0xFF596276)),
        const SizedBox(height: 16),
        const Text('No se pudo consultar la orden.', textAlign: TextAlign.center),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
