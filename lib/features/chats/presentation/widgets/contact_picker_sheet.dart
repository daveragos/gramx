import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/chats/domain/user_profile.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';

/// Picks one of the account's Telegram contacts to share. Uses Telegram's
/// contact list, not the device address book, so no permission is needed.
class ContactPickerSheet extends ConsumerStatefulWidget {
  const ContactPickerSheet({super.key});

  /// Returns the chosen user id, or null if the sheet was dismissed.
  static Future<int?> show(BuildContext context) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      // The shell's tab bar paints over branch navigators, so use the root.
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

  /// Filters the already-loaded list locally, without a request.
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
