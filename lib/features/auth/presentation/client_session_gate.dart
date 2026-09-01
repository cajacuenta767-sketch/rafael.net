import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/api_providers.dart';

class ClientSessionGate extends ConsumerStatefulWidget {
  const ClientSessionGate({
    super.key,
    required this.builder,
    this.allowDemoSession,
  });

  final WidgetBuilder builder;
  final bool? allowDemoSession;

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
    if (widget.allowDemoSession ?? AppConfig.enableMockAuth) return true;
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
            if (mounted) context.go('/cliente/login');
          });
        }
        return const Scaffold(body: SizedBox.shrink());
      }

      return widget.builder(context);
    },
  );
}
