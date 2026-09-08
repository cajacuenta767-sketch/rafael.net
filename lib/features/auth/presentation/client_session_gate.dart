import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/api_providers.dart';

const _developmentClientToken = 'development-client-session';

class ClientSessionGate extends ConsumerStatefulWidget {
  const ClientSessionGate({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  ConsumerState<ClientSessionGate> createState() => _ClientSessionGateState();
}

class _ClientSessionGateState extends ConsumerState<ClientSessionGate> {
  late final Future<bool> _session;
  bool _redirectScheduled = false;

  @override
  void initState() {
    super.initState();
    _session = _hasSession();
  }

  Future<bool> _hasSession() async {
    final tokenStore = ref.read(tokenStoreProvider);
    final token = await tokenStore.readAccessToken();
    // Evita que una sesión local guardada durante desarrollo sobreviva en una
    // versión publicada de la aplicación.
    if (!kDebugMode && token == _developmentClientToken) {
      await tokenStore.clear();
      return false;
    }
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
            if (mounted) context.go('/cliente/login');
          });
        }
        return const Scaffold(body: SizedBox.shrink());
      }

      return widget.builder(context);
    },
  );
}
