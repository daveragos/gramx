import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';

Future<void> pumpTile(WidgetTester tester, String title) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: ChannelResultTile(
          channel: Channel(id: '-100', chatId: -100, title: title),
          primaryColor: Colors.black,
          secondaryColor: Colors.grey,
        ),
      ),
    ),
  ),
);

/// Whether every surrogate in [text] is half of a pair. A lone one is what
/// the engine refuses to lay out.
bool isWellFormed(String text) {
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      final next = i + 1 < text.length ? text.codeUnitAt(i + 1) : 0;
      if (next < 0xDC00 || next > 0xDFFF) return false;
      i++;
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return false;
    }
  }
  return true;
}

/// Every string the tile hands to the engine.
List<String> drawnText(WidgetTester tester) => [
  for (final rich in tester.widgetList<RichText>(find.byType(RichText)))
    rich.text.toPlainText(),
];

/// A channel found by searching "ninja" is titled "🥷 Ninja …". Its avatar,
/// with no photo yet, took `title[0]`: half of the emoji.
void main() {
  testWidgets('a title opening with an emoji draws the letter after it', (
    tester,
  ) async {
    await pumpTile(tester, '🥷 Ninja Warriors');

    expect(tester.takeException(), isNull);
    expect(drawnText(tester).every(isWellFormed), isTrue);
    expect(find.text('N'), findsOneWidget);
  });

  testWidgets('a title that is only an emoji draws the whole emoji', (
    tester,
  ) async {
    await pumpTile(tester, '🥷');

    expect(tester.takeException(), isNull);
    expect(drawnText(tester).every(isWellFormed), isTrue);
    expect(find.text('🥷'), findsNWidgets(2));
  });
}
