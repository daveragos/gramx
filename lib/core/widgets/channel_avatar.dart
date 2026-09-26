import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/widgets/media_path.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

class ChannelAvatar extends ConsumerWidget {
  final String title;
  final String? avatarPath;
  final int? avatarFileId;
  final String? avatarColorHex;
  final double radius;
  final VoidCallback? onTap;

  const ChannelAvatar({
    super.key,
    required this.title,
    this.avatarPath,
    this.avatarFileId,
    this.avatarColorHex,
    this.radius = AppSpacing.avatarSize / 2,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget avatar;

    // Resolves a TDLib file id or a guest-mode https URL to the same thing:
    // a path on disk. See resolveMediaPath.
    final resolvedPath = resolveMediaPath(
      ref,
      fileId: avatarFileId,
      rawPath: avatarPath,
    );

    if (resolvedPath != null && resolvedPath.isNotEmpty) {
      // Use async file existence check instead of blocking existsSync()
      final fileExists = ref.watch(fileExistsProvider(resolvedPath));
      avatar = fileExists.when(
        data: (exists) {
          if (exists) {
            return CircleAvatar(
              radius: radius,
              backgroundImage: FileImage(File(resolvedPath)),
            );
          }
          return _buildFallbackAvatar();
        },
        loading: () => _buildFallbackAvatar(),
        error: (_, _) => _buildFallbackAvatar(),
      );
    } else {
      avatar = _buildFallbackAvatar();
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }

    return avatar;
  }

  static final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// What a photo-less avatar draws: the first letter of [title].
  ///
  /// By grapheme rather than by `title[0]`, which is one UTF-16 code unit —
  /// half of any emoji — so a name like "🇮🇱 Ada" drew a replacement "?". The
  /// first *letter* is skipped to where there is one, since a flag or a star
  /// in front of a name is decoration; a name that is nothing but emoji draws
  /// its first one.
  @visibleForTesting
  static String initialOf(String title) {
    final graphemes = title.trim().characters;
    for (final grapheme in graphemes) {
      if (_letterOrDigit.hasMatch(grapheme)) return grapheme.toUpperCase();
    }
    return graphemes.isEmpty ? '?' : graphemes.first;
  }

  Widget _buildFallbackAvatar() {
    final bgColor = avatarColorHex != null
        ? _parseColor(avatarColorHex!)
        : AppColors.accent;
    final initial = initialOf(title);

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        initial,
        style: AppTypography.displayName(color: Colors.white),
      ),
    );
  }

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}
