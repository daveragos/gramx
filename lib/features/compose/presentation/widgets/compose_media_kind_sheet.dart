import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';

/// What somebody chose to add to what they are writing.
///
/// A poll is not a [ComposeMediaKind] — nothing is picked off the device and
/// nothing is uploaded — so the sheet answers with this instead, and the two
/// media rows carry the kind they mean.
enum ComposeAttachChoice {
  photo,
  video,

  /// Any other file, through the platform's own document picker.
  document,

  /// Record a round video message. Not a pick — it opens a camera.
  videoNote,

  /// Write a poll. Only offered where Telegram will take one.
  poll,

  /// Send where this device is.
  location,

  /// Send one of the account's Telegram contacts.
  contact;

  /// The media kind this choice picks off the device, or null for the choices
  /// that produce a message some other way.
  ComposeMediaKind? get mediaKind => switch (this) {
    ComposeAttachChoice.photo => ComposeMediaKind.photo,
    ComposeAttachChoice.video => ComposeMediaKind.video,
    ComposeAttachChoice.document => ComposeMediaKind.document,
    ComposeAttachChoice.videoNote => ComposeMediaKind.videoNote,
    _ => null,
  };
}

/// What may be added to a post, a message or a comment.
///
/// Its own widget because three composers now ask the same question: a post, a
/// message, and a comment. It was already written twice before the third one
/// needed it, which is one time too many for a list of two rows.
abstract class ComposeMediaKindSheet {
  /// [includePoll] is the caller's answer to "will Telegram take a poll here",
  /// not a preference. A poll cannot be sent into a private chat at all, so the
  /// row is absent there rather than present and refused on send.
  /// Every `include` is the caller's answer to "will Telegram take one of
  /// these here", not a preference — Telegram permissions media by kind, and a
  /// group can allow photos and forbid voice messages. A row that is absent is
  /// one that would have been refused.
  static Future<ComposeAttachChoice?> show(
    BuildContext context, {
    bool includePoll = false,
    bool includeDocument = false,
    bool includeVideoNote = false,
    bool includeLocation = false,
    bool includeContact = false,
  }) {
    return showModalBottomSheet<ComposeAttachChoice>(
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
              onTap: () => Navigator.pop(context, ComposeAttachChoice.photo),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text(AppStrings.composeAddVideo),
              onTap: () => Navigator.pop(context, ComposeAttachChoice.video),
            ),
            if (includeDocument)
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text(AppStrings.composeAddFile),
                onTap: () =>
                    Navigator.pop(context, ComposeAttachChoice.document),
              ),
            if (includeVideoNote)
              ListTile(
                leading: const Icon(Icons.videocam_rounded),
                title: const Text(AppStrings.composeAddVideoNote),
                onTap: () =>
                    Navigator.pop(context, ComposeAttachChoice.videoNote),
              ),
            if (includePoll)
              ListTile(
                leading: const Icon(Icons.poll_outlined),
                title: const Text(AppStrings.pollComposeTitle),
                onTap: () => Navigator.pop(context, ComposeAttachChoice.poll),
              ),
            if (includeLocation)
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text(AppStrings.composeAddLocation),
                onTap: () =>
                    Navigator.pop(context, ComposeAttachChoice.location),
              ),
            if (includeContact)
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text(AppStrings.composeAddContact),
                onTap: () =>
                    Navigator.pop(context, ComposeAttachChoice.contact),
              ),
          ],
        ),
      ),
    );
  }
}
