import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/push/push_service.dart';

/// Avisos push del yonke (nuevas solicitudes y mensajes) recibidos en esta
/// sesión, junto con el estado del registro del dispositivo en el API.
class YonkeNotificationsPage extends ConsumerStatefulWidget {
  const YonkeNotificationsPage({super.key, this.yonkeId});

  /// Identificador del yonke. Si no se indica, se lee el `yonkeGuidId` que
  /// guardó el inicio de sesión.
  final String? yonkeId;

  @override
  ConsumerState<YonkeNotificationsPage> createState() =>
      _YonkeNotificationsPageState();
}

class _YonkeNotificationsPageState
    extends ConsumerState<YonkeNotificationsPage> {
  late final PushService _push;
  bool _loading = true;
  bool _identityPending = false;

  @override
  void initState() {
    super.initState();
    _push = ref.read(pushServiceProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final yonkeId =
        widget.yonkeId ?? await ref.read(tokenStoreProvider).readYonkeGuidId();
    if (!mounted) return;
    if (yonkeId == null || yonkeId.isEmpty) {
      setState(() {
        _identityPending = true;
        _loading = false;
      });
      return;
    }
    await _push.registerCurrentSession();
    if (!mounted) return;
    setState(() {
      _identityPending = false;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFBFD),
    appBar: AppBar(
      backgroundColor: const Color(0xFFFAFBFD),
      surfaceTintColor: const Color(0xFFFAFBFD),
      centerTitle: true,
      title: const Text('Notificaciones'),
      actions: [
        IconButton(
          tooltip: 'Actualizar notificaciones',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(top: false, child: _body()),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_identityPending) {
      return const _StateCard(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Notificaciones pendientes de sesión',
        message:
            'La sesión no incluye el identificador del yonke (yonkeGuidId). '
            'Vuelve a iniciar sesión para registrar este dispositivo.',
      );
    }
    return ValueListenableBuilder<List<PushNotice>>(
      valueListenable: _push.inbox,
      builder: (context, notices, _) => ValueListenableBuilder<PushStatus>(
        valueListenable: _push.status,
        builder: (context, status, _) {
          if (notices.isNotEmpty) return _NoticeList(notices: notices);
          return switch (status) {
            PushStatus.notConfigured => const _StateCard(
              icon: Icons.notifications_paused_outlined,
              title: 'Avisos push no configurados',
              message:
                  'Esta compilación no incluye la configuración de Firebase. '
                  'Las solicitudes y mensajes siguen llegando a sus bandejas.',
            ),
            PushStatus.permissionDenied => const _StateCard(
              icon: Icons.notifications_off_outlined,
              title: 'Permiso de notificaciones desactivado',
              message:
                  'Activa las notificaciones de Refanet en los ajustes del '
                  'teléfono para recibir avisos de nuevas solicitudes.',
            ),
            PushStatus.registrationFailed => _StateCard(
              icon: Icons.cloud_off_outlined,
              title: 'No pudimos registrar este dispositivo',
              message: 'Revisa tu conexión e inténtalo nuevamente.',
              action: OutlinedButton(
                onPressed: _load,
                child: const Text('Reintentar'),
              ),
            ),
            PushStatus.registered || PushStatus.unknown => const _StateCard(
              icon: Icons.notifications_active_outlined,
              title: 'Sin notificaciones nuevas',
              message:
                  'Te avisaremos aquí y en el teléfono cuando llegue una '
                  'solicitud o un mensaje de un cliente.',
            ),
          };
        },
      ),
    );
  }
}

class _NoticeList extends StatelessWidget {
  const _NoticeList({required this.notices});

  final List<PushNotice> notices;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: notices.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      final notice = notices[index];
      return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(
            notice.isNewMessage
                ? Icons.chat_bubble_outline
                : Icons.assignment_outlined,
          ),
          title: Text(
            notice.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: notice.body.isEmpty ? null : Text(notice.body),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(
            notice.isNewMessage
                ? AppRoutes.yonkeMessages
                : AppRoutes.yonkeRequests,
          ),
        ),
      );
    },
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: const Color(0xFF596276)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF596276)),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    ),
  );
}
