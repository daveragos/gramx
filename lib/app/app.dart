import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/router.dart';
import 'package:gramx/app/theme/app_theme.dart';

/// Root application widget.
class GramXApp extends ConsumerWidget {
  const GramXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'gramX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(themeMode),
      routerConfig: router,
    );
  }
}
