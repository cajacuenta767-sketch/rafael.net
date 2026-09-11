import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/yonke_theme.dart';
import '../../../core/di/api_providers.dart';
import '../data/yonke_requests_repository.dart';
import '../domain/yonke_request_summary.dart';
import 'widgets/yonke_request_card.dart';
import 'yonke_bottom_navigation.dart';

class YonkeRequestsPage extends ConsumerStatefulWidget {
  const YonkeRequestsPage({super.key, this.repository});

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

  int _totalCount = 0;
  int _newCount = 0;
  int _viewedCount = 0;
  int _quotedCount = 0;

  bool get _hasActiveQuery =>
      _searchController.text.trim().isNotEmpty || !_filters.isEmpty;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? ref.read(yonkeRequestsRepositoryProvider);
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

        if (_filters.status == null && _searchController.text.isEmpty) {
          _totalCount = _requests.length;
          _newCount = _requests
              .where((item) => item.status == YonkeRequestStatus.newRequest)
              .length;
          _viewedCount = _requests
              .where((item) => item.status == YonkeRequestStatus.viewed)
              .length;
          _quotedCount = _requests
              .where((item) => item.status == YonkeRequestStatus.quoted)
              .length;
        } else if (_totalCount == 0) {
          _totalCount = _requests.length;
        }
      });
    } on AssignedRequestsEndpointPendingException {
      if (!mounted) return;
      setState(() {
        _requests = const [];
        _totalCount = 0;
        _newCount = 0;
        _viewedCount = 0;
        _quotedCount = 0;
        _loading = false;
        _loadingMore = false;
        _endpointPending = true;
        _hasMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requests = const [];
        _totalCount = 0;
        _newCount = 0;
        _viewedCount = 0;
        _quotedCount = 0;
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
      builder: (context) =>
          _YonkeFiltersSheet(initial: _filters, cities: cities),
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

  void _onStatusPillSelected(YonkeRequestStatus? status) {
    setState(() {
      if (_filters.status == status) {
        _filters = _filters.copyWith(clearStatus: true);
      } else {
        _filters = _filters.copyWith(
          status: status,
          clearStatus: status == null,
        );
      }
    });
    _load(refresh: true);
  }

  Future<void> _openRequest(YonkeRequestSummary request) async {
    if (_opening.contains(request.requestYonkeId)) return;
    _opening.add(request.requestYonkeId);
    var current = request;
    try {
      if (request.isNew && request.requestYonkeId.isNotEmpty) {
        try {
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
        } catch (_) {
          // Si el backend no soporta marcar como vista esta forma, se continúa al detalle.
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
            'No se pudo abrir la solicitud. Inténtalo nuevamente.',
          ),
        ),
      );
    } finally {
      _opening.remove(request.requestYonkeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        backgroundColor: YonkeColors.primaryNavy,
        surfaceTintColor: YonkeColors.primaryNavy,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Solicitudes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Filtrar solicitudes',
            onPressed: _loading ? null : _openFilters,
            icon: const Icon(Icons.tune, color: Colors.white),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(51),
          child: _buildHeaderTabs(),
        ),
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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width < 380 ? 16 : 20,
                  14,
                  MediaQuery.sizeOf(context).width < 380 ? 16 : 20,
                  28,
                ),
                children: [
                  TextField(
                    key: const Key('yonke-requests-search'),
                    controller: _searchController,
                    maxLength: 80,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(refresh: true),
                    decoration: InputDecoration(
                      hintText: 'Buscar pieza, vehículo o folio',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: YonkeColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: YonkeColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: YonkeColors.primaryNavy,
                          width: 1.5,
                        ),
                      ),
                      prefixIcon: IconButton(
                        tooltip: 'Buscar solicitudes',
                        onPressed: () => _load(refresh: true),
                        icon: const Icon(
                          Icons.search,
                          color: YonkeColors.textSecondary,
                        ),
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
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Solicitudes recibidas',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: YonkeColors.primaryNavy,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
      ),
    );
  }

  Widget _buildHeaderTabs() => Row(
    children: [
      Expanded(
        child: _HeaderStatusTab(
          label: 'Nuevas',
          count: _newCount,
          selected: _filters.status == YonkeRequestStatus.newRequest,
          onTap: () => _onStatusPillSelected(YonkeRequestStatus.newRequest),
        ),
      ),
      Expanded(
        child: _HeaderStatusTab(
          label: 'En revisión',
          count: _viewedCount,
          selected: _filters.status == YonkeRequestStatus.viewed,
          onTap: () => _onStatusPillSelected(YonkeRequestStatus.viewed),
        ),
      ),
      Expanded(
        child: _HeaderStatusTab(
          label: 'Cotizadas',
          count: _quotedCount,
          selected: _filters.status == YonkeRequestStatus.quoted,
          onTap: () => _onStatusPillSelected(YonkeRequestStatus.quoted),
        ),
      ),
    ],
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
          message: 'La respuesta de la API no trae las solicitudes con la forma SolicitudYonkes que necesita esta bandeja. Se reportó al backend.',
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
      Text(
        '${_requests.length} solicitudes',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: YonkeColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      ..._requests.map(
        (request) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            children: [
              YonkeRequestCard(
                request: request,
                thumbnailOnLeft: false,
                onTap: () => _openRequest(request),
              ),
              if (_opening.contains(request.requestYonkeId)) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: LinearProgressIndicator(
                    color: YonkeColors.primaryNavy,
                    backgroundColor: Color(0xFFE1E6EE),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    ];
  }
}

class _HeaderStatusTab extends StatelessWidget {
  const _HeaderStatusTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFCAD4E3),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? Colors.white : const Color(0xFF445371),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? YonkeColors.primaryNavy
                      : const Color(0xFFE5EAF2),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 3,
          color: selected ? Colors.white : Colors.transparent,
        ),
      ],
    ),
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
  const _YonkeFiltersSheet({required this.initial, required this.cities});

  final YonkeRequestFilters initial;
  final List<String> cities;

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
            decoration: const InputDecoration(
              labelText: 'Ciudad',
              helperText: 'Ciudades de las solicitudes recibidas',
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
              backgroundColor: YonkeColors.primaryNavy,
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

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
