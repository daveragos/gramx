import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';

/// What the user chose to add. Separate from [ComposeMediaKind] because
/// some choices, like a poll, pick nothing off the device.
enum ComposeAttachChoice {
  photo,
  video,

  /// Any other file, through the platform's own document picker.
  document,

  /// Record a round video message with the camera.
  videoNote,

  /// Write a poll.
  poll,

  /// Send this device's location.
  location,

  /// Send one of the account's Telegram contacts.
  contact;

  /// The media kind this choice picks off the device, or null.
  ComposeMediaKind? get mediaKind => switch (this) {
    ComposeAttachChoice.photo => ComposeMediaKind.photo,
    ComposeAttachChoice.video => ComposeMediaKind.video,
    ComposeAttachChoice.document => ComposeMediaKind.document,
    ComposeAttachChoice.videoNote => ComposeMediaKind.videoNote,
    _ => null,
  };
}

/// The attach sheet shared by the post, message and comment composers.
abstract class ComposeMediaKindSheet {
  /// Each `include` flag says whether Telegram accepts that kind in this chat.
  /// Permissions are per kind (a group can allow photos but not polls), so a
  /// row is left out rather than refused on send.
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
      // Above the shell's bottom bar; see mute_sheet.dart.
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
