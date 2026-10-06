import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';

/// The account avatar at the start of a tab's header, which opens the drawer.
class DrawerAvatarButton extends ConsumerWidget {
  const DrawerAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider).value;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Semantics(
        button: true,
        label: AppStrings.a11yOpenMenu,
        child: ChannelAvatar(
          title: account?.displayName ?? AppStrings.drawerAccountFallback,
          avatarPath: account?.avatarPath,
          radius: AppSpacing.avatarSizeSmall / 2,
          onTap: openAppDrawer,
        ),
      ),
    );
  }
}
