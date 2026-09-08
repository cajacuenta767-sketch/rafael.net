import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/yonke_theme.dart';
import '../../../app/widgets/refanet_image.dart';
import '../../../core/di/api_providers.dart';
import '../../yonke_messages/presentation/yonke_messages_page.dart';
import '../data/yonke_quotes_repository.dart';
import '../domain/yonke_quote.dart';

class YonkeQuoteDetailPage extends ConsumerStatefulWidget {
  const YonkeQuoteDetailPage({
    super.key,
    required this.quoteId,
    this.initialQuote,
    this.repository,
  });

  final String quoteId;
  final YonkeQuote? initialQuote;
  final YonkeQuotesRepository? repository;

  @override
  ConsumerState<YonkeQuoteDetailPage> createState() =>
      _YonkeQuoteDetailPageState();
}

class _YonkeQuoteDetailPageState extends ConsumerState<YonkeQuoteDetailPage> {
  late YonkeQuotesRepository _repository;
  YonkeQuote? _quote;
  bool _loading = true;
  Object? _error;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _quote = widget.initialQuote;
    _repository = widget.repository ?? ref.read(yonkeQuotesRepositoryProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quote = await _repository.getById(widget.quoteId);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _editQuote(YonkeQuote quote) async {
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _QuoteEditSheet(quote: quote),
    );
    if (payload == null || !mounted) return;
    setState(() => _updating = true);
    try {
      await ref
          .read(quotesApiProvider)
          .update(quoteId: quote.id, payload: payload);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cotización actualizada correctamente.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar la cotización.')),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFBFD),
    appBar: AppBar(
      backgroundColor: const Color(0xFFFAFBFD),
      surfaceTintColor: const Color(0xFFFAFBFD),
      centerTitle: true,
      title: const Text('Detalle de cotización'),
      actions: [
        IconButton(
          tooltip: 'Actualizar cotización',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: _body(),
        ),
      ),
    ),
  );

  Widget _body() {
    if (_loading && _quote == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _quote == null) {
      return _DetailState(onRetry: _load);
    }
    final quote = _quote;
    if (quote == null) return _DetailState(onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
          12,
          MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
          28,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.part,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    if (quote.vehicle.isNotEmpty)
                      Text(
                        quote.vehicle,
                        style: const TextStyle(color: Color(0xFF596276)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _DetailStatus(status: quote.status),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            quote.available
                ? formatYonkeQuotePrice(quote.price)
                : 'No disponible',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF147A1D),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _DetailCard(
            title: 'Propuesta enviada',
            children: [
              _DetailRow(label: 'Condición', value: quote.condition),
              _DetailRow(label: 'Garantía', value: quote.warranty),
              if (quote.partNumber != null)
                _DetailRow(label: 'Núm. de parte', value: quote.partNumber!),
              if (quote.deliveryDays != null)
                _DetailRow(
                  label: 'Entrega',
                  value: '${quote.deliveryDays} días',
                ),
              _DetailRow(
                label: 'Envío',
                value: quote.shippingAvailable
                    ? quote.shippingCost == null
                          ? 'Disponible'
                          : formatYonkeQuotePrice(quote.shippingCost!)
                    : 'No disponible',
              ),
            ],
          ),
          if (quote.comments != null) ...[
            const SizedBox(height: 14),
            _DetailCard(
              title: 'Comentarios',
              children: [Text(quote.comments!)],
            ),
          ],
          const SizedBox(height: 14),
          _DetailCard(
            title: 'Solicitud relacionada',
            children: [
              if (quote.folio != null)
                _DetailRow(label: 'Folio', value: quote.folio!),
              _DetailRow(label: 'Pieza', value: quote.part),
              if (quote.vehicle.isNotEmpty)
                _DetailRow(label: 'Vehículo', value: quote.vehicle),
            ],
          ),
          const SizedBox(height: 14),
          _DetailCard(
            title: 'Fotografías (${quote.imageUrls.length})',
            children: [
              if (quote.imageUrls.isEmpty)
                const Text(
                  'No agregaste fotografías a esta cotización.',
                  style: TextStyle(color: Color(0xFF596276)),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: quote.imageUrls.length,
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RefanetImage(
                      source: quote.imageUrls[index],
                      fit: BoxFit.cover,
                      fallback: const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('yonke-open-conversation'),
            onPressed: () => context.push(
              AppRoutes.yonkeConversation(quote.id),
              extra: YonkeConversationArgs(quote: quote),
            ),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Mensajes con el cliente'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF114EB0),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('edit-yonke-quote'),
            onPressed: quote.canEdit && !_updating
                ? () => _editQuote(quote)
                : null,
            icon: const Icon(Icons.edit_outlined),
            label: Text(
              _updating ? 'Guardando cambios…' : 'Modificar cotización',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: YonkeColors.primaryNavy,
            ),
          ),
          if (!quote.canEdit) ...[
            const SizedBox(height: 8),
            const Text(
              'Las cotizaciones aceptadas, rechazadas o cerradas ya no pueden modificarse.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF596276), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuoteEditSheet extends StatefulWidget {
  const _QuoteEditSheet({required this.quote});
  final YonkeQuote quote;

  @override
  State<_QuoteEditSheet> createState() => _QuoteEditSheetState();
}

class _QuoteEditSheetState extends State<_QuoteEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _price = TextEditingController(
    text: widget.quote.price.toStringAsFixed(2),
  );
  late final _warrantyDays = TextEditingController(
    text: widget.quote.warrantyDays.toString(),
  );
  late final _shippingCost = TextEditingController(
    text: widget.quote.shippingCost?.toStringAsFixed(2) ?? '',
  );
  late final _comments = TextEditingController(text: widget.quote.comments);
  late bool _hasWarranty = widget.quote.hasWarranty;
  late bool _shipping = widget.quote.shippingAvailable;

  @override
  void dispose() {
    _price.dispose();
    _warrantyDays.dispose();
    _shippingCost.dispose();
    _comments.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, <String, dynamic>{
      'guidId': widget.quote.id,
      'solicitudYonkeGuidId': widget.quote.requestYonkeId,
      'precio': double.parse(_price.text.replaceAll(',', '.')),
      'disponible': widget.quote.available,
      'esNueva': widget.quote.isNew,
      'numeroParte': widget.quote.partNumber,
      'comentarios': _comments.text.trim(),
      'tieneGarantia': _hasWarranty,
      'diasGarantia': _hasWarranty ? int.tryParse(_warrantyDays.text) ?? 0 : 0,
      'envioDisponible': _shipping,
      'costoEnvio': _shipping && _shippingCost.text.trim().isNotEmpty
          ? double.tryParse(_shippingCost.text.replaceAll(',', '.'))
          : null,
      'tiempoEntregaDias': widget.quote.deliveryDays,
      'activo': widget.quote.active,
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      22,
      0,
      22,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Modificar cotización',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('edit-quote-price'),
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Precio',
                prefixText: r'$ ',
              ),
              validator: (value) {
                final number = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                return number == null || number <= 0
                    ? 'Escribe un precio válido'
                    : null;
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Incluye garantía'),
              value: _hasWarranty,
              onChanged: (value) => setState(() => _hasWarranty = value),
            ),
            if (_hasWarranty)
              TextFormField(
                controller: _warrantyDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Días de garantía',
                ),
              ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Envío disponible'),
              value: _shipping,
              onChanged: (value) => setState(() => _shipping = value),
            ),
            if (_shipping)
              TextFormField(
                controller: _shippingCost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Costo de envío (opcional)',
                  prefixText: r'$ ',
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _comments,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Comentarios'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('save-edited-quote'),
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: YonkeColors.primaryNavy,
              ),
              child: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE1E6EC)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(label, style: const TextStyle(color: Color(0xFF596276))),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _DetailStatus extends StatelessWidget {
  const _DetailStatus({required this.status});

  final YonkeQuoteStatus status;

  @override
  Widget build(BuildContext context) => Chip(label: Text(status.label));
}

class _DetailState extends StatelessWidget {
  const _DetailState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 54),
          const SizedBox(height: 14),
          const Text(
            'No pudimos cargar la cotización',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
