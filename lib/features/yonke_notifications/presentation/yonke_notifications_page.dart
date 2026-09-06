import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/api_providers.dart';
import '../data/yonke_notifications_repository.dart';
import '../domain/yonke_notification.dart';

class YonkeNotificationsPage extends ConsumerStatefulWidget {
  const YonkeNotificationsPage({super.key, this.yonkeId, this.repository});

  /// Identificador del yonke. Si no se indica, se lee el `yonkeGuidId` que
  /// guardó el inicio de sesión.
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
  bool _loading = true;
  bool _identityPending = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? ref.read(yonkeNotificationsRepositoryProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _identityPending = false;
      _error = null;
    });
    try {
      final yonkeId =
          widget.yonkeId ??
          await ref.read(tokenStoreProvider).readYonkeGuidId();
      final snapshot = await _repository.load(yonkeId: yonkeId);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
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
    return switch (_snapshot?.setup) {
      YonkeNotificationSetup.identityPending => const _IdentityPending(),
      YonkeNotificationSetup.firebasePending ||
      null => const _FirebasePending(),
    };
  }
}

class _IdentityPending extends StatelessWidget {
  const _IdentityPending();

  @override
  Widget build(BuildContext context) => const _StateCard(
    icon: Icons.admin_panel_settings_outlined,
    title: 'Notificaciones pendientes de sesión',
    message: 'La sesión no incluye el identificador del yonke (yonkeGuidId). Vuelve a iniciar sesión para registrar este dispositivo.',
  );
}

class _FirebasePending extends StatelessWidget {
  const _FirebasePending();

  @override
  Widget build(BuildContext context) => const _StateCard(
    icon: Icons.notifications_paused_outlined,
    title: 'Firebase pendiente de configurar',
    message: 'La API ya permite registrar el token del dispositivo (POST /api/YonkesDispositivos). Falta conectar Firebase Cloud Messaging y pedir el permiso del sistema para recibir avisos reales.',
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
