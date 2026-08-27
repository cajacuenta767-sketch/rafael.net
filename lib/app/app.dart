import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class YonkeApp extends StatelessWidget {
  const YonkeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Refanet Yonke',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
