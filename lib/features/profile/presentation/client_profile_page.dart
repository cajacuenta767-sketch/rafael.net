import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/presentation/legal_document_page.dart';
import '../../home/presentation/client_bottom_navigation.dart';
import '../data/client_profile_repository.dart';
import '../domain/client_profile.dart';
import 'client_profile_controller.dart';

const _navy = Color(0xFF07284D);
const _green = Color(0xFF41B928);
const _muted = Color(0xFF747B84);
const _page = Color(0xFFF8F9FA);

class ClientProfilePage extends ConsumerStatefulWidget {
  const ClientProfilePage({super.key, this.repository, this.tokenStore});

  final ClientProfileRepository? repository;
  final TokenStore? tokenStore;

  @override
  ConsumerState<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends ConsumerState<ClientProfilePage> {
  late final ClientProfileController _controller;
  late final ClientProfileRepository _repository;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    final TokenStore tokenStore =
        widget.tokenStore ?? ref.read(tokenStoreProvider);
    _repository =
        widget.repository ??
        LocalClientProfileRepository(tokenStore: tokenStore);
    _controller = ClientProfileController(_repository, tokenStore)
      ..addListener(_refresh);
    _controller.load();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final value = await _repository.readNotificationsEnabled();
    if (mounted) setState(() => _notificationsEnabled = value);
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
    backgroundColor: _page,
    appBar: AppBar(
      backgroundColor: _page,
      surfaceTintColor: _page,
      centerTitle: true,
      leading: IconButton(
        tooltip: 'Volver al inicio',
        onPressed: () => context.go(AppRoutes.clientHome),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text(
        'Mi perfil',
        style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
      ),
    ),
    body: SafeArea(top: false, child: _buildBody()),
    bottomNavigationBar: const ClientBottomNavigation(currentIndex: 4),
  );

  Widget _buildBody() {
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (_controller.error != null || _controller.snapshot == null) {
      return _ProfileMessage(onRetry: _controller.load);
    }

    final profile = _controller.snapshot!.profile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        _AccountCard(profile: profile, onTap: () => _openDetails(profile)),
        const SizedBox(height: 10),
        Material(
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x2607284D),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _MenuTile(
                key: const Key('profile-data'),
                icon: Icons.person_outline,
                title: 'Mis datos',
                onTap: () => _openDetails(profile),
              ),
              const Divider(height: 1, indent: 54),
              _MenuTile(
                key: const Key('profile-addresses'),
                icon: Icons.location_on_outlined,
                title: 'Direcciones',
                onTap: _openAddresses,
              ),
              const Divider(height: 1, indent: 54),
              _MenuTile(
                key: const Key('profile-payments'),
                icon: Icons.credit_card_outlined,
                title: 'Métodos de pago',
                onTap: _openPayments,
              ),
              const Divider(height: 1, indent: 54),
              _MenuTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notificaciones',
                trailing: Switch.adaptive(
                  key: const Key('profile-notifications'),
                  value: _notificationsEnabled,
                  activeTrackColor: _green,
                  onChanged: _setNotifications,
                ),
              ),
              const Divider(height: 1, indent: 54),
              _MenuTile(
                key: const Key('profile-help'),
                icon: Icons.help_outline_rounded,
                title: 'Ayuda y soporte',
                onTap: _openHelp,
              ),
              const Divider(height: 1, indent: 54),
              _MenuTile(
                key: const Key('client-sign-out'),
                icon: Icons.logout_rounded,
                title: 'Cerrar sesión',
                onTap: _controller.signingOut ? null : _confirmSignOut,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Los datos personales y las direcciones se guardan de forma segura en este dispositivo mientras el API publica el perfil del cliente.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 11, height: 1.35),
        ),
      ],
    );
  }

  Future<void> _openDetails(ClientProfile profile) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ClientDetailsPage(initial: profile, repository: _repository),
      ),
    );
    if (changed == true) await _controller.load();
  }

  void _openAddresses() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ClientAddressesPage(repository: _repository),
    ),
  );

  void _openPayments() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ClientPaymentMethodsPage()),
  );

  void _openHelp() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const ClientHelpPage()));

  Future<void> _setNotifications(bool enabled) async {
    setState(() => _notificationsEnabled = enabled);
    try {
      await _repository.writeNotificationsEnabled(enabled);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notificationsEnabled = !enabled);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la preferencia.')),
      );
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que iniciar sesión nuevamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-client-sign-out'),
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
    if (mounted) context.go(AppRoutes.clientLogin);
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.profile, required this.onTap});

  final ClientProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = profile.name?.trim().isNotEmpty == true
        ? profile.name!.trim()
        : 'Cliente Refanet';
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Material(
      color: _navy,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF173B64),
                  border: Border.all(color: _green, width: 1.2),
                ),
                child: Text(
                  initials.isEmpty ? 'CR' : initials,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Cliente',
                      style: TextStyle(color: Color(0xFFCCD6E0)),
                    ),
                    if (profile.email?.trim().isNotEmpty == true)
                      Text(
                        profile.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFCCD6E0),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _green),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 61,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    leading: Icon(icon, color: _navy, size: 22),
    title: Text(
      title,
      style: const TextStyle(
        color: Color(0xFF263343),
        fontWeight: FontWeight.w600,
      ),
    ),
    trailing:
        trailing ??
        (onTap == null
            ? null
            : const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB8BEC5),
              )),
    onTap: onTap,
  );
}

class ClientDetailsPage extends StatefulWidget {
  const ClientDetailsPage({
    super.key,
    required this.initial,
    required this.repository,
  });

  final ClientProfile initial;
  final ClientProfileRepository repository;

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _email = TextEditingController(text: widget.initial.email);
  late final _phone = TextEditingController(text: widget.initial.phone);
  late final _city = TextEditingController(text: widget.initial.city);
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _page,
    appBar: AppBar(title: const Text('Mis datos'), centerTitle: true),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _LocalNotice(),
          const SizedBox(height: 18),
          TextFormField(
            key: const Key('profile-name-field'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (value) =>
                value?.trim().isEmpty == true ? 'Escribe tu nombre' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo electrónico'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Celular'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'Ciudad'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('save-profile-data'),
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
          ),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    await widget.repository.saveProfile(
      ClientProfile(
        id: widget.initial.id,
        name: _name.text.trim(),
        email: _emptyToNull(_email.text),
        phone: _emptyToNull(_phone.text),
        city: _emptyToNull(_city.text),
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }
}

class ClientAddressesPage extends StatefulWidget {
  const ClientAddressesPage({super.key, required this.repository});

  final ClientProfileRepository repository;

  @override
  State<ClientAddressesPage> createState() => _ClientAddressesPageState();
}

class _ClientAddressesPageState extends State<ClientAddressesPage> {
  List<ClientAddress>? _addresses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.repository.loadAddresses();
    if (mounted) setState(() => _addresses = items);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _page,
    appBar: AppBar(title: const Text('Direcciones'), centerTitle: true),
    body: _addresses == null
        ? const Center(child: CircularProgressIndicator(color: _green))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const _LocalNotice(),
              const SizedBox(height: 16),
              if (_addresses!.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 45),
                  child: Column(
                    children: [
                      Icon(Icons.location_on_outlined, size: 50, color: _green),
                      SizedBox(height: 10),
                      Text('Todavía no agregaste direcciones.'),
                    ],
                  ),
                ),
              ..._addresses!.asMap().entries.map(
                (entry) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: _green,
                    ),
                    title: Text(entry.value.label),
                    subtitle: Text(
                      '${entry.value.street}\n${entry.value.city}${entry.value.postalCode == null ? '' : ' · ${entry.value.postalCode}'}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Eliminar dirección',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _remove(entry.key),
                    ),
                  ),
                ),
              ),
            ],
          ),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('add-address'),
      onPressed: _add,
      backgroundColor: _green,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Agregar'),
    ),
  );

  Future<void> _add() async {
    final address = await showModalBottomSheet<ClientAddress>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddressFormSheet(),
    );
    if (address == null) return;
    final updated = [...?_addresses, address];
    await widget.repository.saveAddresses(updated);
    if (mounted) setState(() => _addresses = updated);
  }

  Future<void> _remove(int index) async {
    final updated = [...?_addresses]..removeAt(index);
    await widget.repository.saveAddresses(updated);
    if (mounted) setState(() => _addresses = updated);
  }
}

class _AddressFormSheet extends StatefulWidget {
  const _AddressFormSheet();

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _label = TextEditingController(text: 'Casa');
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _postalCode = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _label.dispose();
    _street.dispose();
    _city.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Nueva dirección',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Nombre, por ejemplo Casa',
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('address-street-field'),
            controller: _street,
            decoration: const InputDecoration(labelText: 'Calle y número'),
            validator: (value) =>
                value?.trim().isEmpty == true ? 'Escribe la dirección' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('address-city-field'),
            controller: _city,
            decoration: const InputDecoration(labelText: 'Ciudad y estado'),
            validator: (value) =>
                value?.trim().isEmpty == true ? 'Escribe la ciudad' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _postalCode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Código postal'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('save-address'),
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Guardar dirección'),
          ),
        ],
      ),
    ),
  );

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      ClientAddress(
        label: _emptyToNull(_label.text) ?? 'Dirección',
        street: _street.text.trim(),
        city: _city.text.trim(),
        postalCode: _emptyToNull(_postalCode.text),
      ),
    );
  }
}

class ClientPaymentMethodsPage extends StatelessWidget {
  const ClientPaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _page,
    appBar: AppBar(title: const Text('Métodos de pago'), centerTitle: true),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.credit_card_outlined, size: 58, color: _green),
          const SizedBox(height: 16),
          const Text(
            'El pago se realiza al confirmar una cotización',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Por seguridad, Refanet no guarda tarjetas en la aplicación. Stripe solicita el método de pago cuando existe una orden.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => context.go(AppRoutes.clientRequests),
            style: FilledButton.styleFrom(backgroundColor: _green),
            child: const Text('Ver mis solicitudes'),
          ),
        ],
      ),
    ),
  );
}

class ClientHelpPage extends StatelessWidget {
  const ClientHelpPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _page,
    appBar: AppBar(title: const Text('Ayuda y soporte'), centerTitle: true),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _HelpCard(
          title: '¿Cómo solicito una autoparte?',
          text: 'Pulsa el botón +, elige Nueva solicitud y completa las cuatro etapas.',
        ),
        const _HelpCard(
          title: '¿Cómo hablo con un yonke?',
          text:
              'Cuando recibas una cotización, abre su detalle y entra al chat.',
        ),
        const _HelpCard(
          title: '¿Cómo pago?',
          text: 'Acepta una cotización y crea la orden. El pago seguro se abre desde esa orden.',
        ),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.description_outlined, color: _green),
          title: const Text('Términos y condiciones'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openLegal(
            context,
            'Términos y condiciones',
            'assets/legal/terms.txt',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined, color: _green),
          title: const Text('Aviso de privacidad'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openLegal(
            context,
            'Aviso de privacidad',
            'assets/legal/privacy.txt',
          ),
        ),
      ],
    ),
  );

  void _openLegal(BuildContext context, String title, String path) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentPage(title: title, assetPath: path),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: _navy, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: _muted, height: 1.35)),
        ],
      ),
    ),
  );
}

class _LocalNotice extends StatelessWidget {
  const _LocalNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF7E6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.lock_outline, color: _green),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Guardado de forma segura únicamente en este dispositivo.',
            style: TextStyle(color: Color(0xFF31532A), fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 52, color: _muted),
        const SizedBox(height: 12),
        const Text('No pudimos abrir el perfil'),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
