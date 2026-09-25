import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../data/client_profile_repository.dart';
import '../domain/client_profile.dart';

const _navy = Color(0xFF07284D);
const _green = Color(0xFF41B928);
const _muted = Color(0xFF747B84);
const _page = Color(0xFFF8F9FA);

/// Registro del perfil del cliente nuevo y edición de "Mis datos".
///
/// Pide solo lo que existe en la tabla `Clientes` del API: nombre, celular,
/// correo y foto (opcional). En el registro llegan prellenados con lo que
/// entregó el login: nombre y correo de Google, o el teléfono verificado por
/// OTP (que nunca se usa como nombre).
class ClientOnboardingPage extends ConsumerStatefulWidget {
  const ClientOnboardingPage({
    super.key,
    this.editing = false,
    this.repository,
  });

  /// `false`: registro de un cliente nuevo; al guardar va al inicio.
  /// `true`: edición desde el perfil; al guardar regresa.
  final bool editing;
  final ClientProfileRepository? repository;

  @override
  ConsumerState<ClientOnboardingPage> createState() =>
      _ClientOnboardingPageState();
}

class _ClientOnboardingPageState extends ConsumerState<ClientOnboardingPage> {
  late final ClientProfileRepository _repository;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  ClientProfile _draft = const ClientProfile();
  bool _phoneLocked = false;
  bool _emailLocked = false;
  bool _loading = true;
  bool _saving = false;

  /// Foto elegida en esta pantalla, aún sin guardar.
  XFile? _newPhoto;
  bool _removePhoto = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? ref.read(clientProfileRepositoryProvider);
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final draft = widget.editing
        ? (await _repository.load()).profile
        : await _repository.draftForOnboarding();
    if (!mounted) return;
    _draft = draft;
    _name.text = draft.name ?? '';
    _phone.text = draft.phone ?? '';
    _email.text = draft.email ?? '';
    // En el registro, lo que confirmó el login no se edita: el teléfono
    // verificado por OTP y el correo de la cuenta de Google.
    _phoneLocked = !widget.editing && (draft.phone?.isNotEmpty ?? false);
    _emailLocked = !widget.editing && (draft.email?.isNotEmpty ?? false);
    setState(() => _loading = false);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.of(context).pop();
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (photo == null || !mounted) return;
      setState(() {
        _newPhoto = photo;
        _removePhoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la foto.')),
      );
    }
  }

  void _choosePhoto() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () => _pickPhoto(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: () => _pickPhoto(ImageSource.camera),
          ),
          if (_hasPhoto)
            ListTile(
              key: const Key('onboarding-remove-photo'),
              leading: const Icon(Icons.delete_outline),
              title: const Text('Quitar foto'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                setState(() {
                  _newPhoto = null;
                  _removePhoto = true;
                });
              },
            ),
        ],
      ),
    ),
  );

  bool get _hasPhoto =>
      _newPhoto != null ||
      (!_removePhoto && (_draft.photoPath != null || _draft.photoUrl != null));

  Future<void> _save() async {
    if (_saving) return;
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    try {
      var photoPath = _removePhoto ? null : _draft.photoPath;
      final photo = _newPhoto;
      if (photo != null) {
        final name = photo.name.contains('.')
            ? photo.name
            : '${photo.name}.jpg';
        photoPath = await _repository.savePhoto(
          await photo.readAsBytes(),
          extension: name.split('.').last,
        );
      }
      final previousPhoto = _draft.photoPath;
      if (previousPhoto != null && previousPhoto != photoPath) {
        await _repository.deletePhoto(previousPhoto);
      }
      await _repository.saveProfile(
        ClientProfile(
          id: _draft.id,
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim().toLowerCase(),
          // Datos de ciudad de versiones anteriores, si existían.
          city: _draft.city,
          stateId: _draft.stateId,
          stateName: _draft.stateName,
          cityId: _draft.cityId,
          cityName: _draft.cityName,
          photoPath: photoPath,
          photoUrl: _removePhoto ? null : _draft.photoUrl,
        ),
      );
      if (!mounted) return;
      if (widget.editing) {
        Navigator.of(context).pop(true);
      } else {
        context.go(AppRoutes.clientHome);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron guardar tus datos.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _page,
    appBar: AppBar(
      backgroundColor: _page,
      surfaceTintColor: _page,
      centerTitle: true,
      automaticallyImplyLeading: widget.editing,
      title: Text(
        widget.editing ? 'Mis datos' : 'Completa tu perfil',
        style: const TextStyle(color: _navy, fontWeight: FontWeight.w800),
      ),
    ),
    body: SafeArea(
      top: false,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  if (!widget.editing) ...[
                    const Text(
                      'Es tu primera vez en Refanet. Confirma tus datos para '
                      'que los yonkes puedan atenderte.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, height: 1.35),
                    ),
                    const SizedBox(height: 18),
                  ],
                  _PhotoPicker(
                    name: _name.text,
                    file: _newPhoto,
                    photoPath: _removePhoto ? null : _draft.photoPath,
                    photoUrl: _removePhoto ? null : _draft.photoUrl,
                    onTap: _choosePhoto,
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    key: const Key('profile-name-field'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('profile-phone-field'),
                    controller: _phone,
                    readOnly: _phoneLocked,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Celular *',
                      prefixIcon: const Icon(Icons.phone_iphone_outlined),
                      helperText: _phoneLocked ? 'Verificado por SMS' : null,
                    ),
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('profile-email-field'),
                    controller: _email,
                    readOnly: _emailLocked,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico *',
                      prefixIcon: const Icon(Icons.mail_outline),
                      helperText: _emailLocked
                          ? 'De tu cuenta de Google'
                          : null,
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 26),
                  FilledButton(
                    key: const Key('save-profile-data'),
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(
                      _saving
                          ? 'Guardando...'
                          : widget.editing
                          ? 'Guardar cambios'
                          : 'Guardar y continuar',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tus datos se guardan de forma segura en este dispositivo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
    ),
  );

  static String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 3) return 'Escribe tu nombre completo';
    if (RegExp(r'^[+\d\s()-]+$').hasMatch(text)) {
      return 'Escribe tu nombre, no un número';
    }
    return null;
  }

  static String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    return digits.length < 10 || digits.length > 15
        ? 'Escribe un celular de 10 dígitos'
        : null;
  }

  static String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
        ? null
        : 'Escribe un correo válido';
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.name,
    required this.file,
    required this.photoPath,
    required this.photoUrl,
    required this.onTap,
  });

  final String name;
  final XFile? file;
  final String? photoPath;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? image = file != null
        ? FileImage(File(file!.path))
        : photoPath != null
        ? FileImage(File(photoPath!))
        : photoUrl != null && photoUrl!.startsWith('https://')
        ? NetworkImage(photoUrl!)
        : null;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Column(
      children: [
        InkWell(
          key: const Key('onboarding-photo'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: CircleAvatar(
            radius: 46,
            backgroundColor: const Color(0xFF173B64),
            foregroundImage: image,
            child: initials.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 40)
                : Text(
                    initials,
                    style: const TextStyle(color: Colors.white, fontSize: 26),
                  ),
          ),
        ),
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.photo_camera_outlined, color: _green),
          label: Text(
            image == null ? 'Agregar foto (opcional)' : 'Cambiar foto',
            style: const TextStyle(color: _navy),
          ),
        ),
      ],
    );
  }
}
