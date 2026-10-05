import '../../../app/widgets/responsive_scaffold.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../catalogs/domain/location_options.dart';
import '../domain/autoparts_catalog.dart';
import '../domain/request_draft.dart';

const _green = Color(0xFF42B91B);
const _greenDark = Color(0xFF26991D);
const _ink = Color(0xFF101820);
const _muted = Color(0xFF8B929B);

class NewRequestPage extends ConsumerStatefulWidget {
  const NewRequestPage({super.key, this.draft, this.initialStep});
  final RequestDraft? draft;
  final int? initialStep;

  @override
  ConsumerState<NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends ConsumerState<NewRequestPage> {
  static const _maxPhotos = 3;
  static const _maxPhotoBytes = 10 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _cityFormKey = GlobalKey<FormState>();
  final _partController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _partNumberController = TextEditingController();
  final _engineController = TextEditingController();
  final _picker = ImagePicker();

  List<_CatalogOption> _brands = const [];
  List<_CatalogOption> _models = const [];
  List<StateOption> _states = const [];
  List<CityOption> _cities = const [];

  int _step = 0;
  int? _brandId;
  int? _modelId;
  int? _year;
  String? _selectedSide;
  String? _selectedTransmission;
  int? _selectedStateId;
  int? _selectedCityId;

  String? _error;
  String? _cityError;
  bool _loadingBrands = true;
  bool _loadingModels = false;
  bool _loadingStates = false;
  bool _loadingCities = false;
  bool _pickingPhoto = false;

  late final RequestDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft ?? RequestDraft();
    _step = widget.initialStep ?? 0;
    _partController.text = _draft.part;
    _selectedSide = _draft.partSide;
    _partNumberController.text = _draft.partNumber ?? '';
    _engineController.text = _draft.engine ?? '';
    _selectedTransmission = _draft.transmission;
    _descriptionController.text = _draft.description ?? '';
    _brandId = _draft.brandId;
    _modelId = _draft.modelId;
    _year = _draft.year;
    _selectedStateId = _draft.stateId;
    _selectedCityId = _draft.cityId;

    _partController.addListener(() => setState(() {}));
    _loadBrands();
    if (_step == 3 || _selectedStateId != null) {
      _loadStates();
    }
  }

  @override
  void dispose() {
    _partController.dispose();
    _descriptionController.dispose();
    _partNumberController.dispose();
    _engineController.dispose();
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

  Future<void> _loadStates() async {
    if (_states.isNotEmpty) return;
    setState(() {
      _loadingStates = true;
      _cityError = null;
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
      if (_selectedStateId != null) {
        await _loadCities(_selectedStateId!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingStates = false;
        _cityError = 'No se pudieron cargar los estados.';
      });
    }
  }

  Future<void> _loadCities(int stateId) async {
    setState(() {
      _selectedStateId = stateId;
      _selectedCityId = null;
      _cities = const [];
      _loadingCities = true;
      _cityError = null;
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
        _selectedCityId = cities.any((city) => city.id == _draft.cityId)
            ? _draft.cityId
            : null;
        _loadingCities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCities = false;
        _cityError = 'No se pudieron cargar las ciudades.';
      });
    }
  }

  void _syncCurrentStepToDraft() {
    if (_step == 0) {
      _draft.part = _partController.text.trim();
      _draft.partSide = _selectedSide;
      _draft.brandId = _brandId;
      _draft.brandName = _selectedName(_brands, _brandId);
      _draft.modelId = _modelId;
      _draft.modelName = _selectedName(_models, _modelId);
      _draft.year = _year;
    } else if (_step == 1) {
      _draft.description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      _draft.partNumber = _partNumberController.text.trim().isEmpty
          ? null
          : _partNumberController.text.trim();
      _draft.engine = _engineController.text.trim().isEmpty
          ? null
          : _engineController.text.trim();
      _draft.transmission = _selectedTransmission;
    } else if (_step == 3) {
      final city = _cities.where((c) => c.id == _selectedCityId).firstOrNull;
      final state = _states.where((s) => s.id == _selectedStateId).firstOrNull;
      if (city != null) {
        _draft.cityId = city.id;
        _draft.cityName = city.fullName;
      }
      if (state != null) {
        _draft.stateId = state.id;
        _draft.stateName = state.name;
      }
    }
  }

  void _goToStep(int targetStep) {
    if (targetStep == _step) return;
    HapticFeedback.lightImpact();

    if (targetStep < _step) {
      _syncCurrentStepToDraft();
      setState(() => _step = targetStep);
      return;
    }

    // Si intenta saltar hacia adelante
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      _syncCurrentStepToDraft();
    } else if (_step == 1) {
      _syncCurrentStepToDraft();
    }

    if (targetStep == 3 && _states.isEmpty && !_loadingStates) {
      _loadStates();
    }
    setState(() => _step = targetStep);
  }

  Future<void> _goBack() async {
    if (_step > 0) {
      _syncCurrentStepToDraft();
      setState(() => _step--);
    } else {
      final hasData =
          _partController.text.isNotEmpty ||
          _brandId != null ||
          _partNumberController.text.isNotEmpty ||
          _engineController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty ||
          _draft.photos.isNotEmpty;
      if (hasData) {
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Descartar solicitud?'),
            content: const Text(
              'Si sales ahora se perderán los datos ingresados en tu solicitud.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continuar editando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if (leave == true && mounted) {
          context.pop();
        }
      } else {
        context.pop();
      }
    }
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    if (_step == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      _syncCurrentStepToDraft();
      setState(() => _step = 1);
      return;
    }

    if (_step == 1) {
      _syncCurrentStepToDraft();
      setState(() => _step = 2);
      return;
    }

    if (_step == 2) {
      if (_states.isEmpty && !_loadingStates) {
        _loadStates();
      }
      setState(() => _step = 3);
      return;
    }

    if (_step == 3) {
      if (!(_cityFormKey.currentState?.validate() ?? false)) return;
      final city = _cities
          .where((item) => item.id == _selectedCityId)
          .firstOrNull;
      if (city == null) {
        _showMessage('Selecciona una ciudad para continuar.');
        return;
      }
      final state = _states
          .where((item) => item.id == _selectedStateId)
          .firstOrNull;
      _draft
        ..stateId = state?.id
        ..stateName = state?.name
        ..cityId = city.id
        ..cityName = city.fullName;

      final targetStep = await context.push<int>(
        AppRoutes.clientRequestReview,
        extra: _draft,
      );
      if (targetStep != null && mounted) {
        setState(() => _step = targetStep);
      }
    }
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
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
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
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _goBack();
    },
    child: ResponsiveScaffold(
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
                _RequestProgress(currentStep: _step, onStepTapped: _goToStep),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: switch (_step) {
                      0 => _PartAndVehicleStep(
                        key: const ValueKey('part-and-vehicle-step'),
                        formKey: _formKey,
                        partController: _partController,
                        selectedSide: _selectedSide,
                        onSideChanged: (side) =>
                            setState(() => _selectedSide = side),
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
                      1 => _DetailsStep(
                        key: const ValueKey('details-step'),
                        descriptionController: _descriptionController,
                        partNumberController: _partNumberController,
                        engineController: _engineController,
                        selectedTransmission: _selectedTransmission,
                        onTransmissionChanged: (value) =>
                            setState(() => _selectedTransmission = value),
                        part: _partController.text.trim().isEmpty
                            ? _draft.part
                            : _partController.text.trim(),
                        partSide: _selectedSide,
                        vehicle: _vehicleLabel,
                      ),
                      2 => _PhotosStep(
                        key: const ValueKey('photos-step'),
                        photos: _draft.photos,
                        picking: _pickingPhoto,
                        onAdd: _choosePhoto,
                        onRemove: (index) =>
                            setState(() => _draft.photos.removeAt(index)),
                      ),
                      _ => _CityStep(
                        key: const ValueKey('city-step'),
                        formKey: _cityFormKey,
                        states: _states,
                        cities: _cities,
                        selectedStateId: _selectedStateId,
                        selectedCityId: _selectedCityId,
                        loadingStates: _loadingStates,
                        loadingCities: _loadingCities,
                        error: _cityError,
                        onStateChanged: (stateId) {
                          if (stateId != null) _loadCities(stateId);
                        },
                        onCityChanged: (cityId) =>
                            setState(() => _selectedCityId = cityId),
                        onRetry: _loadStates,
                      ),
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                  child: _ContinueButton(
                    label: _step == 3 ? 'Revisar solicitud' : 'Continuar',
                    onPressed: _continue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  String get _vehicleLabel => [
    _selectedName(_brands, _brandId) ?? _draft.brandName,
    _selectedName(_models, _modelId) ?? _draft.modelName,
    (_year ?? _draft.year)?.toString(),
  ].whereType<String>().join(' ');
}

class _RequestProgress extends StatelessWidget {
  const _RequestProgress({
    required this.currentStep,
    required this.onStepTapped,
  });

  final int currentStep;
  final ValueChanged<int> onStepTapped;
  static const _labels = ['Vehículo', 'Detalles', 'Fotos', 'Ciudad'];

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
        MediaQuery.sizeOf(context).height < 480) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Paso ${currentStep + 1} de 4 · ${_labels[currentStep]}',
                style: const TextStyle(
                  color: _greenDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            PopupMenuButton<int>(
              tooltip: 'Cambiar paso',
              onSelected: onStepTapped,
              itemBuilder: (_) => [
                for (var i = 0; i < _labels.length; i++)
                  PopupMenuItem(
                    value: i,
                    child: Text('${i + 1}. ${_labels[i]}'),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 5, 22, 14),
      child: Row(
        children: [
          for (var index = 0; index < _labels.length; index++) ...[
            Expanded(
              child: _ProgressItem(
                number: index + 1,
                label: _labels[index],
                active: index == currentStep,
                completed: index < currentStep,
                onTap: () => onStepTapped(index),
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
}

class _ProgressItem extends StatelessWidget {
  const _ProgressItem({
    required this.number,
    required this.label,
    required this.active,
    required this.completed,
    required this.onTap,
  });

  final int number;
  final String label;
  final bool active;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || completed;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlighted ? _green : Colors.transparent,
              border: Border.all(
                color: highlighted ? _green : const Color(0xFFC7CDD3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: completed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$number',
                      style: TextStyle(
                        color: active ? Colors.white : _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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
      ),
    );
  }
}

class _PartAndVehicleStep extends StatefulWidget {
  const _PartAndVehicleStep({
    super.key,
    required this.formKey,
    required this.partController,
    required this.selectedSide,
    required this.onSideChanged,
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
  final TextEditingController partController;
  final String? selectedSide;
  final ValueChanged<String?> onSideChanged;
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
  State<_PartAndVehicleStep> createState() => _PartAndVehicleStepState();
}

class _PartAndVehicleStepState extends State<_PartAndVehicleStep> {
  final _searchFocus = FocusNode();
  final _suggestionsScrollController = ScrollController();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onFocusChange);
    widget.partController.addListener(_onPartChanged);
  }

  void _onPartChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _showSuggestions = _searchFocus.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    widget.partController.removeListener(_onPartChanged);
    _searchFocus.removeListener(_onFocusChange);
    _searchFocus.dispose();
    _suggestionsScrollController.dispose();
    super.dispose();
  }

  bool get _hasExactMatch {
    final clean = normalizeText(widget.partController.text);
    if (clean.isEmpty) return false;
    return autopartsCatalog.any(
      (item) =>
          normalizeText(item.name) == clean ||
          item.aliases.any((a) => normalizeText(a) == clean),
    );
  }

  bool _checkPartNeedsSide(String partName) {
    final clean = normalizeText(partName);
    if (clean.length < 3) return false;
    const nonSided = {
      'motor',
      'transmision',
      'caja',
      'caja de velocidades',
      'radiador',
      'alternador',
      'bateria',
      'compresor a/c',
      'compresor',
      'marcha',
      'bomba de gasolina',
      'cremallera',
    };
    if (nonSided.contains(clean)) return false;

    return autopartsCatalog.any((item) {
      if (!item.hasSides) return false;
      final cleanItem = normalizeText(item.name);
      if (clean == cleanItem ||
          clean.contains(cleanItem) ||
          cleanItem.contains(clean)) {
        return true;
      }
      return item.aliases.any((a) {
        final cleanAlias = normalizeText(a);
        return clean == cleanAlias ||
            clean.contains(cleanAlias) ||
            cleanAlias.contains(clean);
      });
    });
  }

  Widget _highlightMatch(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final cleanText = normalizeText(text);
    final cleanQuery = normalizeText(query);
    final matchIndex = cleanText.indexOf(cleanQuery);

    if (matchIndex == -1 || matchIndex + query.length > text.length) {
      return Text(
        text,
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final before = text.substring(0, matchIndex);
    final matched = text.substring(matchIndex, matchIndex + query.length);
    final after = text.substring(matchIndex + query.length);

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(
            text: matched,
            style: const TextStyle(
              color: _greenDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(
      DateTime.now().year - 1979,
      (index) => DateTime.now().year - index,
    );

    final currentQuery = widget.partController.text.trim();
    final suggestions = searchAutoparts(currentQuery);
    final showSides = _checkPartNeedsSide(widget.partController.text);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdaptiveInline(
              children: [
                Text(
                  '¿Qué autoparte buscas?',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  '*',
                  style: TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('request-part-field'),
              controller: widget.partController,
              focusNode: _searchFocus,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onTap: () {
                if (!_showSuggestions) {
                  setState(() => _showSuggestions = true);
                }
              },
              decoration: InputDecoration(
                hintText: 'Ej. Faro, Espejo, Motor, Amortiguador...',
                hintStyle: const TextStyle(color: _muted, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search,
                  color: _greenDark,
                  size: 22,
                ),
                suffixIcon: widget.partController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Limpiar',
                        icon: const Icon(Icons.close, size: 18, color: _muted),
                        onPressed: () {
                          widget.partController.clear();
                          widget.onSideChanged(null);
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE2E6E9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _green, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Colors.redAccent,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Escribe la autoparte que buscas.'
                  : null,
            ),

            // Tarjeta de sugerencias de autocompletado y catálogo continuo
            if (_showSuggestions && !_hasExactMatch) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E6E9)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                      child: AdaptiveInline(
                        children: [
                          Expanded(
                            child: Text(
                              currentQuery.isEmpty
                                  ? 'CATÁLOGO DE AUTOPARTES (${suggestions.length})'
                                  : 'COINCIDENCIAS (${suggestions.length})',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '↕ Desliza para explorar',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    if (suggestions.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 270),
                        child: Scrollbar(
                          controller: _suggestionsScrollController,
                          thumbVisibility: true,
                          child: ListView.separated(
                            controller: _suggestionsScrollController,
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: suggestions.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              color: Color(0xFFF8FAFC),
                            ),
                            itemBuilder: (context, index) {
                              final item = suggestions[index];
                              return InkWell(
                                key: Key('autopart-suggestion-${item.name}'),
                                onTap: () {
                                  widget.partController.text = item.name;
                                  if (!item.hasSides) {
                                    widget.onSideChanged(null);
                                  }
                                  _searchFocus.unfocus();
                                  setState(() => _showSuggestions = false);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  child: AdaptiveInline(
                                    children: [
                                      const Icon(
                                        Icons.search,
                                        size: 18,
                                        color: _greenDark,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _highlightMatch(
                                          item.name,
                                          currentQuery,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F4F2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          item.category,
                                          style: const TextStyle(
                                            color: Color(0xFF4A5568),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else if (currentQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Text(
                          'No se encontraron piezas en el catálogo para "$currentQuery".',
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                      ),
                    if (currentQuery.isNotEmpty) ...[
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      InkWell(
                        key: const Key('autopart-custom-option'),
                        onTap: () {
                          _searchFocus.unfocus();
                          setState(() => _showSuggestions = false);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: AdaptiveInline(
                            children: [
                              const Icon(
                                Icons.add_circle_outline,
                                size: 18,
                                color: _greenDark,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Usar "$currentQuery" como pieza personalizada',
                                  style: const TextStyle(
                                    color: _greenDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Chips populares cuando el campo está vacío y no se está buscando
            if (widget.partController.text.isEmpty && !_showSuggestions) ...[
              const SizedBox(height: 10),
              const Text(
                'Búsquedas frecuentes:',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: AdaptiveInline(
                  children: popularAutopartChips.map((chip) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(chip),
                        backgroundColor: const Color(0xFFF5F7F8),
                        labelStyle: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onPressed: () {
                          widget.partController.text = chip;
                          _searchFocus.unfocus();
                          setState(() => _showSuggestions = false);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Selector de Lado / Posición para autopartes aplicables (ej. Espejo, Faro, Puerta)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: showSides
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAF5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE0EEDE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AdaptiveInline(
                              children: [
                                Icon(
                                  Icons.swap_horiz,
                                  size: 18,
                                  color: _greenDark,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Lado o posición de la pieza (opcional):',
                                    style: TextStyle(
                                      color: _ink,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  [
                                    'Izquierdo (Piloto)',
                                    'Derecho (Copiloto)',
                                    'Ambos / Par',
                                    'Delantero',
                                    'Trasero',
                                  ].map((side) {
                                    final isSelected =
                                        widget.selectedSide == side;
                                    return ChoiceChip(
                                      label: Text(side),
                                      selected: isSelected,
                                      selectedColor: const Color(0xFFE4F5DE),
                                      backgroundColor: Colors.white,
                                      labelStyle: TextStyle(
                                        color: isSelected
                                            ? _greenDark
                                            : const Color(0xFF4A5568),
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                      side: BorderSide(
                                        color: isSelected
                                            ? _greenDark
                                            : const Color(0xFFE2E8F0),
                                      ),
                                      onSelected: (selected) {
                                        widget.onSideChanged(
                                          selected ? side : null,
                                        );
                                      },
                                    );
                                  }).toList(),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),
            const Text(
              'Datos de tu vehículo',
              style: TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),

            // Dropdown de Marca (Zero-Flicker sin parpadeo)
            DropdownButtonFormField<int>(
              key: const Key('request-brand-select'),
              initialValue: widget.brandId,
              isExpanded: true,
              decoration: _selectDecoration(
                'Marca *',
                suffixIcon: widget.loadingBrands
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _greenDark,
                          ),
                        ),
                      )
                    : null,
              ),
              hint: Text(
                widget.loadingBrands
                    ? 'Cargando marcas...'
                    : 'Selecciona una marca',
              ),
              items: widget.brands
                  .map(
                    (brand) => DropdownMenuItem(
                      value: brand.id,
                      child: Text(brand.name),
                    ),
                  )
                  .toList(),
              onChanged: widget.loadingBrands ? null : widget.onBrandChanged,
              validator: (value) =>
                  value == null ? 'Selecciona una marca.' : null,
            ),
            const SizedBox(height: 16),

            // Dropdown de Modelo
            DropdownButtonFormField<int>(
              key: ValueKey('request-model-select-${widget.brandId}'),
              initialValue: widget.modelId,
              isExpanded: true,
              decoration: _selectDecoration(
                'Modelo *',
                suffixIcon: widget.loadingModels
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _greenDark,
                          ),
                        ),
                      )
                    : null,
              ),
              hint: Text(
                widget.loadingModels
                    ? 'Cargando modelos...'
                    : widget.brandId == null
                    ? 'Primero selecciona una marca'
                    : 'Selecciona un modelo',
              ),
              items: widget.models
                  .map(
                    (model) => DropdownMenuItem(
                      value: model.id,
                      child: Text(model.name),
                    ),
                  )
                  .toList(),
              onChanged: widget.loadingModels || widget.brandId == null
                  ? null
                  : widget.onModelChanged,
              validator: (value) =>
                  value == null ? 'Selecciona un modelo.' : null,
            ),
            const SizedBox(height: 16),

            // Dropdown de Año
            DropdownButtonFormField<int>(
              key: const Key('request-year-select'),
              initialValue: widget.year,
              isExpanded: true,
              decoration: _selectDecoration('Año *'),
              hint: const Text('Selecciona el año'),
              items: years
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text('$item')),
                  )
                  .toList(),
              onChanged: widget.onYearChanged,
              validator: (value) => value == null ? 'Selecciona el año.' : null,
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 12),
              Text(widget.error!, style: const TextStyle(color: Colors.red)),
              TextButton(
                onPressed: widget.onRetry,
                child: const Text('Reintentar'),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    super.key,
    required this.descriptionController,
    required this.partNumberController,
    required this.engineController,
    required this.selectedTransmission,
    required this.onTransmissionChanged,
    required this.part,
    required this.partSide,
    required this.vehicle,
  });

  final TextEditingController descriptionController;
  final TextEditingController partNumberController;
  final TextEditingController engineController;
  final String? selectedTransmission;
  final ValueChanged<String?> onTransmissionChanged;
  final String part;
  final String? partSide;
  final String vehicle;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
          'Ayuda a los yonkes a identificar con precisión la pieza compatible con tu vehículo.',
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
          child: AdaptiveInline(
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
                      part.isNotEmpty
                          ? '$part${partSide != null && partSide!.isNotEmpty ? ' ($partSide)' : ''}'
                          : 'Pieza sin especificar',
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
                      vehicle.isNotEmpty ? vehicle : 'Vehículo',
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
          key: const Key('request-part-number-field'),
          controller: partNumberController,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Número de parte / OEM (opcional)',
            hintText: 'Ej. 28100-0P060, OEM-12345',
            labelStyle: const TextStyle(color: _muted),
            prefixIcon: const Icon(Icons.tag, color: _greenDark, size: 20),
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
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('request-engine-field'),
          controller: engineController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Motor / Cilindrada (opcional)',
            hintText: 'Ej. 2.0L 4 Cilindros, V6 3.5L',
            labelStyle: const TextStyle(color: _muted),
            prefixIcon: const Icon(Icons.speed, color: _greenDark, size: 20),
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
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const Key('request-transmission-field'),
          initialValue: selectedTransmission,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Transmisión (opcional)',
            labelStyle: const TextStyle(color: _muted),
            prefixIcon: const Icon(
              Icons.settings_outlined,
              color: _greenDark,
              size: 20,
            ),
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
          hint: const Text('Selecciona tipo de transmisión'),
          items: const [
            DropdownMenuItem(value: 'Automática', child: Text('Automática')),
            DropdownMenuItem(
              value: 'Estándar / Manual',
              child: Text('Estándar / Manual'),
            ),
            DropdownMenuItem(value: 'CVT', child: Text('CVT')),
            DropdownMenuItem(
              value: 'Dual-Clutch / DSG',
              child: Text('Dual-Clutch / DSG'),
            ),
          ],
          onChanged: onTransmissionChanged,
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('request-description-field'),
          controller: descriptionController,
          minLines: 4,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Descripción adicional (opcional)',
            hintText: 'Describe el color deseado, versión del vehículo, detalles de la falla...',
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
        const SizedBox(height: 20),
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
          itemCount: photos.length + (photos.length < 3 ? 1 : 0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.18 / MediaQuery.textScalerOf(context).scale(1),
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
          child: const AdaptiveInline(
            children: [
              Icon(Icons.info_outline, color: _greenDark, size: 21),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Puedes continuar sin fotos o agregar hasta 3 (máx. 10 MB).',
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

class _CityStep extends StatelessWidget {
  const _CityStep({
    super.key,
    required this.formKey,
    required this.states,
    required this.cities,
    required this.selectedStateId,
    required this.selectedCityId,
    required this.loadingStates,
    required this.loadingCities,
    required this.error,
    required this.onStateChanged,
    required this.onCityChanged,
    required this.onRetry,
  });

  final GlobalKey<FormState> formKey;
  final List<StateOption> states;
  final List<CityOption> cities;
  final int? selectedStateId;
  final int? selectedCityId;
  final bool loadingStates;
  final bool loadingCities;
  final String? error;
  final ValueChanged<int?> onStateChanged;
  final ValueChanged<int?> onCityChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Selecciona tu ubicación',
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Para enviar tu solicitud a los yonkes con cobertura en tu zona.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 22),
          DropdownButtonFormField<int>(
            key: const Key('request-state-selector'),
            initialValue: selectedStateId,
            isExpanded: true,
            decoration: _selectDecoration(
              'Estado *',
              suffixIcon: loadingStates
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _greenDark,
                        ),
                      ),
                    )
                  : null,
            ),
            hint: Text(
              loadingStates ? 'Cargando estados...' : 'Selecciona tu estado',
            ),
            items: states
                .map(
                  (state) => DropdownMenuItem(
                    value: state.id,
                    child: Text(state.name),
                  ),
                )
                .toList(),
            onChanged: loadingStates ? null : onStateChanged,
            validator: (value) =>
                value == null ? 'Selecciona un estado.' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: ValueKey('request-city-selector-$selectedStateId'),
            initialValue: selectedCityId,
            isExpanded: true,
            decoration: _selectDecoration('Ciudad *'),
            hint: Text(
              loadingCities
                  ? 'Cargando ciudades...'
                  : selectedStateId == null
                  ? 'Primero selecciona un estado'
                  : 'Selecciona una ciudad',
            ),
            items: cities
                .map(
                  (city) => DropdownMenuItem(
                    value: city.id,
                    child: Text(city.fullName),
                  ),
                )
                .toList(),
            onChanged: loadingCities || selectedStateId == null
                ? null
                : onCityChanged,
            validator: (value) =>
                value == null ? 'Selecciona una ciudad.' : null,
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
  const _ContinueButton({required this.onPressed, this.label = 'Continuar'});

  final VoidCallback onPressed;
  final String label;

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
        child: SizedBox(
          height: 54,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
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

InputDecoration _selectDecoration(String label, {Widget? suffixIcon}) =>
    InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
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
