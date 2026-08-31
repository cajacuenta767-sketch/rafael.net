import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/api_providers.dart';
import '../data/yonke_quotes_repository.dart';
import '../domain/yonke_quote.dart';

class YonkeQuoteDetailPage extends ConsumerStatefulWidget {
  const YonkeQuoteDetailPage({
    super.key,
    required this.quoteId,
    required this.isDemoSession,
    this.initialQuote,
    this.repository,
  });

  final String quoteId;
  final bool isDemoSession;
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

  @override
  void initState() {
    super.initState();
    _quote = widget.initialQuote;
    _repository =
        widget.repository ??
        (widget.isDemoSession
            ? const DemoYonkeQuotesRepository()
            : ref.read(yonkeQuotesRepositoryProvider));
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
          if (quote.isDemo) ...[
            const _DetailDemoBanner(),
            const SizedBox(height: 14),
          ],
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
                    child: quote.imageUrls[index].startsWith('demo://')
                        ? Container(
                            color: const Color(0xFFE9ECEF),
                            child: const Icon(
                              Icons.car_repair_outlined,
                              size: 54,
                            ),
                          )
                        : Image.network(
                            quote.imageUrls[index],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: quote.canEdit ? () {} : null,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modificar cotización'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'La API permite actualizar por identificador, pero aún no define en qué estados puede modificarse. La edición permanecerá bloqueada hasta confirmar esa regla.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF596276), fontSize: 12),
          ),
        ],
      ),
    );
  }
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

class _DetailDemoBanner extends StatelessWidget {
  const _DetailDemoBanner();

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
        Expanded(child: Text('Detalle de cotización de prueba.')),
      ],
    ),
  );
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
