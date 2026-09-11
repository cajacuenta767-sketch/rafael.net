import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../domain/request_draft.dart';

const _green = Color(0xFF42B91B);
const _greenDark = Color(0xFF26991D);
const _ink = Color(0xFF101820);
const _muted = Color(0xFF8B929B);

class NewRequestPage extends ConsumerStatefulWidget {
  const NewRequestPage({super.key, this.draft});
  final RequestDraft? draft;

  @override
  ConsumerState<NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends ConsumerState<NewRequestPage> {
  static const _maxPhotos = 3;
  static const _maxPhotoBytes = 10 * 1024 * 1024;
  final _partKey = GlobalKey<FormState>();
  final _vehicleKey = GlobalKey<FormState>();
  final _partController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  List<_CatalogOption> _brands = const [];
  List<_CatalogOption> _models = const [];
  int _step = 0;
  int? _brandId;
  int? _modelId;
  int? _year;
  String? _error;
  bool _loadingBrands = true;
  bool _loadingModels = false;
  bool _pickingPhoto = false;
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
    try {
      final response = await ref.read(catalogsApiProvider).getBrands();
      final brands = _catalogOptions(response, 'marca');
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _loadingBrands = false;
        _error = brands.isEmpty ? 'No hay marcas disponibles.' : null;
      });
      if (_brandId != null) await _loadModels(_brandId!, keepModel: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingBrands = false;
        _error = 'No se pudieron cargar las marcas.';
      });
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
      if (!mounted) return;
      setState(() {
        _models = models;
        _modelId = models.any((item) => item.id == previousModelId)
            ? previousModelId
            : null;
        _loadingModels = false;
        _error = models.isEmpty ? 'No hay modelos disponibles.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingModels = false;
        _error = 'No se pudieron cargar los modelos.';
      });
    }
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      context.pop();
    }
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      if (!(_partKey.currentState?.validate() ?? false)) return;
      _draft.part = _partController.text.trim();
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (!(_vehicleKey.currentState?.validate() ?? false)) return;
      _draft
        ..brandId = _brandId
        ..brandName = _selectedName(_brands, _brandId)
        ..modelId = _modelId
        ..modelName = _selectedName(_models, _modelId)
        ..year = _year;
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      _draft.description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      setState(() => _step = 3);
      return;
    }
    context.push(AppRoutes.clientRequestCity, extra: _draft);
  }

  Future<void> _choosePhoto() async {
    if (_pickingPhoto || _draft.photos.length >= _maxPhotos) {
      _showMessage('Puedes agregar hasta $_maxPhotos fotografías.');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: _greenDark,
                ),
                title: const Text('Elegir de galería'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: _greenDark,
                ),
                title: const Text('Tomar fotografía'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _pickingPhoto = true);
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      final extension = file.name.split('.').last.toLowerCase();
      if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        _showMessage('Selecciona una imagen JPG, PNG o WEBP.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxPhotoBytes) {
        _showMessage('Cada fotografía debe pesar menos de 10 MB.');
        return;
      }
      if (!mounted) return;
      setState(() => _draft.photos.add(RequestPhoto(file: file, bytes: bytes)));
    } catch (_) {
      if (mounted) _showMessage('No se pudo agregar la fotografía.');
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        tooltip: 'Regresar',
        onPressed: _goBack,
        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _ink),
      ),
      title: const Text(
        'Nueva solicitud',
        style: TextStyle(
          color: _ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              _RequestProgress(currentStep: _step),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: switch (_step) {
                    0 => _PartStep(
                      key: const ValueKey('part-step'),
                      formKey: _partKey,
                      controller: _partController,
                    ),
                    1 => _VehicleStep(
                      key: const ValueKey('vehicle-step'),
                      formKey: _vehicleKey,
                      brands: _brands,
                      models: _models,
                      brandId: _brandId,
                      modelId: _modelId,
                      year: _year,
                      loadingBrands: _loadingBrands,
                      loadingModels: _loadingModels,
                      error: _error,
                      onBrandChanged: (value) {
                        if (value != null) _loadModels(value);
                      },
                      onModelChanged: (value) =>
                          setState(() => _modelId = value),
                      onYearChanged: (value) => setState(() => _year = value),
                      onRetry: _brandId == null
                          ? _loadBrands
                          : () => _loadModels(_brandId!),
                    ),
                    2 => _DetailsStep(
                      key: const ValueKey('details-step'),
                      controller: _descriptionController,
                      part: _draft.part,
                      vehicle: _vehicleLabel,
                    ),
                    _ => _PhotosStep(
                      key: const ValueKey('photos-step'),
                      photos: _draft.photos,
                      picking: _pickingPhoto,
                      onAdd: _choosePhoto,
                      onRemove: (index) =>
                          setState(() => _draft.photos.removeAt(index)),
                    ),
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: _ContinueButton(onPressed: _continue),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  String get _vehicleLabel => [
    _draft.brandName,
    _draft.modelName,
    _draft.year?.toString(),
  ].whereType<String>().join(' ');
}

class _RequestProgress extends StatelessWidget {
  const _RequestProgress({required this.currentStep});
  final int currentStep;
  static const _labels = ['Parte', 'Vehículo', 'Detalles', 'Fotos'];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 5, 22, 20),
    child: Row(
      children: [
        for (var index = 0; index < _labels.length; index++) ...[
          Expanded(
            child: _ProgressItem(
              number: index + 1,
              label: _labels[index],
              active: index == currentStep,
              completed: index < currentStep,
            ),
          ),
          if (index < _labels.length - 1)
            Expanded(
              child: Container(
                height: 1.5,
                margin: const EdgeInsets.only(bottom: 20),
                color: index < currentStep ? _green : const Color(0xFFE3E7E9),
              ),
            ),
        ],
      ],
    ),
  );
}

class _ProgressItem extends StatelessWidget {
  const _ProgressItem({
    required this.number,
    required this.label,
    required this.active,
    required this.completed,
  });
  final int number;
  final String label;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || completed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: highlighted ? _greenDark : const Color(0xFFE7EAEC),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(
              color: highlighted ? Colors.white : const Color(0xFF687078),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: active ? _greenDark : _muted,
            fontSize: 9,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PartStep extends StatefulWidget {
  const _PartStep({super.key, required this.formKey, required this.controller});
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;

  @override
  State<_PartStep> createState() => _PartStepState();
}

class _PartStepState extends State<_PartStep> {
  static const _categories = [
    ('Carrocería', Icons.directions_car_outlined),
    ('Motor', Icons.settings_outlined),
    ('Suspensión', Icons.build_outlined),
    ('Transmisión', Icons.hub_outlined),
    ('Eléctrico', Icons.electric_bolt_outlined),
    ('Interior', Icons.airline_seat_recline_normal_outlined),
    ('Frenos', Icons.album_outlined),
    ('Enfriamiento', Icons.device_thermostat_outlined),
  ];
  String? _selected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿Qué autoparte buscas?',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('request-part-field'),
            controller: widget.controller,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Ej. Faro izquierdo, Puerta, Motor...',
              hintStyle: const TextStyle(color: _muted, fontSize: 12),
              suffixIcon: const Icon(Icons.search, color: _greenDark, size: 22),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: const BorderSide(color: Color(0xFFF0F1F2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: const BorderSide(color: _green),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Escribe la autoparte que buscas.'
                : null,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Categorías populares',
                style: TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Estas son todas las categorías disponibles.',
                    ),
                  ),
                ),
                child: const Text(
                  'Ver todas',
                  style: TextStyle(
                    color: _greenDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final category = _categories[index];
              return _CategoryCard(
                label: category.$1,
                icon: category.$2,
                selected: _selected == category.$1,
                onTap: () {
                  setState(() => _selected = category.$1);
                  widget.controller.text = category.$1;
                  widget.controller.selection = TextSelection.collapsed(
                    offset: widget.controller.text.length,
                  );
                },
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFF3FCEB) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: selected ? _green : const Color(0xFFEEF0F1)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 27, color: _ink),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: _ink,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _VehicleStep extends StatelessWidget {
  const _VehicleStep({
    super.key,
    required this.formKey,
    required this.brands,
    required this.models,
    required this.brandId,
    required this.modelId,
    required this.year,
    required this.loadingBrands,
    required this.loadingModels,
    required this.error,
    required this.onBrandChanged,
    required this.onModelChanged,
    required this.onYearChanged,
    required this.onRetry,
  });
  final GlobalKey<FormState> formKey;
  final List<_CatalogOption> brands;
  final List<_CatalogOption> models;
  final int? brandId;
  final int? modelId;
  final int? year;
  final bool loadingBrands;
  final bool loadingModels;
  final String? error;
  final ValueChanged<int?> onBrandChanged;
  final ValueChanged<int?> onModelChanged;
  final ValueChanged<int?> onYearChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(
      DateTime.now().year - 1979,
      (index) => DateTime.now().year - index,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cuéntanos de tu vehículo',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 22),
            if (loadingBrands)
              const Center(child: CircularProgressIndicator(color: _green))
            else
              DropdownButtonFormField<int>(
                key: const Key('request-brand-select'),
                initialValue: brandId,
                isExpanded: true,
                decoration: _selectDecoration('Marca *'),
                hint: const Text('Selecciona una marca'),
                items: brands
                    .map(
                      (brand) => DropdownMenuItem(
                        value: brand.id,
                        child: Text(brand.name),
                      ),
                    )
                    .toList(),
                onChanged: onBrandChanged,
                validator: (value) =>
                    value == null ? 'Selecciona una marca.' : null,
              ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              key: ValueKey('request-model-select-$brandId'),
              initialValue: modelId,
              isExpanded: true,
              decoration: _selectDecoration('Modelo *'),
              hint: Text(
                loadingModels
                    ? 'Cargando modelos...'
                    : brandId == null
                    ? 'Primero selecciona una marca'
                    : 'Selecciona un modelo',
              ),
              items: models
                  .map(
                    (model) => DropdownMenuItem(
                      value: model.id,
                      child: Text(model.name),
                    ),
                  )
                  .toList(),
              onChanged: loadingModels || brandId == null
                  ? null
                  : onModelChanged,
              validator: (value) =>
                  value == null ? 'Selecciona un modelo.' : null,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              key: const Key('request-year-select'),
              initialValue: year,
              isExpanded: true,
              decoration: _selectDecoration('Año *'),
              hint: const Text('Selecciona el año'),
              items: years
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text('$item')),
                  )
                  .toList(),
              onChanged: onYearChanged,
              validator: (value) => value == null ? 'Selecciona el año.' : null,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    super.key,
    required this.controller,
    required this.part,
    required this.vehicle,
  });
  final TextEditingController controller;
  final String part;
  final String vehicle;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Agrega más detalles',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ayuda a los yonkes a identificar exactamente la pieza.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAF5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5EFE1)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_car_outlined,
                  color: _greenDark,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vehicle,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: _greenDark, size: 22),
            ],
          ),
        ),
        const SizedBox(height: 22),
        TextFormField(
          controller: controller,
          minLines: 5,
          maxLines: 7,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Descripción adicional',
            hintText: 'Escribe detalles adicionales de la pieza (opcional)...',
            alignLabelWithHint: true,
            labelStyle: const TextStyle(color: _muted),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFFE7EBED)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: _green, width: 1.5),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PhotosStep extends StatelessWidget {
  const _PhotosStep({
    super.key,
    required this.photos,
    required this.picking,
    required this.onAdd,
    required this.onRemove,
  });

  final List<RequestPhoto> photos;
  final bool picking;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Agrega fotografías',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Muestra la pieza que necesitas desde distintos ángulos.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length + (photos.length < 5 ? 1 : 0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.18,
          ),
          itemBuilder: (context, index) {
            if (index == photos.length) {
              return _AddPhotoCard(picking: picking, onTap: onAdd);
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(photos[index].bytes, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 7,
                  right: 7,
                  child: IconButton.filled(
                    tooltip: 'Quitar fotografía ${index + 1}',
                    onPressed: () => onRemove(index),
                    icon: const Icon(Icons.close, size: 17),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xCC102030),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAF5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: _greenDark, size: 21),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Puedes continuar sin fotos o agregar hasta 5.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AddPhotoCard extends StatelessWidget {
  const _AddPhotoCard({required this.picking, required this.onTap});
  final bool picking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF9FBF8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFDCE9D7)),
    ),
    child: InkWell(
      key: const Key('request-add-photo'),
      onTap: picking ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Center(
        child: picking
            ? const CircularProgressIndicator(color: _greenDark)
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: _greenDark, size: 34),
                  SizedBox(height: 9),
                  Text(
                    'Agregar foto',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF79D42D), Color(0xFF22951D)],
      ),
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
          color: Color(0x252E9D1D),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('request-continue-button'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: const SizedBox(
          height: 54,
          child: Center(
            child: Text(
              'Continuar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    ),
  );
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

InputDecoration _selectDecoration(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: _muted),
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: Color(0xFFE7EBED)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: _green, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: Colors.redAccent),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
  ),
);
