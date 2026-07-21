import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

void showAddChannelDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) => AddChannelDialog(ref: ref),
  );
}

class AddChannelDialog extends StatefulWidget {
  final WidgetRef ref;

  const AddChannelDialog({super.key, required this.ref});

  @override
  State<AddChannelDialog> createState() => _AddChannelDialogState();
}

class _AddChannelDialogState extends State<AddChannelDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final syncService = widget.ref.read(syncServiceProvider);
      await syncService.addPublicChannelByUsername(text);
      if (mounted && context.mounted) {
        Navigator.pop(context);
      }

      widget.ref.invalidate(feedPostsProvider);
      widget.ref.invalidate(channelsProvider);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return AlertDialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      title: Text(
        'Add Public Channel',
        style: AppTypography.heading(color: primaryColor),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter a public Telegram channel username (e.g. durov).',
            style: AppTypography.body(color: secondaryColor),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Channel Username',
              hintText: 'durov',
              prefixText: '@',
              errorText: _errorMsg,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
