import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(themeMode),
      routerConfig: router,
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
