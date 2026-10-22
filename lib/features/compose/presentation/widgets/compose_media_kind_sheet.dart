import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_typography.dart';
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

/// The attach choices shared by the post, message and comment composers.
abstract class ComposeMediaKindSheet {
  /// Each `include` flag says whether Telegram accepts that kind in this chat.
  /// Permissions are per kind (a group can allow photos but not polls), so a
  /// row is left out rather than refused on send.
  ///
  /// With [anchor], the button's place on screen, the choices open in a card
  /// just above it, as X's message bar does; otherwise in a sheet.
  static Future<ComposeAttachChoice?> show(
    BuildContext context, {
    bool includePoll = false,
    bool includeDocument = false,
    bool includeVideoNote = false,
    bool includeLocation = false,
    bool includeContact = false,
    Rect? anchor,
  }) {
    final rows = <_Choice>[
      const _Choice(
        Icons.image_outlined,
        AppStrings.attachPhotos,
        ComposeAttachChoice.photo,
      ),
      const _Choice(
        Icons.videocam_outlined,
        AppStrings.attachVideos,
        ComposeAttachChoice.video,
      ),
      if (includeDocument)
        const _Choice(
          Icons.insert_drive_file_outlined,
          AppStrings.attachFiles,
          ComposeAttachChoice.document,
        ),
      if (includeVideoNote)
        const _Choice(
          Icons.videocam_rounded,
          AppStrings.attachVideoMessage,
          ComposeAttachChoice.videoNote,
        ),
      if (includePoll)
        const _Choice(
          Icons.poll_outlined,
          AppStrings.attachPoll,
          ComposeAttachChoice.poll,
        ),
      if (includeLocation)
        const _Choice(
          Icons.location_on_outlined,
          AppStrings.attachLocation,
          ComposeAttachChoice.location,
        ),
      if (includeContact)
        const _Choice(
          Icons.person_outline_rounded,
          AppStrings.attachContact,
          ComposeAttachChoice.contact,
        ),
    ];

    if (anchor != null) {
      return showGeneralDialog<ComposeAttachChoice>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (context, _, _) =>
            _AttachPopover(anchor: anchor, rows: rows),
        transitionBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
              alignment: Alignment.bottomLeft,
              child: child,
            ),
          );
        },
      );
    }

    return showModalBottomSheet<ComposeAttachChoice>(
      context: context,
      // Above the shell's bottom bar; see mute_sheet.dart.
      useRootNavigator: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in rows)
              ListTile(
                leading: Icon(row.icon),
                title: Text(row.label),
                onTap: () => Navigator.pop(context, row.choice),
              ),
          ],
        ),
      ),
    );
  }
}

class _Choice {
  final IconData icon;
  final String label;
  final ComposeAttachChoice choice;

  const _Choice(this.icon, this.label, this.choice);
}

/// The choices in a rounded card whose lower left sits just above [anchor].
class _AttachPopover extends StatelessWidget {
  final Rect anchor;
  final List<_Choice> rows;

  const _AttachPopover({required this.anchor, required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final card = isDark
        ? AppColors.darkComposerFill
        : AppColors.lightBackground;
    final disc = isDark ? const Color(0xFF2C2E30) : AppColors.lightBorder;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final primary = theme.colorScheme.onSurface;
    final screen = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        Positioned(
          left: anchor.left,
          bottom: screen.height - anchor.top + 8,
          child: Material(
            color: card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7.6),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final row in rows)
                      InkWell(
                        onTap: () => Navigator.pop(context, row.choice),
                        child: SizedBox(
                          height: 56,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 22, 0),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: disc,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    row.icon,
                                    color: primary,
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Text(
                                  row.label,
                                  style: AppTypography.displayName(
                                    color: primary,
                                  ).copyWith(fontSize: 17),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
