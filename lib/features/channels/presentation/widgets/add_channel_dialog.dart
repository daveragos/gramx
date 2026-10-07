import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/app/widgets/pill_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';

/// Asks for a public channel's username and joins it.
Future<void> showAddChannelDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const AddChannelDialog(),
  );
}

class AddChannelDialog extends ConsumerStatefulWidget {
  const AddChannelDialog({super.key});

  @override
  ConsumerState<AddChannelDialog> createState() => _AddChannelDialogState();
}

class _AddChannelDialogState extends ConsumerState<AddChannelDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final username = _controller.text.trim().replaceFirst('@', '');
    if (username.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    // Captured before the dialog closes, since the toast outlives it.
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(channelRepositoryProvider);
    final membership = ref.read(channelMembershipProvider.notifier);

    void fail(String message) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = message;
      });
    }

    try {
      final channel = await repo.getChannelByIdentifier(username);
      if (channel == null) return fail(AppStrings.channelsAddNotFound);

      if (!await membership.join(channel.chatId)) {
        return fail(AppStrings.channelsAddJoinFailed);
      }

      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.channelsAdded(channel.title))),
      );
    } catch (_) {
      // Telegram's own error text isn't for people; a lookup that fails is
      // most often a name nobody has.
      fail(AppStrings.channelsAddNotFound);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog<void>(
      title: AppStrings.channelsAddPublic,
      body: AppStrings.channelsAddBody,
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_isLoading,
        onSubmitted: (_) => _add(),
        decoration: InputDecoration(
          labelText: AppStrings.channelsAddFieldLabel,
          hintText: AppStrings.channelsAddFieldHint,
          prefixText: '@',
          errorText: _errorMsg,
        ),
      ),
      primary: PillButton(
        label: AppStrings.channelsAddConfirm,
        expand: true,
        isBusy: _isLoading,
        onPressed: _add,
      ),
      actions: const [AppDialogAction.cancel(AppStrings.settingsCancel)],
    );
  }
}
