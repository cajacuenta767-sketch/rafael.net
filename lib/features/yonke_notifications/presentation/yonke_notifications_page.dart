import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../data/yonke_notifications_repository.dart';
import '../domain/yonke_notification.dart';

class YonkeNotificationsPage extends ConsumerStatefulWidget {
  const YonkeNotificationsPage({
    super.key,
    required this.isDemoSession,
    this.yonkeId,
    this.repository,
  });

  final bool isDemoSession;
  final String? yonkeId;
  final YonkeNotificationsRepository? repository;

  @override
  ConsumerState<YonkeNotificationsPage> createState() =>
      _YonkeNotificationsPageState();
}

class _YonkeNotificationsPageState
    extends ConsumerState<YonkeNotificationsPage> {
  late final YonkeNotificationsRepository _repository;
  YonkeNotificationSnapshot? _snapshot;
  List<YonkeNotificationItem> _items = const [];
  bool _enabled = false;
  bool _loading = true;
  bool _identityPending = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (widget.isDemoSession
            ? const DemoYonkeNotificationsRepository()
            : ref.read(yonkeNotificationsRepositoryProvider));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _identityPending = false;
      _error = null;
    });
    try {
      final snapshot = await _repository.load(
        isDemoSession: widget.isDemoSession,
        yonkeId: widget.yonkeId,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _enabled = snapshot.notificationsEnabled;
        _items = snapshot.items;
        _loading = false;
      });
    } on YonkeNotificationIdentityPendingException {
      if (mounted) {
        setState(() {
          _identityPending = true;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  void _addDemoNotification() {
    final notification = YonkeNotificationItem(
      id: 'demo-notification-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Nueva solicitud de prueba',
      body: 'Faro Nissan Sentra 2018 · Hermosillo, Sonora',
      receivedAt: DateTime.now(),
    );
    setState(() => _items = [notification, ..._items]);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Aviso de prueba recibido.')));
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
    if (_identityPending) return const _IdentityPending();
    if (_error != null) {
      return _StateCard(
        icon: Icons.cloud_off_outlined,
        title: 'No pudimos abrir las notificaciones',
        message: 'Revisa tu conexión e inténtalo nuevamente.',
        action: OutlinedButton(
          onPressed: _load,
          child: const Text('Reintentar'),
        ),
      );
    }
    final snapshot = _snapshot!;
    if (snapshot.setup == YonkeNotificationSetup.firebasePending) {
      return const _FirebasePending();
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          children: [
            const _DemoBanner(),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              key: const Key('yonke-notifications-toggle'),
              value: _enabled,
              activeThumbColor: const Color(0xFF114EB0),
              title: const Text('Alertas de nuevas solicitudes'),
              subtitle: const Text(
                'Recibe un aviso cuando llegue una solicitud a tu cobertura.',
              ),
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('yonke-demo-notification'),
              onPressed: _enabled ? _addDemoNotification : null,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Generar aviso de prueba'),
            ),
            const SizedBox(height: 24),
            Text(
              'Avisos recientes',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ..._items.map(_notificationTile),
          ],
        ),
      ),
    );
  }

  Widget _notificationTile(YonkeNotificationItem item) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E4EA)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        key: Key('yonke-notification-${item.id}'),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEAF1FF),
          foregroundColor: Color(0xFF114EB0),
          child: Icon(Icons.inbox_outlined),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(item.body),
        trailing: Text(
          _time(item.receivedAt),
          style: const TextStyle(fontSize: 12),
        ),
        onTap: () =>
            context.go(AppRoutes.yonkeHome, extra: widget.isDemoSession),
      ),
    ),
  );
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      'Notificaciones de prueba: no se conectan a Firebase ni se envían a dispositivos reales.',
    ),
  );
}

class _IdentityPending extends StatelessWidget {
  const _IdentityPending();

  @override
  Widget build(BuildContext context) => const _StateCard(
    icon: Icons.admin_panel_settings_outlined,
    title: 'Notificaciones pendientes de sesión',
    message: 'Para registrar este dispositivo, la API debe entregar el identificador del yonke autenticado. No se registrará un token sin ese dato.',
  );
}

class _FirebasePending extends StatelessWidget {
  const _FirebasePending();

  @override
  Widget build(BuildContext context) => const _StateCard(
    icon: Icons.notifications_paused_outlined,
    title: 'Firebase pendiente de configurar',
    message: 'La API ya permite registrar el token del dispositivo. Falta conectar Firebase Cloud Messaging y pedir el permiso del sistema para recibir avisos reales.',
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

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
