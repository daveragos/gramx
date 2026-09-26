import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'package:gramx/core/l10n/app_strings.dart';

/// Hands a downloaded file to whichever app on the device owns it.
///
/// One place, because the three call sites that need it — a document row, the
/// image viewer, the video viewer — were each about to grow their own copy of
/// the same error handling, and the interesting part *is* the error handling:
/// "there is no app for this" and "the app refused it" are different sentences
/// and a reader can act on the first.
///
/// On Android this goes out as a `content://` URI through `open_filex`'s own
/// `FileProvider`, which grants read permission to the receiving app for the
/// life of the intent. A plain `file://` path would throw
/// `FileUriExposedException` — TDLib's files live in app-private storage.
///
/// **It also depends on a manifest declaration.** Android 11 hides apps that
/// are not matched by a `<queries>` entry, so without the `VIEW` + `*/*` intent
/// in `AndroidManifest.xml` this reports "no app found" on a device that has
/// three apps for the file.
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
