import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/chats/domain/user_profile.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';

/// Picks one of this account's Telegram contacts to share.
///
/// **Telegram's contacts, not the phone's.** Sharing a contact means sending a
/// Telegram contact card, so the useful list is the one Telegram already holds
/// — reading the device address book would mean asking for a permission gramX
/// does not want and would fill the list with people who are not on Telegram
/// and cannot be sent as one.
class ContactPickerSheet extends ConsumerStatefulWidget {
  const ContactPickerSheet({super.key});

  /// Returns the chosen user id, or null if the sheet was dismissed.
  static Future<int?> show(BuildContext context) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      // See mute_sheet.dart: the shell's bottom tab bar paints over each
      // branch's own Navigator, so this needs the root Navigator's Overlay.
      useRootNavigator: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.lg),
        ),
      ),
      builder: (_) => const ContactPickerSheet(),
    );
  }

  @override
  ConsumerState<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends ConsumerState<ContactPickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Filters locally. The whole list arrived in one request and is already
  /// here, so a search that reached Telegram would cost a request to tell the
  /// reader something the device already knows.
  List<UserProfile> _matching(List<UserProfile> contacts) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return contacts;
    return [
      for (final contact in contacts)
        if (contact.displayName.toLowerCase().contains(query) ||
            (contact.username?.toLowerCase().contains(query) ?? false) ||
            (contact.phoneNumber?.contains(query) ?? false))
          contact,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final contacts = ref.watch(contactsProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.contactPickTitle,
                    style: AppTypography.subheading(color: primary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _search,
                    style: AppTypography.body(color: primary),
                    decoration: InputDecoration(
                      hintText: AppStrings.contactPickHint,
                      hintStyle: AppTypography.body(color: secondary),
                      prefixIcon: Icon(Icons.search, color: secondary),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: contacts.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (_, _) => Center(
                  child: Text(
                    AppStrings.contactPickEmpty,
                    style: AppTypography.body(color: secondary),
                  ),
                ),
                data: (all) {
                  final matches = _matching(all);
                  if (matches.isEmpty) {
                    return Center(
                      child: Text(
                        all.isEmpty
                            ? AppStrings.contactPickEmpty
                            : AppStrings.contactPickNoMatch,
                        style: AppTypography.body(color: secondary),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: controller,
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final contact = matches[index];
                      return ListTile(
                        leading: ChannelAvatar(
                          title: contact.displayName,
                          avatarPath: contact.avatarPath,
                          avatarFileId: contact.avatarFileId,
                          avatarColorHex: contact.avatarColorHex,
                          radius: AppSpacing.avatarSizeSmall / 2,
                        ),
                        title: Text(
                          contact.displayName,
                          style: AppTypography.body(color: primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: contact.phoneNumber == null
                            ? null
                            : Text(
                                contact.phoneNumber!,
                                style: AppTypography.timestamp(
                                  color: secondary,
                                ),
                              ),
                        onTap: () => Navigator.pop(context, contact.userId),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
