import '../../../app/widgets/responsive_scaffold.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/widgets/refanet_image.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/push/push_service.dart';
import '../../yonke_requests/domain/yonke_request_summary.dart';

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
  List<YonkeRequestSummary> _requests = const [];

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
    try {
      final repo = ref.read(yonkeRequestsRepositoryProvider);
      final result = await repo.getAssignedRequests(page: 1, pageSize: 30);
      _requests = result.items;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _identityPending = false;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => ResponsiveScaffold(
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
          final allNotices = <PushNotice>[...notices];
          final existingIds = allNotices.map((n) => n.targetId).toSet();
          for (final req in _requests) {
            if (!existingIds.contains(req.requestYonkeId)) {
              allNotices.add(
                PushNotice(
                  title: 'Nueva solicitud: ${req.part}',
                  body: req.vehicle,
                  receivedAt: req.receivedAt,
                  type: 'NuevaSolicitud',
                  targetId: req.requestYonkeId,
                  imageUrl: req.imageUrl,
                  description: req.description,
                ),
              );
            }
          }
          if (allNotices.isNotEmpty) return _NoticeList(notices: allNotices);
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
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    itemCount: notices.length,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      final notice = notices[index];
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (notice.isNewMessage) {
              context.go(AppRoutes.yonkeMessages);
            } else if (notice.targetId != null &&
                notice.targetId!.isNotEmpty) {
              context.push(
                AppRoutes.yonkeRequestDetail(notice.targetId!),
              );
            } else {
              context.go(AppRoutes.yonkeRequests);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: notice.isNewMessage
                      ? const Icon(
                          Icons.chat_bubble_outline,
                          color: Color(0xFF092B61),
                          size: 28,
                        )
                      : RefanetImage(
                          source: notice.imageUrl,
                          fit: BoxFit.cover,
                          fallback: const Icon(
                            Icons.settings_input_component_outlined,
                            color: Color(0xFF092B61),
                            size: 28,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: notice.isNewMessage
                                  ? const Color(0xFFE3F2FD)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              notice.isNewMessage
                                  ? 'MENSAJE'
                                  : 'NUEVA SOLICITUD',
                              style: TextStyle(
                                color: notice.isNewMessage
                                    ? const Color(0xFF1565C0)
                                    : const Color(0xFF2E7D32),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDate(notice.receivedAt),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notice.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      if (notice.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          notice.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (notice.description != null &&
                          notice.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          notice.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Icon(
                    Icons.chevron_right,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes <= 0 ? 1 : diff.inMinutes}m';
    }
    if (diff.inHours < 24) {
      return 'Hace ${diff.inHours}h';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
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
    child: SingleChildScrollView(
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
    ),
  );
}
