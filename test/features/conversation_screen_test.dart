import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/data/conversation_state.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/presentation/conversation_providers.dart';
import 'package:gramx/features/chats/presentation/conversation_screen.dart';
import 'package:gramx/features/chats/presentation/widgets/chat_date_separator.dart';
import 'package:gramx/features/chats/presentation/widgets/message_bubble.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

const int _chatId = -100600;

/// An already loaded conversation. Loading is covered in
/// conversation_state_test.
class _FixedConversation extends ConversationNotifier {
  _FixedConversation(this._state) : super(_chatId);

  final ConversationState _state;

  @override
  Future<ConversationState> build() async => _state;

  @override
  Future<void> markRead(List<int> messageIds) async {}

  /// What the update stream would do: replace the conversation in place.
  void replace(ConversationState next) => state = AsyncData(next);

  final List<(int, String)> edits = [];
  final List<(List<int>, bool)> deletes = [];

  @override
  Future<bool> edit(int messageId, String text) async {
    edits.add((messageId, text));
    return true;
  }

  @override
  Future<bool> delete(List<int> messageIds, {required bool revoke}) async {
    deletes.add((messageIds, revoke));
    return true;
  }
}

/// Answers everything the screen asks TDLib with "nothing to report", and
/// remembers what it was asked.
class _QuietTdlib implements TdlibService {
  final List<td.TdFunction> asked = [];

  @override
  Stream<td.TdObject> get updatesStream => const Stream.empty();

  @override
  Stream<td.UpdateFile> get fileUpdates => const Stream.empty();

  @override
  Future<td.TdObject> sendRequest(
    td.TdFunction function, {
    String? extraId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    asked.add(function);
    return switch (function) {
      td.SearchChatMessages() => const td.FoundChatMessages(
        totalCount: 0,
        messages: [],
        nextFromMessageId: 0,
      ),
      _ => const td.Ok(),
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Messages of uneven height, the way a real group is: most are a line, some
/// are a paragraph.
List<ChatMessage> _messages(int count) => [
  for (var i = 1; i <= count; i++)
    ChatMessage(
      id: '${_chatId}_$i',
      chatId: _chatId,
      messageId: i,
      isOutgoing: i % 3 == 0,
      senderId: i % 3 == 0 ? 1 : 2,
      senderName: i % 3 == 0 ? null : 'Ada',
      text: i % 7 == 0
          ? List.filled(12, 'a longer thought that wraps').join(' ')
          : 'message $i',
      sentAt: DateTime(2026, 9, 24, 10).add(Duration(minutes: i)),
      sendState: MessageSendState.sent,
    ),
];

const MessageActions _everything = (
  canEdit: true,
  canDeleteForSelf: true,
  canDeleteForAll: true,
  canReply: true,
  canForward: true,
  canCopy: true,
  canPin: true,
);

Widget _host(ConversationState state, _QuietTdlib tdlib) => ProviderScope(
  overrides: [
    tdlibServiceProvider.overrideWithValue(tdlib),
    conversationProvider.overrideWith2((_) => _FixedConversation(state)),
    activeAccountProvider.overrideWith((ref) => const Stream.empty()),
    messageActionsProvider.overrideWith((ref, target) async => _everything),
    chatReactionsProvider.overrideWith((ref, target) async => const []),
  ],
  child: const MaterialApp(home: ConversationScreen(chatId: _chatId)),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void _phoneSized(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2316);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('opens with the unread band at the top of the list', (
    tester,
  ) async {
    _phoneSized(tester);
    await tester.pumpWidget(
      _host(
        ConversationState(
          chatId: _chatId,
          isGroup: true,
          messages: _messages(150),
          hasMoreOlder: false,
          firstUnreadMessageId: 50,
        ),
        _QuietTdlib(),
      ),
    );
    await _settle(tester);

    final band = find.byType(ChatUnreadBand);
    expect(band, findsOneWidget, reason: 'the band was scrolled into view');

    final list = tester.getRect(find.byType(ListView));
    expect(tester.getRect(band).top, closeTo(list.top, 24));
  });

  // TDLib refreshes messages after the chat opens, so rows below the band can
  // grow. The list is anchored to its bottom, so the band must not drift up.
  testWidgets('the band stays put when rows below it grow', (tester) async {
    _phoneSized(tester);
    final messages = _messages(150);
    final initial = ConversationState(
      chatId: _chatId,
      isGroup: true,
      messages: messages,
      hasMoreOlder: false,
      firstUnreadMessageId: 50,
    );
    await tester.pumpWidget(_host(initial, _QuietTdlib()));
    await _settle(tester);

    final band = find.byType(ChatUnreadBand);
    final landed = tester.getRect(band).top;

    final notifier =
        ProviderScope.containerOf(
              tester.element(find.byType(ConversationScreen)),
            ).read(conversationProvider(_chatId).notifier)
            as _FixedConversation;
    notifier.replace(
      initial.copyWith(
        messages: [
          for (final message in messages)
            message.messageId > 50
                ? message.copyWith(reactions: const {'👍': 3, '🔥': 1})
                : message,
        ],
      ),
    );
    await _settle(tester);

    expect(band, findsOneWidget);
    expect(tester.getRect(band).top, closeTo(landed, 2));
  });

  _FixedConversation notifierOf(WidgetTester tester) =>
      ProviderScope.containerOf(
            tester.element(find.byType(ConversationScreen)),
          ).read(conversationProvider(_chatId).notifier)
          as _FixedConversation;

  ChatMessage arrival(int id) => ChatMessage(
    id: '${_chatId}_$id',
    chatId: _chatId,
    messageId: id,
    isOutgoing: false,
    senderId: 2,
    senderName: 'Ada',
    text: List.filled(8, 'something new arriving').join(' '),
    sentAt: DateTime(2026, 9, 24, 14),
    sendState: MessageSendState.sent,
  );

  testWidgets('reading back through history, an arrival moves nothing', (
    tester,
  ) async {
    _phoneSized(tester);
    final initial = ConversationState(
      chatId: _chatId,
      isGroup: true,
      messages: _messages(80),
      hasMoreOlder: false,
    );
    await tester.pumpWidget(_host(initial, _QuietTdlib()));
    await _settle(tester);

    // A couple of screens back, reading.
    await tester.drag(find.byType(ListView), const Offset(0, 900));
    await _settle(tester);
    // Whichever message is near the top of the screen now.
    final list = tester.getRect(find.byType(ListView));
    final reading = [for (var id = 1; id <= 80; id++) find.text('message $id')]
        .firstWhere(
          (finder) =>
              finder.evaluate().isNotEmpty &&
              tester.getRect(finder).top > list.top + 40 &&
              tester.getRect(finder).bottom < list.bottom,
        );
    final before = tester.getRect(reading).top;

    notifierOf(
      tester,
    ).replace(initial.copyWith(messages: [...initial.messages, arrival(81)]));
    await _settle(tester);

    expect(tester.getRect(reading).top, closeTo(before, 2));
  });

  testWidgets('at the bottom, an arrival is shown', (tester) async {
    _phoneSized(tester);
    final initial = ConversationState(
      chatId: _chatId,
      isGroup: true,
      messages: _messages(80),
      hasMoreOlder: false,
    );
    await tester.pumpWidget(_host(initial, _QuietTdlib()));
    await _settle(tester);

    notifierOf(
      tester,
    ).replace(initial.copyWith(messages: [...initial.messages, arrival(81)]));
    await _settle(tester);

    final list = tester.getRect(find.byType(ListView));
    final newest = tester.getRect(find.textContaining('something new'));
    expect(newest.bottom, lessThanOrEqualTo(list.bottom));
    expect(newest.top, greaterThan(list.top));
  });

  // The long press on a bubble opens reply, edit, forward and delete, so the
  // text must not be selectable.
  testWidgets("a message's words do not take the long press", (tester) async {
    _phoneSized(tester);
    await tester.pumpWidget(
      _host(
        ConversationState(chatId: _chatId, messages: _messages(3)),
        _QuietTdlib(),
      ),
    );
    await _settle(tester);

    expect(find.byType(MessageBubble), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(MessageBubble),
        matching: find.byType(EditableText),
      ),
      findsNothing,
    );
  });

  // Each action closes the sheet, so it must not use the sheet's context or
  // ref afterwards.
  group('the long-press sheet', () {
    Future<_FixedConversation> openSheetOn(WidgetTester tester) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          ConversationState(chatId: _chatId, messages: _messages(3)),
          _QuietTdlib(),
        ),
      );
      await _settle(tester);
      // Message 3 is outgoing, so it can be edited.
      await tester.longPress(find.text('message 3'));
      await tester.pumpAndSettle();
      return notifierOf(tester);
    }

    testWidgets('an edit is saved', (tester) async {
      final notifier = await openSheetOn(tester);

      await tester.tap(find.text(AppStrings.chatActionEdit));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        'message 3, reworded',
      );
      await tester.tap(find.text(AppStrings.chatSave));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(notifier.edits, [(3, 'message 3, reworded')]);
    });

    testWidgets('a delete is carried out', (tester) async {
      final notifier = await openSheetOn(tester);

      await tester.tap(find.text(AppStrings.chatActionDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.chatActionDeleteForMe));
      await tester.pumpAndSettle();

      expect(notifier.deletes, hasLength(1));
      expect(notifier.deletes.single.$1, [3]);
      expect(notifier.deletes.single.$2, isFalse);
    });
  });

  // The composer saves its draft from dispose(), after the screen has been
  // deactivated, so it can't read `ref` there.
  testWidgets('what was typed is saved as a draft on the way out', (
    tester,
  ) async {
    _phoneSized(tester);
    final tdlib = _QuietTdlib();
    await tester.pumpWidget(
      _host(ConversationState(chatId: _chatId, messages: _messages(3)), tdlib),
    );
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'half a thought');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    final drafts = tdlib.asked.whereType<td.SetChatDraftMessage>();
    expect(drafts, isNotEmpty);
    expect(
      drafts.last.draftMessage?.inputMessageText,
      isA<td.InputMessageText>().having(
        (input) => input.text.text,
        'text',
        'half a thought',
      ),
    );
  });
}
