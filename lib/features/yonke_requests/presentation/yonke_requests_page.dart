import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/api_providers.dart';
import '../data/yonke_requests_repository.dart';
import '../domain/yonke_request_summary.dart';
import 'yonke_bottom_navigation.dart';

class YonkeRequestsPage extends ConsumerStatefulWidget {
  const YonkeRequestsPage({
    super.key,
    required this.isDemoSession,
    this.repository,
  });

  final bool isDemoSession;
  final YonkeRequestsRepository? repository;

  @override
  ConsumerState<YonkeRequestsPage> createState() => _YonkeRequestsPageState();
}

class _YonkeRequestsPageState extends ConsumerState<YonkeRequestsPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late final YonkeRequestsRepository _repository;
  List<YonkeRequestSummary> _requests = const [];
  YonkeRequestFilters _filters = const YonkeRequestFilters();
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  bool _endpointPending = false;
  String? _error;
  DateTime? _lastUpdated;
  final _opening = <String>{};

  bool get _hasActiveQuery =>
      _searchController.text.trim().isNotEmpty || !_filters.isEmpty;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (widget.isDemoSession && AppConfig.enableMockAuth
            ? const DemoYonkeRequestsRepository()
            : ref.read(yonkeRequestsRepositoryProvider));
    _scrollController.addListener(_handleScroll);
    _load(refresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_hasMore || _loading || _loadingMore) return;
    if (_scrollController.position.extentAfter < 280) {
      _load(refresh: false);
    }
  }

  Future<void> _load({required bool refresh}) async {
    if (refresh) {
      if (_loading || _loadingMore) return;
      setState(() {
        _loading = true;
        _page = 1;
        _error = null;
        _endpointPending = false;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final result = await _repository.getAssignedRequests(
        page: refresh ? 1 : _page + 1,
        pageSize: 20,
        search: _searchController.text.trim(),
        filters: _filters,
      );
      if (!mounted) return;
      setState(() {
        _requests = refresh
            ? result.items
            : _mergeRequests(_requests, result.items);
        _page = result.page;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
        _lastUpdated = DateTime.now();
      });
    } on AssignedRequestsEndpointPendingException {
      if (!mounted) return;
      setState(() {
        _requests = const [];
        _loading = false;
        _loadingMore = false;
        _endpointPending = true;
        _hasMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'No pudimos cargar las solicitudes en este momento.';
      });
    }
  }

  List<YonkeRequestSummary> _mergeRequests(
    List<YonkeRequestSummary> current,
    List<YonkeRequestSummary> incoming,
  ) {
    final known = current.map((item) => item.requestYonkeId).toSet();
    return [
      ...current,
      ...incoming.where((item) => known.add(item.requestYonkeId)),
    ];
  }

  Future<void> _openFilters() async {
    final cities =
        _requests.map((item) => item.city).whereType<String>().toSet().toList()
          ..sort();
    final selected = await showModalBottomSheet<YonkeRequestFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _YonkeFiltersSheet(
        initial: _filters,
        cities: cities,
        demoMode: _repository.usesDemoData,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _filters = selected);
    await _load(refresh: true);
  }

  Future<void> _clearSearchAndFilters() async {
    _searchController.clear();
    setState(() => _filters = const YonkeRequestFilters());
    await _load(refresh: true);
  }

  Future<void> _openRequest(YonkeRequestSummary request) async {
    if (_opening.contains(request.requestYonkeId)) return;
    _opening.add(request.requestYonkeId);
    var current = request;
    try {
      if (request.isNew && request.requestYonkeId.isNotEmpty) {
        await _repository.markAsViewed(request.requestYonkeId);
        current = request.copyWith(status: YonkeRequestStatus.viewed);
        if (mounted) {
          setState(() {
            _requests = _requests
                .map(
                  (item) => item.requestYonkeId == request.requestYonkeId
                      ? current
                      : item,
                )
                .toList();
          });
        }
      }
      if (!mounted) return;
      context.push(
        AppRoutes.yonkeRequestDetail(request.requestYonkeId),
        extra: current,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar la solicitud. Inténtalo nuevamente.',
          ),
        ),
      );
    } finally {
      _opening.remove(request.requestYonkeId);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFBFD),
    appBar: AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFFAFBFD),
      surfaceTintColor: const Color(0xFFFAFBFD),
      title: const _YonkeWordmark(),
      actions: [
        IconButton(
          tooltip: 'Actualizar solicitudes',
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
              controller: _scrollController,
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
                  'Hola, yonke',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Solicitudes recibidas',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF092B61),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Revisa las refacciones solicitadas en tu zona.',
                  style: TextStyle(color: Color(0xFF596276)),
                ),
                const SizedBox(height: 18),
                if (_repository.usesDemoData) ...[
                  const _DemoBanner(),
                  const SizedBox(height: 16),
                ],
                TextField(
                  key: const Key('yonke-requests-search'),
                  controller: _searchController,
                  maxLength: 80,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(refresh: true),
                  decoration: InputDecoration(
                    hintText: 'Buscar pieza, vehículo o folio',
                    counterText: '',
                    prefixIcon: IconButton(
                      tooltip: 'Buscar solicitudes',
                      onPressed: () => _load(refresh: true),
                      icon: const Icon(Icons.search),
                    ),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, _) => value.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: () async {
                                _searchController.clear();
                                await _load(refresh: true);
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('yonke-open-filters'),
                      onPressed: _openFilters,
                      icon: const Icon(Icons.tune),
                      label: Text(
                        _filters.isEmpty
                            ? 'Filtros'
                            : 'Filtros (${_filters.activeCount})',
                      ),
                    ),
                    if (!_filters.isEmpty)
                      TextButton(
                        onPressed: _clearSearchAndFilters,
                        child: const Text('Limpiar filtros'),
                      ),
                    if (_lastUpdated != null)
                      Text(
                        'Actualizado ${_formatTime(_lastUpdated!)}',
                        style: const TextStyle(
                          color: Color(0xFF596276),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                if (!_filters.isEmpty) ...[
                  const SizedBox(height: 8),
                  _ActiveFilters(filters: _filters),
                ],
                const SizedBox(height: 18),
                ..._buildContent(context),
                if (_loadingMore) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: YonkeBottomNavigation(
      onRefresh: () => _load(refresh: true),
      selected: YonkeNavigationSection.requests,
      isDemoSession: widget.isDemoSession,
    ),
  );

  List<Widget> _buildContent(BuildContext context) {
    if (_loading) {
      return const [
        SizedBox(height: 80),
        Center(child: CircularProgressIndicator()),
        SizedBox(height: 12),
        Center(child: Text('Cargando solicitudes...')),
      ];
    }
    if (_endpointPending) {
      return [
        _StateMessage(
          icon: Icons.construction_outlined,
          title: 'Bandeja pendiente de conexión',
          message: 'La API todavía no documenta cómo consultar las solicitudes asignadas al yonke autenticado.',
          actionLabel: 'Reintentar',
          onAction: () => _load(refresh: true),
        ),
      ];
    }
    if (_error != null) {
      return [
        _StateMessage(
          icon: Icons.cloud_off_outlined,
          title: 'No pudimos cargar las solicitudes',
          message: _error!,
          actionLabel: 'Reintentar',
          onAction: () => _load(refresh: true),
        ),
      ];
    }
    if (_requests.isEmpty) {
      return [
        _StateMessage(
          icon: _hasActiveQuery
              ? Icons.search_off_outlined
              : Icons.inbox_outlined,
          title: _hasActiveQuery
              ? 'No encontramos solicitudes con esos filtros'
              : 'Todavía no tienes solicitudes asignadas',
          message: _hasActiveQuery
              ? 'Prueba otra búsqueda o limpia los filtros.'
              : 'Las solicitudes compatibles con tu cobertura aparecerán aquí.',
          actionLabel: _hasActiveQuery
              ? 'Limpiar búsqueda y filtros'
              : 'Actualizar',
          onAction: _hasActiveQuery
              ? _clearSearchAndFilters
              : () => _load(refresh: true),
        ),
      ];
    }

    return [
      _RequestSummaryGrid(requests: _requests),
      const SizedBox(height: 20),
      Text(
        '${_requests.length} solicitudes',
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      ..._requests.map(
        (request) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _YonkeRequestCard(
            request: request,
            opening: _opening.contains(request.requestYonkeId),
            onTap: () => _openRequest(request),
          ),
        ),
      ),
    ];
  }
}

class _YonkeWordmark extends StatelessWidget {
  const _YonkeWordmark();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'refaNet',
    child: ExcludeSemantics(
      child: Text.rich(
        const TextSpan(
          children: [
            TextSpan(
              text: 'refa',
              style: TextStyle(color: Color(0xFF092B61)),
            ),
            TextSpan(
              text: 'Net',
              style: TextStyle(color: Color(0xFF14951F)),
            ),
          ],
        ),
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
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
      color: const Color(0xFFEDF3FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.science_outlined, color: Color(0xFF114EB0)),
        SizedBox(width: 10),
        Expanded(child: Text('Solicitudes de prueba. No provienen de la API.')),
      ],
    ),
  );
}

class _RequestSummaryGrid extends StatelessWidget {
  const _RequestSummaryGrid({required this.requests});

  final List<YonkeRequestSummary> requests;

  @override
  Widget build(BuildContext context) {
    final values = <(String, int, Color)>[
      (
        'Nuevas',
        requests
            .where((item) => item.status == YonkeRequestStatus.newRequest)
            .length,
        const Color(0xFF114EB0),
      ),
      (
        'Vistas',
        requests
            .where((item) => item.status == YonkeRequestStatus.viewed)
            .length,
        const Color(0xFF596276),
      ),
      (
        'Cotizadas',
        requests
            .where((item) => item.status == YonkeRequestStatus.quoted)
            .length,
        const Color(0xFF6D3BB6),
      ),
      ('Total', requests.length, const Color(0xFF14951F)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: values
              .map(
                (value) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE1E6EE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${value.$2}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: value.$3,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(value.$1),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _YonkeRequestCard extends StatelessWidget {
  const _YonkeRequestCard({
    required this.request,
    required this.opening,
    required this.onTap,
  });

  final YonkeRequestSummary request;
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(request.status);
    return Semantics(
      button: true,
      label: '${request.part}, ${request.status.label}',
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: opening ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        request.part,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        request.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (request.vehicle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(request.vehicle),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    if (request.city != null)
                      _CardMeta(
                        icon: Icons.location_on_outlined,
                        text: request.city!,
                      ),
                    _CardMeta(
                      icon: Icons.schedule_outlined,
                      text: _formatDate(request.receivedAt),
                    ),
                    if (request.photoCount > 0)
                      _CardMeta(
                        icon: Icons.photo_library_outlined,
                        text: '${request.photoCount} fotos',
                      ),
                    if (request.folio != null)
                      _CardMeta(icon: Icons.tag, text: request.folio!),
                  ],
                ),
                if (opening) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardMeta extends StatelessWidget {
  const _CardMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: const Color(0xFF596276)),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Color(0xFF596276))),
    ],
  );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
    child: Column(
      children: [
        Icon(icon, size: 54, color: const Color(0xFF596276)),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    ),
  );
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.filters});

  final YonkeRequestFilters filters;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      if (filters.status != null) Chip(label: Text(filters.status!.label)),
      if (filters.city != null) Chip(label: Text(filters.city!)),
      if (filters.from != null && filters.to != null)
        Chip(
          label: Text(
            '${_formatDate(filters.from!)}–${_formatDate(filters.to!)}',
          ),
        ),
    ],
  );
}

class _YonkeFiltersSheet extends StatefulWidget {
  const _YonkeFiltersSheet({
    required this.initial,
    required this.cities,
    required this.demoMode,
  });

  final YonkeRequestFilters initial;
  final List<String> cities;
  final bool demoMode;

  @override
  State<_YonkeFiltersSheet> createState() => _YonkeFiltersSheetState();
}

class _YonkeFiltersSheetState extends State<_YonkeFiltersSheet> {
  late YonkeRequestFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initial;
  }

  Future<void> _selectDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _filters.from != null && _filters.to != null
          ? DateTimeRange(start: _filters.from!, end: _filters.to!)
          : null,
    );
    if (range != null) {
      setState(() {
        _filters = _filters.copyWith(from: range.start, to: range.end);
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filtrar solicitudes',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<YonkeRequestStatus>(
            key: const Key('yonke-status-filter'),
            initialValue: _filters.status,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: YonkeRequestStatus.values
                .where((status) => status != YonkeRequestStatus.unknown)
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(
              () => _filters = value == null
                  ? _filters.copyWith(clearStatus: true)
                  : _filters.copyWith(status: value),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _filters.city,
            decoration: InputDecoration(
              labelText: 'Ciudad',
              helperText: widget.demoMode
                  ? 'Ciudades de las solicitudes de prueba'
                  : 'Pendiente del endpoint de bandeja',
            ),
            items: widget.cities
                .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                .toList(),
            onChanged: widget.cities.isEmpty
                ? null
                : (value) => setState(
                    () => _filters = value == null
                        ? _filters.copyWith(clearCity: true)
                        : _filters.copyWith(city: value),
                  ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _selectDates,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              _filters.from == null || _filters.to == null
                  ? 'Seleccionar fechas'
                  : '${_formatDate(_filters.from!)}–${_formatDate(_filters.to!)}',
            ),
          ),
          if (_filters.from != null) ...[
            TextButton(
              onPressed: () => setState(
                () => _filters = _filters.copyWith(clearDates: true),
              ),
              child: const Text('Quitar fechas'),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('yonke-apply-filters'),
            onPressed: () => Navigator.pop(context, _filters),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF114EB0),
            ),
            child: const Text('Aplicar filtros'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const YonkeRequestFilters()),
            child: const Text('Limpiar todos'),
          ),
        ],
      ),
    ),
  );
}

Color _statusColor(YonkeRequestStatus status) => switch (status) {
  YonkeRequestStatus.newRequest => const Color(0xFF114EB0),
  YonkeRequestStatus.viewed => const Color(0xFF596276),
  YonkeRequestStatus.quoted => const Color(0xFF6D3BB6),
  YonkeRequestStatus.unavailable => const Color(0xFF9B2C24),
  YonkeRequestStatus.closed => const Color(0xFF48515A),
  YonkeRequestStatus.unknown => const Color(0xFF596276),
};

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
