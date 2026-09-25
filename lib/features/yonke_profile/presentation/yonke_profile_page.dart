import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/app_router.dart';
import '../../../app/widgets/refanet_image.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_file.dart';
import '../../../core/storage/token_store.dart';
import '../../../app/theme/yonke_theme.dart';
import '../../yonke_requests/presentation/yonke_bottom_navigation.dart';
import '../data/yonke_profile_repository.dart';
import '../domain/yonke_profile.dart';
import 'yonke_profile_controller.dart';

class YonkeProfilePage extends ConsumerStatefulWidget {
  const YonkeProfilePage({super.key, this.repository, this.tokenStore});

  final YonkeProfileRepository? repository;
  final TokenStore? tokenStore;

  @override
  ConsumerState<YonkeProfilePage> createState() => _YonkeProfilePageState();
}

class _YonkeProfilePageState extends ConsumerState<YonkeProfilePage> {
  late final YonkeProfileController _controller;
  late final TokenStore _tokenStore;
  bool _deactivating = false;

  @override
  void initState() {
    super.initState();
    final TokenStore store = widget.tokenStore ?? ref.read(tokenStoreProvider);
    _tokenStore = store;
    _controller = YonkeProfileController(
      widget.repository ?? ref.read(yonkeProfileRepositoryProvider),
      store,
    )..addListener(_refresh);
    _controller.load();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFBFD),
    appBar: AppBar(
      backgroundColor: YonkeColors.primaryNavy,
      surfaceTintColor: YonkeColors.primaryNavy,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: const Text(
        'Perfil del yonke',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
    ),
    body: SafeArea(top: false, child: _body()),
    bottomNavigationBar: YonkeBottomNavigation(
      selected: YonkeNavigationSection.profile,
      onRefresh: _controller.load,
    ),
  );

  Widget _body() {
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.error != null) {
      return _ProfileState(
        icon: Icons.cloud_off_outlined,
        title: 'No pudimos abrir el perfil',
        message: 'Revisa tu conexión e inténtalo nuevamente.',
        action: _controller.load,
      );
    }
    final snapshot = _controller.snapshot!;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          constraints.maxWidth < 380 ? 20 : 28,
          12,
          constraints.maxWidth < 380 ? 20 : 28,
          28,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AccountCard(
                  snapshot: snapshot,
                  onTap: snapshot.profile == null
                      ? null
                      : () => _openBusinessEditor(snapshot.profile!),
                ),
                const SizedBox(height: 24),
                _ProfileTile(
                  icon: Icons.storefront_outlined,
                  title: 'Información del negocio',
                  subtitle: 'Editar datos y logotipo',
                  onTap: snapshot.profile == null
                      ? null
                      : () => _openBusinessEditor(snapshot.profile!),
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.schedule_outlined,
                  title: 'Horario de atención',
                  onTap: () => _showUnavailable(
                    'La API todavía no publica el horario del negocio.',
                  ),
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.contact_phone_outlined,
                  title: 'Métodos de contacto',
                  onTap: () => _showBusinessData(snapshot),
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  key: const Key('yonke-profile-coverage'),
                  icon: Icons.settings_outlined,
                  title: 'Configuración',
                  subtitle: 'Cobertura y notificaciones',
                  onTap: () => context.push(AppRoutes.yonkeCoverage),
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.help_outline,
                  title: 'Ayuda y soporte',
                  onTap: () => _showUnavailable(
                    'El canal de soporte será publicado por el backend.',
                  ),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  key: const Key('yonke-sign-out'),
                  onPressed: _controller.signingOut ? null : _confirmSignOut,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: const Color(0xFFB3261E),
                    alignment: Alignment.centerLeft,
                  ),
                  icon: _controller.signingOut
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
                TextButton.icon(
                  key: const Key('yonke-deactivate-account'),
                  onPressed: _deactivating ? null : _confirmDeactivate,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: const Color(0xFF596276),
                    alignment: Alignment.centerLeft,
                  ),
                  icon: _deactivating
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_remove_outlined),
                  label: const Text('Dar de baja mi cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUnavailable(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showBusinessData(YonkeProfileSnapshot snapshot) {
    final profile = snapshot.profile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La sesión no incluye el identificador del yonke. Vuelve a iniciar sesión para consultar tus datos.',
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name ?? 'Datos del yonke',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _DataRow('Responsable', profile.manager),
              _DataRow('Teléfono', profile.phone),
              _DataRow('Correo', profile.email),
              _DataRow('Dirección', profile.fullAddress),
              const SizedBox(height: 12),
              const Text(
                'La edición de estos datos se habilitará en una próxima versión.',
                style: TextStyle(color: Color(0xFF596276), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBusinessEditor(YonkeProfile profile) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _YonkeProfileEditor(profile: profile)),
    );
    if (changed == true) await _controller.load();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que iniciar sesión nuevamente para consultar solicitudes y cotizaciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-yonke-sign-out'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _controller.signOut();
    if (mounted) context.go(AppRoutes.yonkeLogin);
  }

  /// Baja del asociado con `PUT /api/Yonkes/baja/byGuidId/{guidId}`.
  Future<void> _confirmDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Dar de baja tu cuenta?'),
        content: const Text(
          'Tu yonke dejará de recibir solicitudes y se cerrará la sesión. '
          'Para reactivarla tendrás que contactar a soporte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-yonke-deactivate'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final yonkeId =
        _controller.snapshot?.profile?.guidId ??
        await _tokenStore.readYonkeGuidId();
    if (yonkeId == null || yonkeId.isEmpty) {
      _showUnavailable(
        'La sesión no incluye el identificador del yonke. Vuelve a iniciar sesión.',
      );
      return;
    }
    setState(() => _deactivating = true);
    try {
      await ref.read(yonkesApiProvider).deactivate(yonkeId);
      await _tokenStore.clear();
      if (mounted) context.go(AppRoutes.start);
    } on ApiException catch (error) {
      if (mounted) {
        // El API publicado reserva la baja al rol Soporte.
        _showUnavailable(
          error.statusCode == 401 || error.statusCode == 403
              ? 'La baja de la cuenta la realiza el equipo de soporte de '
                    'Refanet. Escríbenos y la procesamos.'
              : error.message,
        );
      }
    } catch (_) {
      if (mounted) {
        _showUnavailable(
          'No se pudo dar de baja la cuenta. Inténtalo nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _deactivating = false);
    }
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.snapshot, this.onTap});
  final YonkeProfileSnapshot snapshot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final profile = snapshot.profile;
    final connected =
        snapshot.availability == YonkeProfileAvailability.available &&
        profile != null;
    return Material(
      color: YonkeColors.primaryNavy,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFF162A50),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: YonkeColors.accentGreen,
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: RefanetImage(
                  source: profile?.logoUrl,
                  fit: BoxFit.cover,
                  fallback: Image.asset(
                    YonkeAssets.icon,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.storefront_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected
                          ? profile.name ?? 'Cuenta del yonke'
                          : 'Cuenta del yonke',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connected
                          ? 'Yonke verificado'
                          : 'Perfil pendiente de sesión',
                      style: const TextStyle(
                        color: Color(0xFFD6DEEB),
                        fontSize: 12,
                      ),
                    ),
                    if (connected && profile.email != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        profile.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFD6DEEB),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                onTap == null ? Icons.storefront_outlined : Icons.edit_outlined,
                color: YonkeColors.accentGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YonkeProfileEditor extends ConsumerStatefulWidget {
  const _YonkeProfileEditor({required this.profile});
  final YonkeProfile profile;

  @override
  ConsumerState<_YonkeProfileEditor> createState() =>
      _YonkeProfileEditorState();
}

class _YonkeProfileEditorState extends ConsumerState<_YonkeProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.name);
  late final _manager = TextEditingController(text: widget.profile.manager);
  late final _phone = TextEditingController(text: widget.profile.phone);
  late final _email = TextEditingController(text: widget.profile.email);
  late final _address = TextEditingController(text: widget.profile.address);
  late final _postalCode = TextEditingController(
    text: widget.profile.postalCode?.toString(),
  );
  XFile? _logo;
  Uint8List? _logoBytes;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _manager.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1200,
    );
    if (file != null && mounted) {
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _logo = file;
          _logoBytes = bytes;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(yonkesApiProvider);
      await api.updateInfo(
        yonkeId: widget.profile.guidId,
        payload: {
          'guidId': widget.profile.guidId,
          'nombre': _name.text.trim(),
          'responsable': _manager.text.trim(),
          'telefono': _phone.text.trim(),
          'direccion': _address.text.trim(),
          'cp': int.tryParse(_postalCode.text.trim()),
          'ciudadId': widget.profile.cityId,
        },
      );
      final logo = _logo;
      if (logo != null) {
        await api.updateLogo(
          yonkeId: widget.profile.guidId,
          logo: ApiFile(
            fieldName: 'LogoUrl',
            fileName: logo.name,
            bytes: _logoBytes ?? await logo.readAsBytes(),
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'No se pudieron guardar los cambios.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFBFD),
    appBar: AppBar(centerTitle: true, title: const Text('Editar negocio')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Center(
            child: Stack(
              children: [
                Container(
                  width: 104,
                  height: 104,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEAF0FA),
                  ),
                  child: _logoBytes == null
                      ? RefanetImage(
                          source: widget.profile.logoUrl,
                          fit: BoxFit.cover,
                          fallback: const Icon(
                            Icons.storefront_outlined,
                            color: YonkeColors.primaryNavy,
                            size: 44,
                          ),
                        )
                      : Image.memory(_logoBytes!, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    key: const Key('change-yonke-logo'),
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.camera_alt_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _field(_name, 'Nombre del yonke', required: true),
          _field(_manager, 'Responsable', required: true),
          _field(_phone, 'Teléfono', keyboard: TextInputType.phone),
          // `updateInfo` no recibe el correo: es el usuario de acceso y lo
          // cambia soporte.
          _field(
            _email,
            'Correo',
            keyboard: TextInputType.emailAddress,
            readOnly: true,
            helper: 'Para cambiar el correo de acceso, contacta a soporte.',
          ),
          _field(_address, 'Dirección'),
          _field(_postalCode, 'Código postal', keyboard: TextInputType.number),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('save-yonke-profile'),
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: YonkeColors.primaryNavy,
            ),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboard,
    bool readOnly = false,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      readOnly: readOnly,
      decoration: InputDecoration(labelText: label, helperText: helper),
      validator: required
          ? (value) => value?.trim().isEmpty == true
                ? 'Este dato es obligatorio'
                : null
          : null,
    ),
  );
}

class _DataRow extends StatelessWidget {
  const _DataRow(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: const TextStyle(color: Color(0xFF596276))),
        ),
        Expanded(
          child: Text(
            value == null || value!.isEmpty ? 'Sin información' : value!,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFE0E4EA)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: ListTile(
      minTileHeight: 58,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Icon(icon, color: const Color(0xFF114EB0)),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _ProfileState extends StatelessWidget {
  const _ProfileState({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: const Color(0xFF596276)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: action,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF114EB0),
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}
