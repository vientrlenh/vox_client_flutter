
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/storage/preference_storage.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';
import 'router.dart';

class App extends StatefulWidget {
  const App({super.key});
  static void setLocale(BuildContext context, Locale locale) {
    context.findAncestorStateOfType<_AppState>()?._setLocale(locale);
  }

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    PreferenceStorage().getLanguageCode().then((code) {
      if (code != null && mounted) setState(() => _locale = Locale(code));
    });
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
    PreferenceStorage().saveLanguageCode(locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VOX Client',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppRouter.navigatorKey,
      theme: buildTheme(),
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.login,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

