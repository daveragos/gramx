import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/app/widgets/edit_text_dialog.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/text/composed_text.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

import '../support/td_fixtures.dart';

/// Answers every edit with a message, and records what was asked.
class _EditingTdlib implements TdlibService {
  final _updates = StreamController<td.TdObject>.broadcast();
  final List<td.TdFunction> asked = [];

  @override
  Stream<td.TdObject> get updatesStream => _updates.stream;

  @override
  Future<td.TdObject> sendRequest(
    td.TdFunction function, {
    String? extraId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    asked.add(function);
    return TdFixtures.textMessage(id: 1, chatId: 42);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _bold = TextEntity(offset: 4, length: 4, type: TextEntityType.bold);

void main() {
  group('editing with formatting', () {
    test('sends the formatting it was given and returns it', () async {
      final tdlib = _EditingTdlib();
      final repository = ChatsRepository(tdlib, ChatCache(tdlib));

      final sent = await repository.editText(
        chatId: 42,
        messageId: 1,
        text: 'big news',
        entities: const [_bold],
      );

      // The writer's formatting replaces the message's own, so it isn't read.
      final edit = tdlib.asked.single as td.EditMessageText;
      final text = (edit.inputMessageContent as td.InputMessageText).text;
      expect(text.entities.single.type, isA<td.TextEntityTypeBold>());
      expect(sent, const ComposedText('big news', [_bold]));
    });
  });

  group('EditTextDialog', () {
    Future<Future<ComposedText?>> open(WidgetTester tester) async {
      late Future<ComposedText?> result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = EditTextDialog.show(
                context,
                initialText: 'big news',
                initialEntities: const [
                  _bold,
                  // Found by Telegram, not kept by the writer.
                  TextEntity(
                    offset: 0,
                    length: 3,
                    type: TextEntityType.hashtag,
                  ),
                ],
              ),
              child: const Text('edit'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('opens with the formatting and saves it with the edit', (
      tester,
    ) async {
      final result = await open(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        (field.controller! as dynamic).composed,
        const ComposedText('big news', [_bold]),
      );

      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'big news!',
          selection: TextSelection.collapsed(offset: 9),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(AppStrings.chatSave));
      await tester.pumpAndSettle();

      expect(await result, const ComposedText('big news!', [_bold]));
    });

    testWidgets('saving it unchanged changes nothing', (tester) async {
      final result = await open(tester);
      await tester.tap(find.text(AppStrings.chatSave));
      await tester.pumpAndSettle();

      expect(await result, isNull);
    });
  });
}
