import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/presentation/legal_document_page.dart';
import '../../yonke_requests/presentation/yonke_bottom_navigation.dart';
import '../data/yonke_profile_repository.dart';
import '../domain/yonke_profile.dart';
import 'yonke_profile_controller.dart';

class YonkeProfilePage extends ConsumerStatefulWidget {
  const YonkeProfilePage({
    super.key,
    required this.isDemoSession,
    this.repository,
    this.tokenStore,
  });

  final bool isDemoSession;
  final YonkeProfileRepository? repository;
  final TokenStore? tokenStore;

  @override
  ConsumerState<YonkeProfilePage> createState() => _YonkeProfilePageState();
}

class _YonkeProfilePageState extends ConsumerState<YonkeProfilePage> {
  late final YonkeProfileController _controller;

  @override
  void initState() {
    super.initState();
    final TokenStore store = widget.tokenStore ?? ref.read(tokenStoreProvider);
    _controller = YonkeProfileController(
      widget.repository ??
          LocalYonkeProfileRepository(
            tokenStore: store,
            isDemoSession: widget.isDemoSession,
          ),
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
      backgroundColor: const Color(0xFFFAFBFD),
      surfaceTintColor: const Color(0xFFFAFBFD),
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: const Text('Perfil del yonke'),
    ),
    body: SafeArea(top: false, child: _body()),
    bottomNavigationBar: YonkeBottomNavigation(
      selected: YonkeNavigationSection.profile,
      isDemoSession: widget.isDemoSession,
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
    final isDemo =
        _controller.snapshot!.availability == YonkeProfileAvailability.demo;
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
                _AccountCard(isDemo: isDemo),
                const SizedBox(height: 24),
                const _SectionTitle('Mi operación'),
                const SizedBox(height: 10),
                _ProfileTile(
                  key: const Key('yonke-profile-requests'),
                  icon: Icons.inbox_outlined,
                  title: 'Solicitudes recibidas',
                  subtitle: 'Revisa las refacciones pendientes de cotizar',
                  onTap: () => context.go(
                    AppRoutes.yonkeHome,
                    extra: widget.isDemoSession,
                  ),
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  key: const Key('yonke-profile-quotes'),
                  icon: Icons.request_quote_outlined,
                  title: 'Cotizaciones enviadas',
                  subtitle: 'Consulta las propuestas que compartiste',
                  onTap: () => context.go(
                    AppRoutes.yonkeQuotes,
                    extra: widget.isDemoSession,
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Negocio y cobertura'),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.storefront_outlined,
                  title: 'Datos del yonke',
                  subtitle: 'Nombre, contacto y dirección',
                  onTap: _showContractPending,
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  key: const Key('yonke-profile-coverage'),
                  icon: Icons.location_on_outlined,
                  title: 'Ciudades de cobertura',
                  subtitle: 'Define dónde deseas recibir solicitudes',
                  onTap: () => context.push(
                    AppRoutes.yonkeCoverage,
                    extra: widget.isDemoSession,
                  ),
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  key: const Key('yonke-profile-notifications'),
                  icon: Icons.notifications_outlined,
                  title: 'Notificaciones',
                  subtitle: 'Alertas cuando llegue una nueva solicitud',
                  onTap: () => context.push(
                    AppRoutes.yonkeNotifications,
                    extra: widget.isDemoSession,
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Legal e información'),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.description_outlined,
                  title: 'Términos y condiciones',
                  onTap: () => _openLegal(
                    'Términos y condiciones',
                    'assets/legal/terms.txt',
                  ),
                ),
                const SizedBox(height: 10),
                _ProfileTile(
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
                  key: const Key('yonke-sign-out'),
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
                  'El cierre elimina la sesión de este dispositivo. La revocación en el servidor está pendiente de la API.',
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

  void _showContractPending() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'La API debe confirmar el id del yonke autenticado antes de permitir esta actualización.',
      ),
    ),
  );

  void _openLegal(String title, String assetPath) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LegalDocumentPage(title: title, assetPath: assetPath),
    ),
  );

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
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.isDemo});
  final bool isDemo;

  @override
  Widget build(BuildContext context) => Container(
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
            color: Color(0xFFEAF1FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.storefront_outlined,
            size: 38,
            color: Color(0xFF114EB0),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          isDemo ? 'Yonke de prueba' : 'Cuenta del yonke',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDemo ? const Color(0xFFFFF4DD) : const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isDemo ? 'Modo de prueba' : 'Perfil pendiente de la API',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          isDemo
              ? 'Este acceso permite revisar el flujo del yonke, pero no representa una cuenta autenticada.'
              : 'La API expone operaciones para actualizar un yonke por id, pero aún no indica cuál es el yonke de esta sesión.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF596276), height: 1.4),
        ),
      ],
    ),
  );
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
      leading: Icon(icon, color: const Color(0xFF114EB0)),
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
