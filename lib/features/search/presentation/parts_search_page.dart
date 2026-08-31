import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/api_providers.dart';
import '../../home/presentation/client_bottom_navigation.dart';
import '../../requests/domain/request_draft.dart';
import '../data/parts_search_repository.dart';
import '../domain/part_search.dart';

class PartsSearchPage extends ConsumerStatefulWidget {
  const PartsSearchPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<PartsSearchPage> createState() => _PartsSearchPageState();
}

enum _SearchStatus { initial, loading, results, empty, error, unavailable }

class _PartsSearchPageState extends ConsumerState<PartsSearchPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  PartSearchFilters _filters = const PartSearchFilters();
  List<PartSearchResult> _results = const [];
  List<SearchHistoryEntry> _history = const [];
  List<_CatalogOption> _brands = const [];
  _SearchStatus _status = _SearchStatus.initial;
  String? _validationMessage;
  String? _catalogMessage;
  bool _loadingCatalogs = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery?.trim() ?? '';
    _loadHistory();
    _loadCatalogs();
    if (_searchController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final entries = await ref.read(searchHistoryRepositoryProvider).read();
    if (mounted) setState(() => _history = entries);
  }

  Future<void> _loadCatalogs() async {
    setState(() {
      _loadingCatalogs = true;
      _catalogMessage = null;
    });
    if (AppConfig.enableMockAuth) {
      setState(() {
        _brands = _demoBrands;
        _loadingCatalogs = false;
      });
      return;
    }
    try {
      final response = await ref.read(catalogsApiProvider).getBrands();
      final brands = _catalogOptions(response, 'marca');
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _loadingCatalogs = false;
        if (brands.isEmpty) {
          _catalogMessage = 'No hay marcas disponibles en el catálogo.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCatalogs = false;
        _catalogMessage = 'No se pudieron cargar las marcas.';
      });
    }
  }

  Future<List<_CatalogOption>> _modelsForBrand(int brandId) async {
    if (AppConfig.enableMockAuth) return _demoModels[brandId] ?? const [];
    final response = await ref
        .read(catalogsApiProvider)
        .getModels(brandId: brandId);
    return _catalogOptions(response, 'modelo');
  }

  Future<void> _search({SearchHistoryEntry? historyEntry}) async {
    if (historyEntry != null) {
      _searchController.text = historyEntry.query;
      _filters = historyEntry.filters;
    }
    final query = _searchController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (query.isEmpty) {
      setState(
        () => _validationMessage = 'Escribe el nombre de una refacción.',
      );
      _searchFocus.requestFocus();
      return;
    }
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _searchFocus.unfocus();
    setState(() {
      _validationMessage = null;
      _status = _SearchStatus.loading;
    });
    try {
      final results = await ref
          .read(partsSearchRepositoryProvider)
          .search(query, _filters);
      await _remember(SearchHistoryEntry(query: query, filters: _filters));
      if (!mounted) return;
      setState(() {
        _results = results;
        _status = results.isEmpty ? _SearchStatus.empty : _SearchStatus.results;
      });
    } on SearchUnavailableException {
      if (!mounted) return;
      setState(() => _status = _SearchStatus.unavailable);
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _SearchStatus.error);
    }
  }

  Future<void> _remember(SearchHistoryEntry entry) async {
    final updated = [
      entry,
      ..._history.where((item) => item.identity != entry.identity),
    ].take(8).toList();
    setState(() => _history = updated);
    await ref.read(searchHistoryRepositoryProvider).write(updated);
  }

  Future<void> _removeHistory(SearchHistoryEntry entry) async {
    final updated = _history
        .where((item) => item.identity != entry.identity)
        .toList();
    setState(() => _history = updated);
    await ref.read(searchHistoryRepositoryProvider).write(updated);
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar historial'),
        content: const Text('¿Quieres eliminar todas las búsquedas recientes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _history = const []);
    await ref.read(searchHistoryRepositoryProvider).write(const []);
  }

  Future<void> _openFilters() async {
    final filters = await showModalBottomSheet<PartSearchFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FiltersSheet(
        initial: _filters,
        brands: _brands,
        loadingBrands: _loadingCatalogs,
        catalogMessage: _catalogMessage,
        loadModels: _modelsForBrand,
      ),
    );
    if (filters == null || !mounted) return;
    setState(() => _filters = filters);
    if (_searchController.text.trim().isNotEmpty) await _search();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _validationMessage = null;
      _status = _SearchStatus.initial;
      _results = const [];
    });
    _searchFocus.requestFocus();
  }

  void _createRequest({PartSearchResult? result}) {
    final draft = RequestDraft()
      ..part = result?.partName ?? _searchController.text.trim()
      ..brandId = result?.brandId ?? _filters.brandId
      ..brandName = result?.brandName ?? _filters.brandName
      ..modelId = result?.modelId ?? _filters.modelId
      ..modelName = result?.modelName ?? _filters.modelName
      ..year = result?.year ?? _filters.year
      ..description = null;
    context.push(AppRoutes.clientNewRequest, extra: draft);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFCFCFC),
    appBar: AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFFCFCFC),
      surfaceTintColor: const Color(0xFFFCFCFC),
      centerTitle: true,
      title: const Text('Buscar refacción'),
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
                    12,
                    MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
                    28,
                  ),
                  children: [
                    Semantics(
                      textField: true,
                      label: 'Buscar refacción por nombre',
                      child: TextField(
                        key: const Key('parts-search-field'),
                        controller: _searchController,
                        focusNode: _searchFocus,
                        maxLength: 80,
                        textInputAction: TextInputAction.search,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _search(),
                        onChanged: (_) {
                          if (_validationMessage != null) {
                            setState(() => _validationMessage = null);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Ej. Alternador, radiador o transmisión',
                          counterText: '',
                          errorText: _validationMessage,
                          prefixIcon: IconButton(
                            tooltip: 'Buscar',
                            onPressed: _search,
                            icon: const Icon(Icons.search),
                          ),
                          suffixIcon: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _searchController,
                            builder: (context, value, _) => value.text.isEmpty
                                ? const SizedBox.shrink()
                                : IconButton(
                                    tooltip: 'Limpiar búsqueda',
                                    onPressed: _clearSearch,
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          key: const Key('open-search-filters'),
                          onPressed: _openFilters,
                          icon: const Icon(Icons.tune),
                          label: Text(
                            _filters.activeCount == 0
                                ? 'Filtros'
                                : 'Filtros (${_filters.activeCount})',
                          ),
                        ),
                        if (!_filters.isEmpty) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              setState(
                                () => _filters = const PartSearchFilters(),
                              );
                              if (_searchController.text.trim().isNotEmpty) {
                                await _search();
                              }
                            },
                            child: const Text('Limpiar filtros'),
                          ),
                        ],
                      ],
                    ),
                    if (!_filters.isEmpty) ...[
                      const SizedBox(height: 8),
                      _ActiveFilters(
                        filters: _filters,
                        onChanged: (filters) async {
                          setState(() => _filters = filters);
                          if (_searchController.text.trim().isNotEmpty) {
                            await _search();
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 18),
                    _buildContent(context),
                  ],
                ),
              ),
            ),
          ),
          const ClientBottomNavigation(currentIndex: 1),
        ],
      ),
    ),
  );

  Widget _buildContent(BuildContext context) {
    switch (_status) {
      case _SearchStatus.initial:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_history.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Búsquedas recientes',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearHistory,
                    child: const Text('Borrar historial'),
                  ),
                ],
              ),
              ..._history.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(entry.query),
                  subtitle: entry.filters.isEmpty
                      ? null
                      : Text('${entry.filters.activeCount} filtros'),
                  onTap: () => _search(historyEntry: entry),
                  trailing: IconButton(
                    tooltip: 'Eliminar ${entry.query}',
                    onPressed: () => _removeHistory(entry),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Text(
              'Categorías sugeridas',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (AppConfig.enableMockAuth) ...[
              const _DemoNotice(),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories
                    .map(
                      (category) => ActionChip(
                        avatar: Icon(category.icon, size: 18),
                        label: Text(category.label),
                        onPressed: () => setState(
                          () => _filters = _filters.copyWith(
                            category: category.label,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ] else
              const Text(
                'El catálogo de categorías está pendiente de definición en la API.',
              ),
          ],
        );
      case _SearchStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 72),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text('Buscando refacciones...'),
              ],
            ),
          ),
        );
      case _SearchStatus.results:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ref.read(partsSearchRepositoryProvider).usesDemoData) ...[
              const _DemoNotice(),
              const SizedBox(height: 14),
            ],
            Text(
              '${_results.length} resultados',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ..._results.map(
              (result) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ResultCard(
                  result: result,
                  onRequest: () => _createRequest(result: result),
                ),
              ),
            ),
          ],
        );
      case _SearchStatus.empty:
        return _MessageState(
          icon: Icons.search_off,
          title: 'No encontramos refacciones con esos datos',
          message: 'Revisa el nombre o elimina alguno de los filtros.',
          actionLabel: 'Crear solicitud',
          onAction: _createRequest,
        );
      case _SearchStatus.unavailable:
        return _MessageState(
          icon: Icons.construction_outlined,
          title: 'Búsqueda pendiente de conexión',
          message: 'La API todavía no documenta un buscador de refacciones. Puedes crear la solicitud manualmente.',
          actionLabel: 'Crear solicitud',
          onAction: _createRequest,
        );
      case _SearchStatus.error:
        return _MessageState(
          icon: Icons.cloud_off_outlined,
          title: 'No pudimos realizar la búsqueda',
          message: 'Revisa tu conexión e inténtalo nuevamente.',
          actionLabel: 'Reintentar',
          onAction: _search,
        );
    }
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF8F0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: Color(0xFF147A1D)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Datos de demostración. La API aún no documenta la búsqueda de refacciones.',
          ),
        ),
      ],
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onRequest});

  final PartSearchResult result;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final vehicle = [
      result.brandName,
      result.modelName,
      result.year?.toString(),
    ].whereType<String>().join(' · ');
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.partName,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(result.category),
            if (vehicle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(vehicle, style: const TextStyle(color: Color(0xFF596276))),
            ],
            if (result.description != null) ...[
              const SizedBox(height: 10),
              Text(result.description!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRequest,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: const Color(0xFF14951F),
              ),
              child: const Text('Solicitar cotización'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
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
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 54),
    child: Column(
      children: [
        Icon(icon, size: 52, color: const Color(0xFF596276)),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        FilledButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    ),
  );
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.filters, required this.onChanged});

  final PartSearchFilters filters;
  final ValueChanged<PartSearchFilters> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      if (filters.category != null)
        InputChip(
          label: Text(filters.category!),
          onDeleted: () => onChanged(filters.copyWith(clearCategory: true)),
        ),
      if (filters.brandName != null)
        InputChip(
          label: Text(filters.brandName!),
          onDeleted: () => onChanged(filters.copyWith(clearBrand: true)),
        ),
      if (filters.modelName != null)
        InputChip(
          label: Text(filters.modelName!),
          onDeleted: () => onChanged(filters.copyWith(clearModel: true)),
        ),
      if (filters.year != null)
        InputChip(
          label: Text('${filters.year}'),
          onDeleted: () => onChanged(filters.copyWith(clearYear: true)),
        ),
    ],
  );
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({
    required this.initial,
    required this.brands,
    required this.loadingBrands,
    required this.catalogMessage,
    required this.loadModels,
  });

  final PartSearchFilters initial;
  final List<_CatalogOption> brands;
  final bool loadingBrands;
  final String? catalogMessage;
  final Future<List<_CatalogOption>> Function(int brandId) loadModels;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late PartSearchFilters _filters;
  List<_CatalogOption> _models = const [];
  bool _loadingModels = false;
  String? _modelsError;

  @override
  void initState() {
    super.initState();
    _filters = widget.initial;
    if (_filters.brandId != null) _loadModels(_filters.brandId!);
  }

  Future<void> _loadModels(int brandId) async {
    setState(() {
      _loadingModels = true;
      _modelsError = null;
    });
    try {
      final models = await widget.loadModels(brandId);
      if (!mounted) return;
      setState(() {
        _models = models;
        _loadingModels = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _models = const [];
        _loadingModels = false;
        _modelsError = 'No se pudieron cargar los modelos.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(
      DateTime.now().year - 1979,
      (index) => DateTime.now().year - index,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filtrar búsqueda',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              key: const Key('category-search-filter'),
              initialValue: _filters.category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Categoría',
                helperText: AppConfig.enableMockAuth
                    ? 'Catálogo de demostración'
                    : 'Catálogo pendiente de la API',
              ),
              items: AppConfig.enableMockAuth
                  ? _categories
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.label,
                            child: Text(item.label),
                          ),
                        )
                        .toList()
                  : const [],
              onChanged: AppConfig.enableMockAuth
                  ? (value) => setState(
                      () => _filters = value == null
                          ? _filters.copyWith(clearCategory: true)
                          : _filters.copyWith(category: value),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            if (widget.loadingBrands)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<int>(
                initialValue: _filters.brandId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Marca'),
                items: widget.brands
                    .map(
                      (brand) => DropdownMenuItem(
                        value: brand.id,
                        child: Text(brand.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  final brand = _findOption(widget.brands, value);
                  setState(() {
                    _filters = value == null
                        ? _filters.copyWith(clearBrand: true)
                        : _filters.copyWith(
                            brandId: value,
                            brandName: brand?.name,
                            clearModel: true,
                          );
                    _models = const [];
                  });
                  if (value != null) _loadModels(value);
                },
              ),
            if (widget.catalogMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.catalogMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey(_filters.brandId),
              initialValue: _filters.modelId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Modelo'),
              hint: Text(
                _loadingModels
                    ? 'Cargando modelos...'
                    : _filters.brandId == null
                    ? 'Primero selecciona una marca'
                    : 'Selecciona un modelo',
              ),
              items: _models
                  .map(
                    (model) => DropdownMenuItem(
                      value: model.id,
                      child: Text(model.name),
                    ),
                  )
                  .toList(),
              onChanged: _filters.brandId == null || _loadingModels
                  ? null
                  : (value) {
                      final model = _findOption(_models, value);
                      setState(
                        () => _filters = value == null
                            ? _filters.copyWith(clearModel: true)
                            : _filters.copyWith(
                                modelId: value,
                                modelName: model?.name,
                              ),
                      );
                    },
            ),
            if (_modelsError != null) ...[
              const SizedBox(height: 8),
              Text(_modelsError!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _filters.year,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Año'),
              items: years
                  .map(
                    (year) =>
                        DropdownMenuItem(value: year, child: Text('$year')),
                  )
                  .toList(),
              onChanged: (value) => setState(
                () => _filters = value == null
                    ? _filters.copyWith(clearYear: true)
                    : _filters.copyWith(year: value),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('apply-search-filters'),
              onPressed: () => Navigator.pop(context, _filters),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF14951F),
              ),
              child: const Text('Aplicar filtros'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, const PartSearchFilters()),
              child: const Text('Limpiar todos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogOption {
  const _CatalogOption({required this.id, required this.name});

  final int id;
  final String name;
}

_CatalogOption? _findOption(List<_CatalogOption> options, int? id) {
  for (final option in options) {
    if (option.id == id) return option;
  }
  return null;
}

List<_CatalogOption> _catalogOptions(dynamic response, String nameKey) {
  final data = response is Map ? response['data'] : response;
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map(
        (item) => _CatalogOption(
          id: (item['id'] as num?)?.toInt() ?? -1,
          name: item[nameKey]?.toString() ?? '',
        ),
      )
      .where((item) => item.id >= 0 && item.name.isNotEmpty)
      .toList();
}

const _demoBrands = [
  _CatalogOption(id: 1, name: 'Nissan'),
  _CatalogOption(id: 2, name: 'Toyota'),
  _CatalogOption(id: 3, name: 'Ford'),
];

const _demoModels = <int, List<_CatalogOption>>{
  1: [
    _CatalogOption(id: 1, name: 'Sentra'),
    _CatalogOption(id: 2, name: 'Versa'),
  ],
  2: [
    _CatalogOption(id: 3, name: 'Corolla'),
    _CatalogOption(id: 4, name: 'Hilux'),
  ],
  3: [
    _CatalogOption(id: 5, name: 'Focus'),
    _CatalogOption(id: 6, name: 'Ranger'),
  ],
};

typedef _CategoryItem = ({String label, IconData icon});

const _categories = <_CategoryItem>[
  (label: 'Motor', icon: Icons.settings_outlined),
  (label: 'Transmisión', icon: Icons.album_outlined),
  (label: 'Frenos', icon: Icons.radio_button_checked_outlined),
  (label: 'Eléctrico', icon: Icons.electric_bolt_outlined),
  (label: 'Suspensión', icon: Icons.car_repair_outlined),
  (label: 'Dirección', icon: Icons.turn_slight_right_outlined),
  (label: 'Enfriamiento', icon: Icons.ac_unit_outlined),
  (label: 'Combustible', icon: Icons.local_gas_station_outlined),
  (label: 'Escape', icon: Icons.air_outlined),
  (label: 'Clutch', icon: Icons.settings_input_component_outlined),
  (label: 'Carrocería', icon: Icons.directions_car_outlined),
  (label: 'Iluminación', icon: Icons.lightbulb_outline),
  (label: 'Cristales', icon: Icons.window_outlined),
  (label: 'Interior', icon: Icons.event_seat_outlined),
  (label: 'Aire acondicionado', icon: Icons.air_outlined),
  (label: 'Llantas y rines', icon: Icons.tire_repair_outlined),
  (label: 'Seguridad', icon: Icons.health_and_safety_outlined),
  (label: 'Accesorios', icon: Icons.extension_outlined),
];
