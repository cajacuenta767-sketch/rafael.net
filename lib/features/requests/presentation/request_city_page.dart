import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../domain/request_draft.dart';
import '../../catalogs/domain/location_options.dart';

class RequestCityPage extends ConsumerStatefulWidget {
  const RequestCityPage({super.key, required this.draft});

  final RequestDraft draft;

  @override
  ConsumerState<RequestCityPage> createState() => _RequestCityPageState();
}

class _RequestCityPageState extends ConsumerState<RequestCityPage> {
  List<StateOption> _states = const [];
  List<CityOption> _cities = const [];
  int? _selectedStateId;
  int? _selectedCityId;
  bool _loadingStates = true;
  bool _loadingCities = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedCityId = widget.draft.cityId;
    _loadStates();
  }

  Future<void> _loadStates() async {
    setState(() {
      _loadingStates = true;
      _error = null;
    });
    try {
      final response = await ref.read(catalogsApiProvider).getStates();
      final states = statesFromResponse(response);
      if (states.isEmpty) throw StateError('No hay estados disponibles.');
      if (!mounted) return;
      setState(() {
        _states = states;
        _selectedStateId = states.any((state) => state.id == _selectedStateId)
            ? _selectedStateId
            : states.first.id;
        _loadingStates = false;
      });
      await _loadCities(_selectedStateId!);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingStates = false;
        _error = 'No se pudieron cargar los estados. Inténtalo nuevamente.';
      });
    }
  }

  Future<void> _loadCities(int stateId) async {
    setState(() {
      _selectedStateId = stateId;
      _selectedCityId = null;
      _cities = const [];
      _loadingCities = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(catalogsApiProvider)
          .getCitiesByState(stateId);
      final stateName = _states
          .where((state) => state.id == stateId)
          .map((state) => state.name)
          .firstOrNull;
      final cities = citiesFromResponse(response, fallbackStateName: stateName);
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _selectedCityId = cities.any((city) => city.id == widget.draft.cityId)
            ? widget.draft.cityId
            : null;
        _loadingCities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCities = false;
        _error = 'No se pudieron cargar las ciudades. Inténtalo nuevamente.';
      });
    }
  }

  void _selectState(int? stateId) {
    if (stateId == null || stateId == _selectedStateId) return;
    _loadCities(stateId);
  }

  void _continue() {
    final city = _cities
        .where((city) => city.id == _selectedCityId)
        .firstOrNull;
    if (city == null) return;
    widget.draft
      ..cityId = city.id
      ..cityName = city.fullName;
    context.push(AppRoutes.clientRequestReview, extra: widget.draft);
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = !_loadingCities && _selectedCityId != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text('Selecciona tu ciudad'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Para enviar tu solicitud a los yonkes cercanos.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: const Color(0xFF30394B)),
                  ),
                  const SizedBox(height: 20),
                  if (_loadingStates)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null && _states.isEmpty)
                    Expanded(
                      child: _ErrorState(
                        message: _error!,
                        onRetry: _loadStates,
                      ),
                    )
                  else ...[
                    DropdownButtonFormField<int>(
                      key: const Key('request-state-selector'),
                      initialValue: _selectedStateId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      items: _states
                          .map(
                            (state) => DropdownMenuItem(
                              value: state.id,
                              child: Text(state.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _loadingCities ? null : _selectState,
                    ),
                    const SizedBox(height: 14),
                    Expanded(child: _citiesContent()),
                    const SizedBox(height: 12),
                    const Text(
                      'Ciudades obtenidas del catálogo de la API.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF596276), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: canContinue ? _continue : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: const Color(0xFF14951F),
                        disabledBackgroundColor: const Color(0xFFB8CFBA),
                      ),
                      child: const Text('Continuar'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _citiesContent() {
    if (_loadingCities) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorState(
        message: _error!,
        onRetry: () => _loadCities(_selectedStateId!),
      );
    }
    if (_cities.isEmpty) {
      return const Center(
        child: Text(
          'No hay ciudades disponibles para este estado.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      key: const Key('request-city-list'),
      padding: EdgeInsets.zero,
      itemCount: _cities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final city = _cities[index];
        final isSelected = city.id == _selectedCityId;
        return Semantics(
          button: true,
          selected: isSelected,
          label: '${city.fullName}${isSelected ? ', seleccionada' : ''}',
          child: InkWell(
            onTap: () => setState(() => _selectedCityId = city.id),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF15951F)
                      : const Color(0xFFE0E4EA),
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      city.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF202736),
                      ),
                    ),
                  ),
                  _SelectionCircle(selected: isSelected),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? const Color(0xFF15951F) : const Color(0xFFBEC5CF),
        width: 2,
      ),
    ),
    child: selected
        ? const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF15951F),
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 10, height: 10),
            ),
          )
        : null,
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
