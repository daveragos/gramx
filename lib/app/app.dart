import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/launch_reveal.dart';
import 'package:gramx/app/router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/theme/app_theme.dart';
import 'package:gramx/features/settings/data/settings_store.dart';

/// Root application widget.
class GramXApp extends ConsumerWidget {
  const GramXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    // When following the device, MaterialApp switches themes itself. A chosen
    // theme is passed as both so there is nothing to switch.
    final followsDevice = themeMode.followsDevice;
    final chosen = AppTheme.getTheme(themeMode);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: followsDevice ? AppTheme.light() : chosen,
      darkTheme: followsDevice ? AppTheme.dark() : chosen,
      themeMode: followsDevice ? ThemeMode.system : ThemeMode.light,
      routerConfig: router,
      // Above every route so the launch mark stays put while the router
      // decides. See LaunchReveal.
      builder: (context, child) => LaunchReveal(child: child!),
      // For framework strings (selection menu, date picker, semantics). The
      // app's own strings are in AppStrings and ship in English only.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }
}
