import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'package:gramx/core/l10n/app_strings.dart';

/// Opens a downloaded file in another app on the device, with a snackbar
/// that tells "no app found" apart from other failures.
///
/// `open_filex` shares the file as a `content://` URI through its
/// `FileProvider`, since TDLib's files are in app-private storage. Android 11+
/// also needs the `VIEW` `*/*` `<queries>` entry in `AndroidManifest.xml`, or
/// every file reports no app found.
Future<void> openWithSystemApp(BuildContext context, String? path) async {
  if (path == null || path.isEmpty || !File(path).existsSync()) {
    _say(context, AppStrings.openWithNotReady);
    return;
  }

  final result = await OpenFilex.open(path);
  if (result.type == ResultType.done || !context.mounted) return;

  _say(
    context,
    result.type == ResultType.noAppToOpen
        ? AppStrings.documentNoAppFound
        : AppStrings.documentOpenFailed,
  );
}

void _say(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
