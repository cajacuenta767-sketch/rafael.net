import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/presentation/legal_document_page.dart';
import '../../home/presentation/client_bottom_navigation.dart';
import '../data/client_profile_repository.dart';
import '../domain/client_profile.dart';
import 'client_profile_controller.dart';

class ClientProfilePage extends ConsumerStatefulWidget {
  const ClientProfilePage({super.key, this.repository, this.tokenStore});

  final ClientProfileRepository? repository;
  final TokenStore? tokenStore;

  @override
  ConsumerState<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends ConsumerState<ClientProfilePage> {
  late final ClientProfileController _controller;

  @override
  void initState() {
    super.initState();
    final TokenStore tokenStore =
        widget.tokenStore ?? ref.read(tokenStoreProvider);
    _controller = ClientProfileController(
      widget.repository ??
          LocalClientProfileRepository(
            tokenStore: tokenStore,
            demoMode: AppConfig.enableMockAuth,
          ),
      tokenStore,
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
    backgroundColor: const Color(0xFFFCFCFC),
    appBar: AppBar(
      backgroundColor: const Color(0xFFFCFCFC),
      surfaceTintColor: const Color(0xFFFCFCFC),
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: const Text('Mi perfil'),
    ),
    body: SafeArea(top: false, child: _buildBody()),
    bottomNavigationBar: const ClientBottomNavigation(currentIndex: 4),
  );

  Widget _buildBody() {
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.error != null) {
      return _ProfileMessage(
        icon: Icons.cloud_off_outlined,
        title: 'No pudimos abrir el perfil',
        message: 'Revisa tu conexión e inténtalo nuevamente.',
        actionLabel: 'Reintentar',
        onAction: _controller.load,
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
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AccountCard(snapshot: snapshot),
                const SizedBox(height: 24),
                const _SectionTitle('Mi actividad'),
                const SizedBox(height: 10),
                _ProfileTile(
                  key: const Key('profile-requests'),
                  icon: Icons.receipt_long_outlined,
                  title: 'Mis solicitudes',
                  subtitle: 'Consulta su estado y las cotizaciones recibidas',
                  onTap: () => context.push(AppRoutes.clientRequests),
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  key: const Key('profile-quotes'),
                  icon: Icons.request_quote_outlined,
                  title: 'Cotizaciones recibidas',
                  subtitle: 'Selecciona una solicitud para comparar opciones',
                  onTap: () => context.push(AppRoutes.clientRequests),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Legal e información'),
                const SizedBox(height: 10),
                _ProfileTile(
                  key: const Key('profile-terms'),
                  icon: Icons.description_outlined,
                  title: 'Términos y condiciones',
                  onTap: () => _openLegal(
                    'Términos y condiciones',
                    'assets/legal/terms.txt',
                  ),
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  key: const Key('profile-privacy'),
                  icon: Icons.privacy_tip_outlined,
                  title: 'Aviso de privacidad',
                  onTap: () => _openLegal(
                    'Aviso de privacidad',
                    'assets/legal/privacy.txt',
                  ),
                ),
                const SizedBox(height: 10),
                const _ProfileTile(
                  icon: Icons.info_outline,
                  title: 'Versión de la aplicación',
                  trailingText: '1.0.0',
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  key: const Key('client-sign-out'),
                  onPressed: _controller.signingOut ? null : _confirmSignOut,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: const Color(0xFFB3261E),
                    side: const BorderSide(color: Color(0xFFB3261E)),
                  ),
                  icon: _controller.signingOut
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'El cierre actual elimina la sesión de este dispositivo. La revocación en el servidor está pendiente de la API.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF596276), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openLegal(String title, String assetPath) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentPage(title: title, assetPath: assetPath),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que iniciar sesión nuevamente para consultar tus solicitudes y cotizaciones.',
        ),
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
    if (!mounted) return;
    context.go(AppRoutes.clientLogin);
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.snapshot});

  final ClientProfileSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final demo = snapshot.availability == ClientProfileAvailability.demo;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E4EA)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF7EC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              size: 40,
              color: Color(0xFF14951F),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            demo ? 'Cliente de prueba' : 'Cuenta del cliente',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: demo ? const Color(0xFFFFF4DD) : const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              demo ? 'Modo de prueba' : 'Perfil pendiente de la API',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            demo
                ? 'Este acceso permite revisar la aplicación, pero no representa una cuenta autenticada.'
                : 'La API todavía no publica una operación para consultar o actualizar tus datos personales.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF596276), height: 1.4),
          ),
          const SizedBox(height: 14),
          const Tooltip(
            message: 'La actualización estará disponible cuando el backend publique esta operación.',
            child: FilledButton(onPressed: null, child: Text('Editar perfil')),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700),
  );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
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
      leading: Icon(icon, color: const Color(0xFF00695C)),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailingText != null
          ? Text(
              trailingText!,
              style: const TextStyle(color: Color(0xFF596276)),
            )
          : onTap == null
          ? null
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({
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
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}
