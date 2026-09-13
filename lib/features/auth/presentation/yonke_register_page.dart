import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/yonke_theme.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_file.dart';

import 'package:image_picker/image_picker.dart';

class YonkeRegisterPage extends ConsumerStatefulWidget {
  const YonkeRegisterPage({super.key});

  @override
  ConsumerState<YonkeRegisterPage> createState() => _YonkeRegisterPageState();
}

class _YonkeRegisterPageState extends ConsumerState<YonkeRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _managerController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _managerFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _cpFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _loading = false;
  String? _message;
  static const _maxLogoBytes = 2 * 1024 * 1024;
  Uint8List? _logoBytes;
  String? _logoFileName;
  bool _pickingLogo = false;

  List<_StateOption> _states = const [];
  List<_CityOption> _cities = const [];
  int? _selectedStateId;
  int? _selectedCityId;
  bool _loadingStates = false;
  bool _loadingCities = false;

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _managerController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cpController.dispose();
    _passwordController
      ..clear()
      ..dispose();
    _confirmPasswordController
      ..clear()
      ..dispose();
    _managerFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _addressFocus.dispose();
    _cpFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadStates() async {
    setState(() => _loadingStates = true);
    try {
      final response = await ref.read(catalogsApiProvider).getStates();
      final states = _statesFromResponse(response);
      if (!mounted) return;
      setState(() {
        _states = states;
        _loadingStates = false;
        if (states.isNotEmpty) {
          _selectedStateId = states.first.id;
          _loadCities(states.first.id);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStates = false);
    }
  }

  Future<void> _loadCities(int stateId) async {
    setState(() {
      _selectedStateId = stateId;
      _selectedCityId = null;
      _cities = const [];
      _loadingCities = true;
    });
    try {
      final response = await ref
          .read(catalogsApiProvider)
          .getCitiesByState(stateId);
      final cities = _citiesFromResponse(response);
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _selectedCityId = cities.isNotEmpty ? cities.first.id : null;
        _loadingCities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCities = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickLogo() async {
    if (_loading || _pickingLogo) return;
    setState(() => _pickingLogo = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        // Reglas del servidor (POST /api/Yonkes): máximo 2 MB y solo
        // JPG, JPEG o PNG. Se validan aquí para no recibir un 400 al final.
        final extension = picked.name.split('.').last.toLowerCase();
        if (!const {'jpg', 'jpeg', 'png'}.contains(extension)) {
          _showMessage('El logo debe ser una imagen JPG o PNG.');
          return;
        }
        final bytes = await picked.readAsBytes();
        if (bytes.length > _maxLogoBytes) {
          _showMessage('El logo debe pesar menos de 2 MB.');
          return;
        }
        if (!mounted) return;
        setState(() {
          _logoBytes = bytes;
          _logoFileName = picked.name;
        });
      }
    } catch (_) {
      // Ignorar cancelaciones o errores de permisos
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  Future<void> _submit() async {
    if (_loading || !(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedCityId == null) {
      setState(() => _message = 'Por favor selecciona la ciudad de tu yonke.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _message = null;
    });

    final fields = <String, dynamic>{
      'Nombre': _nameController.text.trim(),
      'Responsable': _managerController.text.trim(),
      'Telefono': _phoneController.text.trim(),
      'Correo': _emailController.text.trim().toLowerCase(),
      'Direccion': _addressController.text.trim(),
      'CP': int.tryParse(_cpController.text.trim()) ?? 0,
      'CiudadId': _selectedCityId,
      'Password': _passwordController.text,
      'ConfirmPassword': _confirmPasswordController.text,
    };

    Uint8List logoBytesToSend;
    String logoFileNameToSend;

    if (_logoBytes != null && _logoBytes!.isNotEmpty) {
      logoBytesToSend = _logoBytes!;
      logoFileNameToSend = _logoFileName ?? 'logo.png';
    } else {
      final byteData = await rootBundle.load(
        'assets/images/refanet_yonke_icon.png',
      );
      logoBytesToSend = byteData.buffer.asUint8List();
      logoFileNameToSend = 'refanet_yonke_logo.png';
    }

    final logoFile = ApiFile(
      fieldName: 'LogoUrl',
      fileName: logoFileNameToSend,
      bytes: logoBytesToSend,
    );

    try {
      await ref
          .read(yonkesApiProvider)
          .register(fields: fields, files: [logoFile]);
      if (!mounted) return;
      _showSuccessDialog();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message.isNotEmpty
            ? error.message
            : 'No pudimos completar el registro. Verifica los datos.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'No se pudo conectar con el servidor. Revisa tu conexión.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(
          Icons.check_circle_outline,
          color: YonkeColors.accentGreen,
          size: 56,
        ),
        title: const Text(
          '¡Yonke registrado!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: YonkeColors.primaryNavy,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Tu cuenta de yonke ha sido creada con éxito. Ahora puedes iniciar sesión con tus credenciales.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            key: const Key('yonke-register-success-ok'),
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.yonkeLogin);
            },
            style: FilledButton.styleFrom(
              backgroundColor: YonkeColors.primaryNavy,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Ir al inicio de sesión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_loading,
    child: Scaffold(
      backgroundColor: YonkeColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: YonkeColors.primaryNavy,
          ),
          tooltip: 'Regresar',
          onPressed: _loading ? null : () => context.pop(),
        ),
        title: const Text(
          'Afiliación de Yonke',
          style: TextStyle(
            color: YonkeColors.primaryNavy,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              constraints.maxWidth < 380 ? 16 : 24,
              16,
              constraints.maxWidth < 380 ? 16 : 24,
              32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        label: 'Logo refaNet Yonke',
                        image: true,
                        child: Center(
                          child: Image.asset(
                            YonkeAssets.logoTransparent,
                            width: 170,
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Registra tu Yonke',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: YonkeColors.primaryNavy,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Recibe solicitudes de autopartes y envía cotizaciones directamente a compradores.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: YonkeColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildSectionCard(
                        title: '1. Datos del negocio',
                        icon: Icons.storefront_outlined,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                InkWell(
                                  key: const Key('yonke-register-logo-button'),
                                  onTap: _loading ? null : _pickLogo,
                                  borderRadius: BorderRadius.circular(50),
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 42,
                                        backgroundColor: const Color(
                                          0xFFEDF2F9,
                                        ),
                                        backgroundImage: _logoBytes != null
                                            ? MemoryImage(_logoBytes!)
                                            : const AssetImage(
                                                'assets/images/refanet_yonke_icon.png',
                                              ) as ImageProvider,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundColor:
                                              YonkeColors.primaryNavy,
                                          child: const Icon(
                                            Icons.camera_alt,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: _loading ? null : _pickLogo,
                                  child: Text(
                                    _logoBytes != null
                                        ? 'Cambiar logo'
                                        : 'Subir logo del yonke (opcional)',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('yonke-register-name'),
                            controller: _nameController,
                            enabled: !_loading,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nombre comercial del Yonke *',
                              hintText: 'Ej. Yonke San José',
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingresa el nombre de tu yonke.'
                                : null,
                            onFieldSubmitted: (_) =>
                                _managerFocus.requestFocus(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('yonke-register-manager'),
                            controller: _managerController,
                            focusNode: _managerFocus,
                            enabled: !_loading,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del responsable o titular *',
                              hintText: 'Ej. Juan Pérez',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingresa el nombre del responsable.'
                                : null,
                            onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildSectionCard(
                        title: '2. Contacto y ubicación',
                        icon: Icons.location_on_outlined,
                        children: [
                          TextFormField(
                            key: const Key('yonke-register-phone'),
                            controller: _phoneController,
                            focusNode: _phoneFocus,
                            enabled: !_loading,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Teléfono de contacto (10 dígitos) *',
                              hintText: '6621234567',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) {
                              final p = v?.trim() ?? '';
                              if (p.isEmpty) return 'Ingresa tu teléfono.';
                              if (p.length < 10) {
                                return 'El teléfono debe tener 10 dígitos.';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('yonke-register-email'),
                            controller: _emailController,
                            focusNode: _emailFocus,
                            enabled: !_loading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.none,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico *',
                              hintText: 'contacto@yonkesanjose.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              final email = v?.trim() ?? '';
                              if (email.isEmpty) return 'Ingresa tu correo.';
                              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(email)) {
                                return 'Ingresa un correo electrónico válido.';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) =>
                                _addressFocus.requestFocus(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('yonke-register-address'),
                            controller: _addressController,
                            focusNode: _addressFocus,
                            enabled: !_loading,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Dirección física *',
                              hintText: 'Calle, número y colonia',
                              prefixIcon: Icon(Icons.map_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingresa la dirección de tu negocio.'
                                : null,
                            onFieldSubmitted: (_) => _cpFocus.requestFocus(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  key: const Key('yonke-register-cp'),
                                  controller: _cpController,
                                  focusNode: _cpFocus,
                                  enabled: !_loading,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'C.P. *',
                                    hintText: '83000',
                                    prefixIcon: Icon(
                                      Icons.local_post_office_outlined,
                                    ),
                                  ),
                                  validator: (v) {
                                    final cp = v?.trim() ?? '';
                                    if (cp.isEmpty) return 'Requerido.';
                                    if (cp.length != 5) return '5 dígitos.';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: _loadingStates
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.only(top: 14),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : DropdownButtonFormField<int>(
                                        isExpanded: true,
                                        initialValue: _selectedStateId,
                                        decoration: const InputDecoration(
                                          labelText: 'Estado *',
                                        ),
                                        items: _states
                                            .map(
                                              (state) => DropdownMenuItem<int>(
                                                value: state.id,
                                                child: Text(
                                                  state.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _loading
                                            ? null
                                            : (val) {
                                                if (val != null) {
                                                  _loadCities(val);
                                                }
                                              },
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _loadingCities
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  key: const Key(
                                    'yonke-register-city-dropdown',
                                  ),
                                  initialValue: _selectedCityId,
                                  decoration: const InputDecoration(
                                    labelText: 'Ciudad *',
                                    prefixIcon: Icon(
                                      Icons.location_city_outlined,
                                    ),
                                  ),
                                  items: _cities
                                      .map(
                                        (city) => DropdownMenuItem<int>(
                                          value: city.id,
                                          child: Text(
                                            city.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _loading
                                      ? null
                                      : (val) => setState(
                                          () => _selectedCityId = val,
                                        ),
                                  validator: (v) => v == null
                                      ? 'Selecciona una ciudad.'
                                      : null,
                                ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildSectionCard(
                        title: '3. Seguridad y acceso',
                        icon: Icons.lock_outline,
                        children: [
                          TextFormField(
                            key: const Key('yonke-register-password'),
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            enabled: !_loading,
                            obscureText: !_passwordVisible,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Contraseña (mínimo 8 caracteres) *',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _passwordVisible = !_passwordVisible,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Ingresa una contraseña.';
                              }
                              if (v.length < 8) {
                                return 'Debe tener al menos 8 caracteres.';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) =>
                                _confirmPasswordFocus.requestFocus(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('yonke-register-confirm-password'),
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocus,
                            enabled: !_loading,
                            obscureText: !_confirmPasswordVisible,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Confirmar contraseña *',
                              prefixIcon: const Icon(Icons.lock_reset_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _confirmPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _confirmPasswordVisible =
                                      !_confirmPasswordVisible,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Confirma tu contraseña.';
                              }
                              if (v != _passwordController.text) {
                                return 'Las contraseñas no coinciden.';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        ],
                      ),

                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE53935)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Color(0xFFB3261E),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _message!,
                                  style: const TextStyle(
                                    color: Color(0xFFB3261E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      FilledButton(
                        key: const Key('yonke-register-submit'),
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: YonkeColors.primaryNavy,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Registrando yonke...'),
                                ],
                              )
                            : const Text(
                                'Registrar mi Yonke',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _loading ? null : () => context.pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: YonkeColors.textSecondary,
                          ),
                          child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) => Card(
    elevation: 0.5,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: YonkeColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: YonkeColors.primaryNavy, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: YonkeColors.primaryNavy,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

class _StateOption {
  const _StateOption({required this.id, required this.name});
  final int id;
  final String name;
}

class _CityOption {
  const _CityOption({required this.id, required this.name});
  final int id;
  final String name;
}

List<_StateOption> _statesFromResponse(dynamic response) {
  final list = _records(response);
  return list
      .map(
        (r) => _StateOption(
          id: (r['id'] as num?)?.toInt() ?? -1,
          name: (r['entidad'] ?? '').toString().trim(),
        ),
      )
      .where((s) => s.id > 0 && s.name.isNotEmpty)
      .toList(growable: false);
}

List<_CityOption> _citiesFromResponse(dynamic response) {
  final list = _records(response);
  return list
      .map(
        (r) => _CityOption(
          id: (r['id'] as num?)?.toInt() ?? -1,
          name: (r['ciudad'] ?? '').toString().trim(),
        ),
      )
      .where((c) => c.id > 0 && c.name.isNotEmpty)
      .toList(growable: false);
}

List<Map<dynamic, dynamic>> _records(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  return data is List
      ? data.whereType<Map>().toList(growable: false)
      : const [];
}
