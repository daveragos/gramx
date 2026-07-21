import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';

class ChannelAvatar extends StatelessWidget {
  final String title;
  final String? avatarPath;
  final String? avatarColorHex;
  final double radius;
  final VoidCallback? onTap;

  const ChannelAvatar({
    super.key,
    required this.title,
    this.avatarPath,
    this.avatarColorHex,
    this.radius = AppSpacing.avatarSize / 2,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    if (avatarPath != null && avatarPath!.isNotEmpty) {
      final file = File(avatarPath!);
      if (file.existsSync()) {
        avatar = CircleAvatar(
          radius: radius,
          backgroundImage: FileImage(file),
        );
      } else {
        avatar = _buildFallbackAvatar();
      }
    } else {
      avatar = _buildFallbackAvatar();
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildFallbackAvatar() {
    final bgColor = avatarColorHex != null
        ? _parseColor(avatarColorHex!)
        : AppColors.accent;
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';

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
