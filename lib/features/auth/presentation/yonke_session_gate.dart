import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/api_providers.dart';

/// Protege las secciones privadas del yonke sin convertir el modo de prueba
/// en una sesión real. El modo de prueba sólo entra cuando se recibió de forma
/// explícita desde la pantalla de acceso.
class YonkeSessionGate extends ConsumerStatefulWidget {
  const YonkeSessionGate({
    super.key,
    required this.builder,
    required this.isDemoSession,
  });

  final WidgetBuilder builder;
  final bool isDemoSession;

  @override
  ConsumerState<YonkeSessionGate> createState() => _YonkeSessionGateState();
}

class _YonkeSessionGateState extends ConsumerState<YonkeSessionGate> {
  late final Future<bool> _session;
  bool _redirectScheduled = false;

  @override
  void initState() {
    super.initState();
    _session = _hasSession();
  }

  Future<bool> _hasSession() async {
    if (widget.isDemoSession) return true;
    final token = await ref.read(tokenStoreProvider).readAccessToken();
    return token?.isNotEmpty == true;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          body: SafeArea(child: Center(child: CircularProgressIndicator())),
        );
      }
      if (snapshot.data != true) {
        if (!_redirectScheduled) {
          _redirectScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/yonke/login');
          });
        }
        return const Scaffold(body: SizedBox.shrink());
      }
      return widget.builder(context);
    },
  );
}
