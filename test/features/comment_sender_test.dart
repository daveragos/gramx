import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/post_detail/presentation/widgets/comment_sender_button.dart';
import 'package:gramx/infrastructure/telegram/chat_identity.dart';

const _postId = '-100500_7';
const _discussion = -100600;
const _channel = -100700;

/// Records the sender chosen for comments.
class _Repository implements FeedRepository {
  final chosen = <(int, td.MessageSender)>[];

  @override
  Future<bool> setCommentSender(
    int discussionChatId,
    td.MessageSender sender,
  ) async {
    chosen.add((discussionChatId, sender));
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Widget _app(_Repository repository, {CommentSenders? senders}) => ProviderScope(
  overrides: [
    feedRepositoryProvider.overrideWithValue(repository),
    commentSendersProvider(_postId).overrideWith((ref) async => senders),
    chatIdentityProvider(_channel).overrideWithValue((
      title: 'Dawit Writes',
      avatarPath: null,
      avatarFileId: null,
      username: 'dawitwrites',
      isVerified: false,
    )),
    activeAccountProvider.overrideWith((ref) => Stream.value(null)),
  ],
  child: const MaterialApp(
    home: Scaffold(
      body: Center(child: CommentSenderButton(postId: _postId)),
    ),
  ),
);

const _choices = CommentSenders(
  chatId: _discussion,
  senders: [
    td.ChatMessageSender(
      sender: td.MessageSenderUser(userId: 1),
      needsPremium: false,
    ),
    td.ChatMessageSender(
      sender: td.MessageSenderChat(chatId: _channel),
      needsPremium: false,
    ),
  ],
);

void main() {
  testWidgets('picking a channel comments as it', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(_app(repository, senders: _choices));
    await tester.pump();

    await tester.tap(find.byType(CommentSenderButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.commentAs), findsOneWidget);
    expect(find.text(AppStrings.commentAsAccount), findsOneWidget);
    expect(find.text('@dawitwrites'), findsOneWidget);

    await tester.tap(find.text('Dawit Writes'));
    await tester.pumpAndSettle();

    final (chatId, sender) = repository.chosen.single;
    expect(chatId, _discussion);
    expect((sender as td.MessageSenderChat).chatId, _channel);
  });

  testWidgets('choosing whoever is already chosen changes nothing', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(_app(repository, senders: _choices));
    await tester.pump();

    await tester.tap(find.byType(CommentSenderButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.commentAsAccount));
    await tester.pumpAndSettle();

    expect(repository.chosen, isEmpty);
  });

  testWidgets('with no channels to choose, the picture is not a button', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Repository()));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(CommentSenderButton),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });
}
