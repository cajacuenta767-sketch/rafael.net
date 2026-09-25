import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/api_providers.dart';
import '../../../core/session/session_events.dart';

/// Protege las secciones privadas del yonke: sin token guardado redirige al
/// inicio de sesión.
class YonkeSessionGate extends ConsumerStatefulWidget {
  const YonkeSessionGate({super.key, required this.builder});

  final WidgetBuilder builder;

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

  Future<bool> _hasSession() => hasActiveSession(ref.read(tokenStoreProvider));

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
