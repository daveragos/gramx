import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/text/composed_text.dart';
import 'package:gramx/core/widgets/formatting_controller.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

Future<FormattingController> _field(WidgetTester tester, String text) async {
  final controller = FormattingController(text: text);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextField(
            controller: controller,
            contextMenuBuilder: controller.contextMenuBuilder,
          ),
        ),
      ),
    ),
  );
  return controller;
}

/// Selects [start, end) and opens the selection menu, as a long press does.
Future<void> _select(
  WidgetTester tester,
  FormattingController controller,
  int start,
  int end,
) async {
  await tester.tap(find.byType(TextField));
  await tester.pump();
  controller.selection = TextSelection(baseOffset: start, extentOffset: end);
  await tester.pump();
  tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
  await tester.pumpAndSettle();
}

/// Taps the menu item [label], opening the menu's overflow first if the
/// phone-width toolbar folded it away.
Future<void> _tapItem(WidgetTester tester, String label) async {
  if (find.text(label).evaluate().isEmpty) {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Format opens the marks, and one applies to the selection', (
    tester,
  ) async {
    final controller = await _field(tester, 'big news today');
    await _select(tester, controller, 4, 8);

    expect(find.text(AppStrings.formatBold), findsNothing);
    await tester.tap(find.text(AppStrings.formatMenu));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.formatBold));
    await tester.pumpAndSettle();

    expect(controller.composed.entities, [
      const TextEntity(offset: 4, length: 4, type: TextEntityType.bold),
    ]);
    // The text keeps its selection, and the menu closes.
    expect(
      controller.selection,
      const TextSelection(baseOffset: 4, extentOffset: 8),
    );
    expect(find.text(AppStrings.formatMenu), findsNothing);
  });

  testWidgets('a link asks for its address', (tester) async {
    final controller = await _field(tester, 'read this');
    await _select(tester, controller, 5, 9);
    await tester.tap(find.text(AppStrings.formatMenu));
    await tester.pumpAndSettle();
    await _tapItem(tester, AppStrings.formatLink);

    await tester.enterText(
      find.descendant(
        of: find.byType(LinkDialog),
        matching: find.byType(TextField),
      ),
      'example.com/story',
    );
    await tester.pump();
    await tester.tap(find.text(AppStrings.formatLinkAdd));
    await tester.pumpAndSettle();

    final link = controller.composed.entities.single;
    expect(link.type, TextEntityType.textUrl);
    expect(link.url, 'https://example.com/story');
    expect(
      controller.text.substring(link.offset, link.offset + link.length),
      'this',
    );
  });

  testWidgets('the marks follow the text as it is typed', (tester) async {
    final controller = await _field(tester, '');
    controller.composed = const ComposedText('news', [
      TextEntity(offset: 0, length: 4, type: TextEntityType.bold),
    ]);
    await tester.pump();

    await tester.showKeyboard(find.byType(TextField));
    // "big " typed at the start, the caret after it.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'big news',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await tester.pump();

    expect(controller.text, 'big news');
    expect(controller.composed.entities.single.offset, 4);
  });

  test('a link needs an address that can open', () {
    expect(LinkDialog.addressOf('example.com'), 'https://example.com');
    expect(LinkDialog.addressOf(' http://a.example/x '), 'http://a.example/x');
    expect(LinkDialog.addressOf('tg://resolve?domain=durov'), isNotNull);
    expect(LinkDialog.addressOf('not a link'), isNull);
    expect(LinkDialog.addressOf('word'), isNull);
  });
}
