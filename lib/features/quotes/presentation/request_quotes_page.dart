import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/api_providers.dart';
import '../domain/client_quote.dart';

enum QuoteSort { lowestPrice, highestPrice, longestWarranty }

class RequestQuotesPage extends ConsumerStatefulWidget {
  const RequestQuotesPage({
    super.key,
    required this.requestId,
    this.requestTitle,
  });

  final String requestId;
  final String? requestTitle;

  @override
  ConsumerState<RequestQuotesPage> createState() => _RequestQuotesPageState();
}

class _RequestQuotesPageState extends ConsumerState<RequestQuotesPage> {
  List<ClientQuote> _quotes = const [];
  QuoteSort _sort = QuoteSort.lowestPrice;
  bool _loading = true;
  bool _usingTestData = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (widget.requestId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'La solicitud no tiene un identificador válido.';
      });
      return;
    }

    if (AppConfig.enableMockAuth) {
      setState(() {
        _quotes = mockQuotesForRequest(widget.requestId);
        _usingTestData = true;
        _loading = false;
      });
      return;
    }

    try {
      final response = await ref.read(dashboardApiProvider).getMyQuotes();
      final quotes = clientQuotesFromDashboard(response)
          .where((quote) => quote.requestId == widget.requestId)
          .toList();
      if (!mounted) return;
      setState(() {
        _quotes = quotes;
        _usingTestData = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'No se pudieron cargar las cotizaciones. Inténtalo nuevamente.';
      });
    }
  }

  List<ClientQuote> get _sortedQuotes {
    final result = [..._quotes];
    switch (_sort) {
      case QuoteSort.lowestPrice:
        result.sort((a, b) => a.price.compareTo(b.price));
      case QuoteSort.highestPrice:
        result.sort((a, b) => b.price.compareTo(a.price));
      case QuoteSort.longestWarranty:
        result.sort((a, b) => b.warrantyDays.compareTo(a.warrantyDays));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCFCFC),
        surfaceTintColor: const Color(0xFFFCFCFC),
        centerTitle: true,
        title: const Text('Cotizaciones recibidas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar cotizaciones',
            onPressed: _loading ? null : _loadQuotes,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _QuotesMessage(
        icon: Icons.cloud_off_outlined,
        title: 'No pudimos cargar las cotizaciones',
        message: _error!,
        onRetry: _loadQuotes,
      );
    }
    if (_quotes.isEmpty) {
      return _QuotesMessage(
        icon: Icons.local_offer_outlined,
        title: 'Aún no recibes cotizaciones',
        message:
            'Los yonkes podrán responder mientras la solicitud esté activa.',
        onRetry: _loadQuotes,
      );
    }

    final quotes = _sortedQuotes;
    final lowestPrice = _quotes
        .where((quote) => quote.available && quote.active)
        .map((quote) => quote.price)
        .fold<double?>(null, (lowest, price) {
          if (lowest == null || price < lowest) return price;
          return lowest;
        });

    return RefreshIndicator(
      onRefresh: _loadQuotes,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        itemCount: quotes.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _QuotesHeader(
              requestTitle: widget.requestTitle,
              count: quotes.length,
              sort: _sort,
              usingTestData: _usingTestData,
              onSortChanged: (value) => setState(() => _sort = value),
            );
          }
          final quote = quotes[index - 1];
          return _QuoteCard(
            quote: quote,
            bestPrice:
                lowestPrice != null &&
                quote.available &&
                quote.active &&
                quote.price == lowestPrice,
            onTap: () => context.push(
              AppRoutes.clientQuoteDetail(quote.id),
              extra: quote,
            ),
          );
        },
      ),
    );
  }
}

class _QuotesHeader extends StatelessWidget {
  const _QuotesHeader({
    required this.requestTitle,
    required this.count,
    required this.sort,
    required this.usingTestData,
    required this.onSortChanged,
  });

  final String? requestTitle;
  final int count;
  final QuoteSort sort;
  final bool usingTestData;
  final ValueChanged<QuoteSort> onSortChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (usingTestData) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF8F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF147A1D)),
              SizedBox(width: 10),
              Expanded(child: Text('Cotizaciones de prueba.')),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (requestTitle != null && requestTitle!.isNotEmpty) ...[
        Text(
          requestTitle!,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
      ],
      Text(
        '$count ${count == 1 ? 'cotización recibida' : 'cotizaciones recibidas'}',
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<QuoteSort>(
        initialValue: sort,
        decoration: const InputDecoration(labelText: 'Ordenar por'),
        items: const [
          DropdownMenuItem(
            value: QuoteSort.lowestPrice,
            child: Text('Menor precio'),
          ),
          DropdownMenuItem(
            value: QuoteSort.highestPrice,
            child: Text('Mayor precio'),
          ),
          DropdownMenuItem(
            value: QuoteSort.longestWarranty,
            child: Text('Mayor garantía'),
          ),
        ],
        onChanged: (value) {
          if (value != null) onSortChanged(value);
        },
      ),
    ],
  );
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.bestPrice,
    required this.onTap,
  });

  final ClientQuote quote;
  final bool bestPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${quote.yonkeName}, ${formatQuotePrice(quote.price)}, ${quote.availability}, garantía ${quote.warranty}',
    child: Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _YonkeLogo(name: quote.yonkeName, url: quote.logoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      quote.yonkeName,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (bestPrice) const Chip(label: Text('Mejor precio')),
                  _InfoChip(label: quote.availability),
                  _InfoChip(label: quote.condition),
                  _InfoChip(label: 'Garantía: ${quote.warranty}'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                formatQuotePrice(quote.price),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF147A1D),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (quote.shippingAvailable) ...[
                const SizedBox(height: 4),
                Text(
                  quote.shippingCost == null
                      ? 'Envío disponible'
                      : 'Envío: ${formatQuotePrice(quote.shippingCost!)}',
                  style: const TextStyle(color: Color(0xFF596276)),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _YonkeLogo extends StatelessWidget {
  const _YonkeLogo({required this.name, required this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      backgroundColor: const Color(0xFFE8F5EA),
      child: Text(name.isEmpty ? 'Y' : name.substring(0, 1).toUpperCase()),
    );
    if (url == null) return fallback;
    return CircleAvatar(
      backgroundColor: const Color(0xFFE8F5EA),
      foregroundImage: NetworkImage(url!),
      onForegroundImageError: (_, _) {},
      child: fallback.child,
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F3F5),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(label),
  );
}

class _QuotesMessage extends StatelessWidget {
  const _QuotesMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: const Color(0xFF596276)),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
