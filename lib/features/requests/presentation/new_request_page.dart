import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/api_providers.dart';
import '../domain/request_draft.dart';

class NewRequestPage extends ConsumerStatefulWidget {
  const NewRequestPage({super.key, this.draft});

  final RequestDraft? draft;

  @override
  ConsumerState<NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends ConsumerState<NewRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _partController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<_CatalogOption> _brands = const [];
  List<_CatalogOption> _models = const [];
  int? _brandId;
  int? _modelId;
  int? _year;
  String? _error;
  bool _loadingBrands = true;
  bool _loadingModels = false;
  bool _usingTestCatalogs = false;
  late final RequestDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft ?? RequestDraft();
    _partController.text = _draft.part;
    _descriptionController.text = _draft.description ?? '';
    _brandId = _draft.brandId;
    _modelId = _draft.modelId;
    _year = _draft.year;
    _loadBrands();
  }

  @override
  void dispose() {
    _partController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    setState(() {
      _loadingBrands = true;
      _error = null;
    });
    try {
      final response = await ref.read(catalogsApiProvider).getBrands();
      final brands = _catalogOptions(response, 'marca');
      if (brands.isEmpty) throw StateError('No hay marcas disponibles.');
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _loadingBrands = false;
        _usingTestCatalogs = false;
      });
      if (_brandId != null) await _loadModels(_brandId!, keepModel: true);
    } catch (_) {
      if (!mounted) return;
      if (AppConfig.enableMockAuth) {
        setState(() {
          _brands = _testBrands;
          _loadingBrands = false;
          _usingTestCatalogs = true;
        });
        if (_brandId != null) await _loadModels(_brandId!, keepModel: true);
      } else {
        setState(() {
          _loadingBrands = false;
          _error = 'No se pudieron cargar las marcas. Inténtalo nuevamente.';
        });
      }
    }
  }

  Future<void> _loadModels(int brandId, {bool keepModel = false}) async {
    final previousModelId = keepModel ? _modelId : null;
    setState(() {
      _brandId = brandId;
      _modelId = null;
      _models = const [];
      _loadingModels = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(catalogsApiProvider)
          .getModels(brandId: brandId);
      final models = _catalogOptions(response, 'modelo');
      if (models.isEmpty) throw StateError('No hay modelos disponibles.');
      if (!mounted) return;
      setState(() {
        _models = models;
        _modelId = models.any((model) => model.id == previousModelId)
            ? previousModelId
            : null;
        _loadingModels = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (_usingTestCatalogs) {
        setState(() {
          _models = _testModels[brandId] ?? const [];
          _modelId = _models.any((model) => model.id == previousModelId)
              ? previousModelId
              : null;
          _loadingModels = false;
        });
      } else {
        setState(() {
          _loadingModels = false;
          _error = 'No se pudieron cargar los modelos. Inténtalo nuevamente.';
        });
      }
    }
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _draft
      ..part = _partController.text.trim()
      ..brandId = _brandId
      ..brandName = _selectedName(_brands, _brandId)
      ..modelId = _modelId
      ..modelName = _selectedName(_models, _modelId)
      ..year = _year
      ..description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
    context.push(AppRoutes.clientRequestPhotos, extra: _draft);
  }

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(DateTime.now().year - 1979, (index) {
      return DateTime.now().year - index;
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text('Nueva solicitud'),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  minHeight: constraints.maxHeight - 52,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Información de la pieza',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _partController,
                        onChanged: (_) => setState(() {}),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la pieza *',
                          hintText: 'Alternador',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Ingresa la pieza que buscas.'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      if (_loadingBrands)
                        const Center(child: CircularProgressIndicator())
                      else
                        DropdownButtonFormField<int>(
                          initialValue: _brandId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Marca *',
                          ),
                          hint: const Text('Selecciona una marca'),
                          items: _brands
                              .map(
                                (brand) => DropdownMenuItem(
                                  value: brand.id,
                                  child: Text(brand.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) _loadModels(value);
                          },
                          validator: (value) =>
                              value == null ? 'Selecciona una marca.' : null,
                        ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<int>(
                        key: ValueKey(_brandId),
                        initialValue: _modelId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Modelo *',
                        ),
                        hint: Text(
                          _loadingModels
                              ? 'Cargando modelos...'
                              : _brandId == null
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
                        onChanged: _loadingModels || _brandId == null
                            ? null
                            : (value) => setState(() => _modelId = value),
                        validator: (value) =>
                            value == null ? 'Selecciona un modelo.' : null,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<int>(
                        initialValue: _year,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Año *'),
                        hint: const Text('Selecciona el año'),
                        items: years
                            .map(
                              (year) => DropdownMenuItem(
                                value: year,
                                child: Text('$year'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _year = value),
                        validator: (value) =>
                            value == null ? 'Selecciona el año.' : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 3,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Descripción adicional',
                          hintText: 'Original o compatible en buen estado.',
                        ),
                      ),
                      if (_usingTestCatalogs) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Marcas y modelos de prueba: el catálogo real se conectará al iniciar sesión con la API.',
                          style: TextStyle(color: Color(0xFF596276)),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        TextButton(
                          onPressed: _brandId == null
                              ? _loadBrands
                              : () => _loadModels(_brandId!),
                          child: const Text('Reintentar'),
                        ),
                      ],
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: _loadingBrands ? null : _continue,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: const Color(0xFF14951F),
                        ),
                        child: const Text('Continuar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _selectedName(List<_CatalogOption> options, int? id) {
  for (final option in options) {
    if (option.id == id) return option.name;
  }
  return null;
}

class _CatalogOption {
  const _CatalogOption({required this.id, required this.name});

  final int id;
  final String name;
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

const _testBrands = [
  _CatalogOption(id: 1, name: 'Nissan'),
  _CatalogOption(id: 2, name: 'Toyota'),
  _CatalogOption(id: 3, name: 'Ford'),
];

const _testModels = <int, List<_CatalogOption>>{
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
