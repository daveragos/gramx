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

    // "Use device setting" hands the choice to MaterialApp, which already
    // watches the platform's brightness and swaps between the two themes on
    // its own. A chosen look is passed as both, so the platform has nothing
    // to switch between.
    final followsDevice = themeMode.followsDevice;
    final chosen = AppTheme.getTheme(themeMode);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: followsDevice ? AppTheme.light() : chosen,
      darkTheme: followsDevice ? AppTheme.dark() : chosen,
      themeMode: followsDevice ? ThemeMode.system : ThemeMode.light,
      routerConfig: router,
      // Above every route, so the launch screen's mark stays put while the
      // router decides, and the app opens through it. See LaunchReveal.
      builder: (context, child) => LaunchReveal(child: child!),
      // gramX writes every string of its own in `core/l10n/app_strings.dart`
      // and ships English only. These delegates are for the strings it does
      // *not* write — the text selection menu, the date picker, the semantics
      // announcements — which without them are English on every device with no
      // locale for the app to react to at all. Declaring one supported locale
      // is also what makes the choice explicit rather than accidental: adding
      // a second means adding it here and swapping AppStrings' bodies for
      // lookups, and no call site changes.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }
}
