import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/api_providers.dart';
import '../core/push/push_service.dart';
import '../core/session/session_events.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class YonkeApp extends ConsumerStatefulWidget {
  const YonkeApp({super.key});

  @override
  ConsumerState<YonkeApp> createState() => _YonkeAppState();
}

class _YonkeAppState extends ConsumerState<YonkeApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _subscriptions = <StreamSubscription<Object?>>[];
  late final PushService _push;

  @override
  void initState() {
    super.initState();
    final push = _push = ref.read(pushServiceProvider);
    _subscriptions
      ..add(SessionEvents.expired.listen((_) => _onSessionExpired()))
      // El push y el tiempo real siguen a la sesión guardada.
      ..add(SessionEvents.signedIn.listen((_) => push.registerCurrentSession()))
      ..add(SessionEvents.signedOut.listen((_) => _onSignedOut()))
      ..add(push.openedNotices.listen(_openNotice));
    // Un aviso de mensaje nuevo trae la cotización: el yonke la agrega a su
    // bandeja aunque la haya enviado desde otro teléfono.
    push.inbox.addListener(_rememberQuotesFromNotices);
    // Una sesión que sigue abierta desde la ejecución anterior.
    push.registerCurrentSession();
  }

  void _rememberQuotesFromNotices() {
    final notices = _push.inbox.value;
    if (notices.isEmpty) return;
    final latest = notices.first;
    final quoteId = latest.targetId;
    if (latest.isNewMessage && quoteId != null) {
      ref.read(yonkeQuoteRegistryProvider).add(quoteId);
    }
  }

  @override
  void dispose() {
    _push.inbox.removeListener(_rememberQuotesFromNotices);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _onSignedOut() {
    ref.read(pushServiceProvider).unregister();
    ref.read(realtimeServiceProvider).stop();
  }

  /// Abre la pantalla del aviso que el usuario tocó.
  Future<void> _openNotice(PushNotice notice) async {
    final isYonke =
        (await ref.read(tokenStoreProvider).readYonkeGuidId())?.isNotEmpty ==
        true;
    final target = notice.targetId;
    if (isYonke) {
      appRouter.go(
        notice.isNewMessage ? AppRoutes.yonkeMessages : AppRoutes.yonkeRequests,
      );
    } else if (notice.isNewMessage && target != null) {
      appRouter.go(AppRoutes.clientQuoteDetail(target));
    } else {
      appRouter.go(AppRoutes.clientNotifications);
    }
  }

  /// Lleva al login del rol activo. Varias peticiones pueden recibir 401 a la
  /// vez; solo la primera redirige.
  void _onSessionExpired() {
    final location = appRouter.routerDelegate.currentConfiguration.uri.path;
    final login = location.startsWith('/yonke')
        ? AppRoutes.yonkeLogin
        : AppRoutes.clientLogin;
    if (location == login) return;
    appRouter.go(login);
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tu sesión expiró. Inicia sesión nuevamente.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Refanet Yonke',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: _messengerKey,
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        CountryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
    );
  }
}
