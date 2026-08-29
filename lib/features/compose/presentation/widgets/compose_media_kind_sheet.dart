import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';

/// Photo or video — the two things this app can upload.
///
/// Its own widget because three composers now ask the same question: a post, a
/// message, and a comment. It was already written twice before the third one
/// needed it, which is one time too many for a list of two rows.
abstract class ComposeMediaKindSheet {
  static Future<ComposeMediaKind?> show(BuildContext context) {
    return showModalBottomSheet<ComposeMediaKind>(
      context: context,
      // See mute_sheet.dart: the shell's bottom tab bar paints over each
      // branch's own Navigator, so this needs the root Navigator's Overlay.
      useRootNavigator: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text(AppStrings.composeAddPhoto),
              onTap: () => Navigator.pop(context, ComposeMediaKind.photo),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text(AppStrings.composeAddVideo),
              onTap: () => Navigator.pop(context, ComposeMediaKind.video),
            ),
          ],
        ),
      ),
    );
  }
}
