import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/api_providers.dart';
import '../../../core/session/session_events.dart';

/// Protege las secciones del cliente: sin sesión lleva al login y, si la
/// cuenta es nueva en este dispositivo, al registro del perfil.
class ClientSessionGate extends ConsumerStatefulWidget {
  const ClientSessionGate({
    super.key,
    required this.builder,
    this.requireCompleteProfile = true,
  });

  final WidgetBuilder builder;

  /// `false` solo en la propia pantalla de registro.
  final bool requireCompleteProfile;

  @override
  ConsumerState<ClientSessionGate> createState() => _ClientSessionGateState();
}

class _ClientSessionGateState extends ConsumerState<ClientSessionGate> {
  late final Future<_Access> _session;
  bool _redirectScheduled = false;

  @override
  void initState() {
    super.initState();
    _session = _access();
  }

  Future<_Access> _access() async {
    if (!await hasActiveSession(ref.read(tokenStoreProvider))) {
      return _Access.signedOut;
    }
    if (widget.requireCompleteProfile &&
        await ref.read(clientProfileRepositoryProvider).needsOnboarding()) {
      return _Access.needsProfile;
    }
    return _Access.allowed;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_Access>(
    future: _session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          body: SafeArea(child: Center(child: CircularProgressIndicator())),
        );
      }

      final access = snapshot.data ?? _Access.signedOut;
      if (access != _Access.allowed) {
        if (!_redirectScheduled) {
          _redirectScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.go(
              access == _Access.needsProfile
                  ? '/cliente/registro'
                  : '/cliente/login',
            );
          });
        }
        return const Scaffold(body: SizedBox.shrink());
      }

      return widget.builder(context);
    },
  );
}

enum _Access { allowed, signedOut, needsProfile }
