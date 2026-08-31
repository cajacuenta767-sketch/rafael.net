import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../yonke_requests/presentation/yonke_bottom_navigation.dart';
import '../data/yonke_quotes_repository.dart';
import '../domain/yonke_quote.dart';

class YonkeQuotesPage extends ConsumerStatefulWidget {
  const YonkeQuotesPage({
    super.key,
    required this.isDemoSession,
    this.repository,
  });

  final bool isDemoSession;
  final YonkeQuotesRepository? repository;

  @override
  ConsumerState<YonkeQuotesPage> createState() => _YonkeQuotesPageState();
}

class _YonkeQuotesPageState extends ConsumerState<YonkeQuotesPage> {
  static const _pageSize = 20;
  final _searchController = TextEditingController();
  late YonkeQuotesRepository _repository;
  List<YonkeQuote> _quotes = const [];
  YonkeQuoteFilters _filters = const YonkeQuoteFilters();
  bool _loading = false;
  bool _loadingMore = false;
  bool _contractPending = false;
  int _page = 1;
  bool _hasMore = false;
  Object? _error;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (widget.isDemoSession
            ? const DemoYonkeQuotesRepository()
            : ref.read(yonkeQuotesRepositoryProvider));
    _load(refresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool refresh}) async {
    if (_loading || _loadingMore) return;
    setState(() {
      if (refresh) {
        _loading = true;
        _contractPending = false;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    final requestedPage = refresh ? 1 : _page + 1;
    try {
      final result = await _repository.getMyQuotes(
        page: requestedPage,
        pageSize: _pageSize,
        search: _searchController.text,
        filters: _filters,
      );
      if (!mounted) return;
      setState(() {
        _quotes = refresh ? result.items : [..._quotes, ...result.items];
        _page = result.page;
        _hasMore = result.hasMore;
        _updatedAt = DateTime.now();
        _loading = false;
        _loadingMore = false;
      });
    } on YonkeQuotesContractPendingException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _contractPending = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error;
      });
    }
  }

  Future<void> _openFilters() async {
    var status = _filters.status;
    var onlyAvailable = _filters.onlyAvailable;
    final result = await showModalBottomSheet<YonkeQuoteFilters>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filtrar cotizaciones',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<YonkeQuoteStatus?>(
                  key: const Key('yonke-quote-status-filter'),
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...YonkeQuoteStatus.values.map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    ),
                  ],
                  onChanged: (value) => setSheetState(() => status = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<bool?>(
                  initialValue: onlyAvailable,
                  decoration: const InputDecoration(
                    labelText: 'Disponibilidad',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todas')),
                    DropdownMenuItem(
                      value: true,
                      child: Text('Pieza disponible'),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text('No disponible'),
                    ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => onlyAvailable = value),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange:
                          _filters.from != null && _filters.to != null
                          ? DateTimeRange(
                              start: _filters.from!,
                              end: _filters.to!,
                            )
                          : null,
                    );
                    if (range != null && context.mounted) {
                      Navigator.pop(
                        context,
                        YonkeQuoteFilters(
                          status: status,
                          onlyAvailable: onlyAvailable,
                          from: range.start,
                          to: range.end,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    _filters.from == null
                        ? 'Elegir rango de fechas'
                        : '${_date(_filters.from!)} – ${_date(_filters.to!)}',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  key: const Key('apply-yonke-quote-filters'),
                  onPressed: () => Navigator.pop(
                    context,
                    YonkeQuoteFilters(
                      status: status,
                      onlyAvailable: onlyAvailable,
                      from: _filters.from,
                      to: _filters.to,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF14951F),
                  ),
                  child: const Text('Aplicar filtros'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, const YonkeQuoteFilters()),
                  child: const Text('Limpiar filtros'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _filters = result);
    await _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFBFD),
    appBar: AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFFAFBFD),
      surfaceTintColor: const Color(0xFFFAFBFD),
      title: const _Wordmark(),
      actions: [
        IconButton(
          tooltip: 'Actualizar cotizaciones',
          onPressed: _loading ? null : () => _load(refresh: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
                8,
                MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
                28,
              ),
              children: [
                Text(
                  'Cotizaciones enviadas',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Consulta las propuestas enviadas a los clientes.',
                  style: TextStyle(color: Color(0xFF596276)),
                ),
                if (_repository.usesDemoData) ...[
                  const SizedBox(height: 12),
                  const _DemoBanner(),
                ],
                const SizedBox(height: 16),
                TextField(
                  key: const Key('yonke-quotes-search'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(refresh: true),
                  decoration: InputDecoration(
                    hintText: 'Buscar pieza, vehículo, folio o número de parte',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: () {
                              _searchController.clear();
                              _load(refresh: true);
                            },
                            icon: const Icon(Icons.close),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      key: const Key('open-yonke-quote-filters'),
                      onPressed: _openFilters,
                      icon: const Icon(Icons.tune),
                      label: Text(
                        _filters.activeCount == 0
                            ? 'Filtros'
                            : 'Filtros (${_filters.activeCount})',
                      ),
                    ),
                    const Spacer(),
                    if (_updatedAt != null)
                      Flexible(
                        child: Text(
                          'Actualizado ${_time(_updatedAt!)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: Color(0xFF596276),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ..._buildContent(),
              ],
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: YonkeBottomNavigation(
      selected: YonkeNavigationSection.quotes,
      isDemoSession: widget.isDemoSession,
      onRefresh: () => _load(refresh: true),
    ),
  );

  List<Widget> _buildContent() {
    if (_loading) {
      return const [
        SizedBox(height: 80),
        Center(child: CircularProgressIndicator()),
      ];
    }
    if (_contractPending) {
      return const [
        _StateCard(
          icon: Icons.rule_folder_outlined,
          title: 'Contrato de lista pendiente',
          message: 'La API publica “mis-cotizaciones”, pero todavía no documenta la estructura de su respuesta. No se mostrarán datos inventados.',
        ),
      ];
    }
    if (_error != null) {
      return [
        _StateCard(
          icon: Icons.cloud_off_outlined,
          title: 'No pudimos cargar las cotizaciones',
          message: 'Comprueba tu conexión e inténtalo nuevamente.',
          action: OutlinedButton(
            onPressed: () => _load(refresh: true),
            child: const Text('Reintentar'),
          ),
        ),
      ];
    }
    if (_quotes.isEmpty) {
      return [
        _StateCard(
          icon: Icons.request_quote_outlined,
          title: _searchController.text.isNotEmpty || _filters.activeCount > 0
              ? 'No encontramos cotizaciones'
              : 'Todavía no has enviado cotizaciones',
          message: _searchController.text.isNotEmpty || _filters.activeCount > 0
              ? 'Prueba con otra búsqueda o limpia los filtros.'
              : 'Las cotizaciones que envíes aparecerán aquí.',
        ),
      ];
    }

    final accepted = _quotes
        .where((quote) => quote.status == YonkeQuoteStatus.accepted)
        .length;
    final active = _quotes.where((quote) => quote.active).length;
    return [
      _SummaryRow(total: _quotes.length, active: active, accepted: accepted),
      const SizedBox(height: 14),
      ..._quotes.map(
        (quote) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _QuoteCard(
            quote: quote,
            onTap: () => context.push(
              AppRoutes.yonkeQuoteDetail(quote.id),
              extra: quote,
            ),
          ),
        ),
      ),
      if (_hasMore)
        OutlinedButton(
          onPressed: _loadingMore ? null : () => _load(refresh: false),
          child: _loadingMore
              ? const CircularProgressIndicator()
              : const Text('Cargar más'),
        ),
    ];
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.total,
    required this.active,
    required this.accepted,
  });

  final int total;
  final int active;
  final int accepted;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _SummaryCard(label: 'Total', value: total),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _SummaryCard(label: 'Activas', value: active),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _SummaryCard(label: 'Aceptadas', value: accepted),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFE1E6EC)),
    ),
    child: Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        FittedBox(child: Text(label)),
      ],
    ),
  );
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, required this.onTap});

  final YonkeQuote quote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${quote.part}, ${formatYonkeQuotePrice(quote.price)}, ${quote.status.label}',
    child: Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE1E6EC)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      quote.part,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  _StatusChip(status: quote.status),
                ],
              ),
              if (quote.vehicle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  quote.vehicle,
                  style: const TextStyle(color: Color(0xFF596276)),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quote.available
                          ? formatYonkeQuotePrice(quote.price)
                          : 'No disponible',
                      style: const TextStyle(
                        color: Color(0xFF147A1D),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Text(
                    _date(quote.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF596276),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (quote.folio != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Folio ${quote.folio}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final YonkeQuoteStatus status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: _statusColor(status).withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      status.label,
      style: TextStyle(
        color: _statusColor(status),
        fontWeight: FontWeight.w800,
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
        Expanded(
          child: Text('Cotizaciones de prueba. No provienen de la API.'),
        ),
      ],
    ),
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE1E6EC)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 48, color: const Color(0xFF596276)),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => RichText(
    text: const TextSpan(
      style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
      children: [
        TextSpan(
          text: 'refa',
          style: TextStyle(color: Color(0xFF123B7A)),
        ),
        TextSpan(
          text: 'Net',
          style: TextStyle(color: Color(0xFF14951F)),
        ),
      ],
    ),
  );
}

Color _statusColor(YonkeQuoteStatus status) => switch (status) {
  YonkeQuoteStatus.sent => const Color(0xFF114EB0),
  YonkeQuoteStatus.viewed => const Color(0xFF6D3BB6),
  YonkeQuoteStatus.accepted => const Color(0xFF147A1D),
  YonkeQuoteStatus.rejected => const Color(0xFF9B1C1C),
  YonkeQuoteStatus.closed => const Color(0xFF596276),
  YonkeQuoteStatus.unknown => const Color(0xFF596276),
};

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
