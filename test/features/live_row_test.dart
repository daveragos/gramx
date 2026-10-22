import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/live/presentation/live_providers.dart';
import 'package:gramx/features/live/presentation/live_row.dart';
import 'package:gramx/features/live/presentation/live_screen.dart';
import 'package:handy_tdlib/api.dart' as td;

import '../support/td_fixtures.dart';

td.Chat _withVideoChat(td.Chat chat, int groupCallId, {bool people = true}) =>
    chat.copyWith(
      videoChat: td.VideoChat(
        groupCallId: groupCallId,
        hasParticipants: people,
      ),
    );

void main() {
  group('selectLiveChats', () {
    final channel = _withVideoChat(
      TdFixtures.chat(id: -1001, title: 'Live channel', mainOrder: 10),
      11,
    );
    final emptyVideoChat = _withVideoChat(
      TdFixtures.chat(id: -1002, title: 'Nobody in it', mainOrder: 9),
      12,
      people: false,
    );
    final notFollowed = _withVideoChat(
      TdFixtures.chat(id: -1003, title: 'Not followed'),
      13,
    );
    final group = _withVideoChat(
      TdFixtures.groupChat(id: -1004, title: 'Group'),
      14,
    );
    final basicGroup = _withVideoChat(
      TdFixtures.basicGroupChat(id: -5, title: 'Basic').copyWith(
        positions: TdFixtures.chat(id: -5, mainOrder: 3).positions,
      ),
      15,
    );
    final quiet = TdFixtures.chat(id: -1006, title: 'Quiet', mainOrder: 8);
    final chats = [channel, emptyVideoChat, notFollowed, group, basicGroup, quiet];

    test('a followed channel with people in its video chat is live', () {
      final lives = selectLiveChats(chats, rtmpGroupCalls: const {});

      expect(lives.map((l) => l.chatId), [-1001]);
      expect(lives.single.groupCallId, 11);
      expect(lives.single.title, 'Live channel');
    });

    test('a group is live only while it streams over RTMP', () {
      final lives = selectLiveChats(
        chats,
        rtmpGroupCalls: const {14: true, 15: false},
      );

      expect(lives.map((l) => l.chatId), [-1001, -1004]);
    });

    test('asks about the group calls of followed groups only', () {
      expect(groupCallsToLookUp(chats, rtmpGroupCalls: const {}), {14, 15});
      expect(groupCallsToLookUp(chats, rtmpGroupCalls: const {14: true}), {
        15,
      });
    });
  });

  group('LiveRow', () {
    const lives = [
      LiveChat(chatId: -1001, groupCallId: 11, title: 'Morning show'),
      LiveChat(chatId: -1002, groupCallId: 12, title: 'Match day'),
    ];

    Widget host(List<LiveChat> lives) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: LiveRow(lives: lives)),
          ),
          GoRoute(
            path: LiveScreen.route,
            builder: (_, state) =>
                Text('watching ${state.pathParameters['chatId']}'),
          ),
        ],
      );
      return ProviderScope(child: MaterialApp.router(routerConfig: router));
    }

    testWidgets('shows each live with its name and badge', (tester) async {
      await tester.pumpWidget(host(lives));

      expect(find.text('Morning show'), findsOneWidget);
      expect(find.text('Match day'), findsOneWidget);
      expect(find.text(AppStrings.liveBadge), findsNWidgets(2));
      expect(
        find.bySemanticsLabel(AppStrings.liveTileLabel('Match day')),
        findsOneWidget,
      );
    });

    testWidgets('opens the live page on a tap', (tester) async {
      await tester.pumpWidget(host(lives));

      await tester.tap(find.text('Match day'));
      await tester.pumpAndSettle();

      expect(find.text('watching -1002'), findsOneWidget);
    });

    testWidgets('draws nothing while nothing is live', (tester) async {
      await tester.pumpWidget(host(const []));

      expect(find.text(AppStrings.liveBadge), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });
  });
}
