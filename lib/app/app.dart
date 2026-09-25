import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/session/session_events.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class YonkeApp extends StatefulWidget {
  const YonkeApp({super.key});

  @override
  State<YonkeApp> createState() => _YonkeAppState();
}

class _YonkeAppState extends State<YonkeApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final StreamSubscription<void> _expiredSubscription;

  @override
  void initState() {
    super.initState();
    _expiredSubscription = SessionEvents.expired.listen(
      (_) => _onSessionExpired(),
    );
  }

  @override
  void dispose() {
    _expiredSubscription.cancel();
    super.dispose();
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
