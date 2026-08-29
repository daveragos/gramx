import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/presentation/widgets/chat_list_tile.dart';
import 'package:gramx/features/chats/presentation/widgets/message_bubble.dart';

ChatSummary row({
  MessageSendState? sendState,
  String? affiliation,
  int? affiliationId,
}) => ChatSummary(
  chatId: 7,
  title: 'Ada',
  kind: ChatKind.direct,
  preview: 'on my way',
  previewSendState: sendState,
  affiliatedChannelId: affiliationId,
  affiliatedChannelTitle: affiliation,
  affiliatedChannelAvatarColorHex: affiliationId == null ? null : '#1D9BF0',
);

void main() {
  Widget host(Widget child) => ProviderScope(
    child: MaterialApp(home: Scaffold(body: child)),
  );

  group('the delivery tick on a row', () {
    testWidgets('is absent for a message from the other side', (tester) async {
      await tester.pumpWidget(host(ChatListTile(chat: row(), onTap: () {})));

      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.byIcon(Icons.done_all_rounded), findsNothing);
    });

    testWidgets('is one tick for sent and two for read', (tester) async {
      await tester.pumpWidget(
        host(
          ChatListTile(
            chat: row(sendState: MessageSendState.sent),
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.pumpWidget(
        host(
          ChatListTile(
            chat: row(sendState: MessageSendState.read),
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    });

    // Shape alone carries the state, which is exactly the case the
    // accessibility rule in docs/CONVENTIONS.md names.
    testWidgets('says what it means out loud', (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        host(
          ChatListTile(
            chat: row(sendState: MessageSendState.read),
            onTap: () {},
          ),
        ),
      );

      // The row is a button, so it merges its subtree into one node — the
      // tick's words are announced as part of the row rather than on their
      // own, which is why this reads the merged label rather than looking for
      // a node of its own.
      expect(
        tester.getSemantics(find.byType(ChatListTile)).label,
        contains(AppStrings.chatStateRead),
      );
      semantics.dispose();
    });
  });

  group('the channel a person runs', () {
    testWidgets('is not drawn when there is none', (tester) async {
      await tester.pumpWidget(host(ChatListTile(chat: row(), onTap: () {})));
      // One avatar on the row: the person's. No second one beside the name.
      expect(find.byType(ChannelAvatar), findsOneWidget);
    });

    // The picture and nothing else. A second name on the line competes with
    // the person's own, and a megaphone says "channel" a third time when the
    // avatar already looks like one.
    testWidgets('is the channel picture, not its name', (tester) async {
      await tester.pumpWidget(
        host(
          ChatListTile(
            chat: row(affiliation: 'Ada Writes', affiliationId: -100),
            onTap: () {},
          ),
        ),
      );

      expect(find.byType(ChannelAvatar), findsNWidgets(2));
      expect(find.text('Ada Writes'), findsNothing);
      expect(find.byIcon(Icons.campaign_rounded), findsNothing);
    });

    // The name is still said out loud — it is a detail nobody needs at a
    // glance, not one nobody needs at all.
    testWidgets('still names the channel to a screen reader', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          ChatListTile(
            chat: row(affiliation: 'Ada Writes', affiliationId: -100),
            onTap: () {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(ChatListTile)).label,
        contains(AppStrings.chatAffiliation('Ada Writes')),
      );
      semantics.dispose();
    });

    testWidgets('opens the channel when tapped', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        host(
          ChatListTile(
            chat: row(affiliation: 'Ada Writes', affiliationId: -100),
            onTap: () {},
            onAffiliatedChannelTap: () => opened++,
          ),
        ),
      );

      await tester.tap(find.byType(ChannelAvatar).last);
      expect(opened, 1);
    });
  });

  // T17-14. Two long presses on one row: the row's own opens the actions
  // sheet, and the face opens a read-only look into the conversation. The
  // innermost detector wins the arena, which is the whole reason this works —
  // and the reason it is worth pinning.
  group('holding the avatar peeks', () {
    testWidgets('fires the peek, not the row actions', (tester) async {
      var peeked = 0;
      var actions = 0;

      await tester.pumpWidget(
        host(
          ChatListTile(
            chat: row(),
            onTap: () {},
            onLongPress: () => actions++,
            onPeek: () => peeked++,
          ),
        ),
      );

      await tester.longPress(find.byType(ChannelAvatar));
      await tester.pumpAndSettle();

      expect(peeked, 1);
      expect(actions, 0);
    });

    testWidgets('while the rest of the row still opens the actions', (
      tester,
    ) async {
      var peeked = 0;
      var actions = 0;

      await tester.pumpWidget(
        host(
          ChatListTile(
            chat: row(),
            onTap: () {},
            onLongPress: () => actions++,
            onPeek: () => peeked++,
          ),
        ),
      );

      // The name, which is in the row's own column rather than on the face.
      await tester.longPress(find.text('Ada'));
      await tester.pumpAndSettle();

      expect(actions, 1);
      expect(peeked, 0);
    });
  });

  // T17-5. Telegram draws a reply as a quote: an accent bar down the left, the
  // author in bold, the words indented behind it — a card inside the bubble.
  group('a reply is named, not quoted', () {
    ChatMessage reply({String? text}) => ChatMessage(
      id: '7_2',
      chatId: 7,
      messageId: 2,
      isOutgoing: false,
      text: 'sure',
      sentAt: DateTime(2026, 8, 30, 12),
      replyToMessageId: 1,
      replyToAuthorName: 'Ada',
      replyToText: text,
    );

    testWidgets('says "Replying to <name>"', (tester) async {
      await tester.pumpWidget(
        host(
          MessageBubble(
            message: reply(text: 'are you coming'),
            isGroup: false,
            isFirstInGroup: true,
            isLastInGroup: true,
          ),
        ),
      );

      expect(find.text(AppStrings.chatReplyingToName('Ada')), findsOneWidget);
      expect(find.text('are you coming'), findsOneWidget);
    });

    // Null when the replied-to message is older than the loaded page. The
    // naming line alone is honest; inventing a preview is not.
    testWidgets('drops the preview rather than inventing one', (tester) async {
      await tester.pumpWidget(
        host(
          MessageBubble(
            message: reply(),
            isGroup: false,
            isFirstInGroup: true,
            isLastInGroup: true,
          ),
        ),
      );

      expect(find.text(AppStrings.chatReplyingToName('Ada')), findsOneWidget);
    });

    testWidgets('the whole line jumps to what was answered', (tester) async {
      var jumped = 0;
      await tester.pumpWidget(
        host(
          MessageBubble(
            message: reply(text: 'are you coming'),
            isGroup: false,
            isFirstInGroup: true,
            isLastInGroup: true,
            onReplyTap: () => jumped++,
          ),
        ),
      );

      await tester.tap(find.text(AppStrings.chatReplyingToName('Ada')));
      expect(jumped, 1);
    });
  });
}
