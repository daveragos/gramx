import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';

Widget harness(WidgetTester tester) {
  return ProviderScope(
    child: MaterialApp(
      home: ChromeScaffold(
        header: const ChromeHeaderRow(title: 'Channels'),
        body: (context, topPadding, bottomPadding) => ListView.builder(
          padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
          itemCount: 60,
          itemBuilder: (context, index) =>
              SizedBox(height: 80, child: Text('row $index')),
        ),
      ),
    ),
  );
}

ChromeOffset offsetOf(WidgetTester tester) {
  final element = tester.element(find.byType(ChromeScaffold));
  return ProviderScope.containerOf(element).read(chromeOffsetProvider);
}

void main() {
  testWidgets('a screen with a header renders and reserves space for it',
      (tester) async {
    await tester.pumpWidget(harness(tester));

    expect(find.text('Channels'), findsOneWidget);
    // The first row must not be underneath the header.
    final headerBottom = tester.getBottomLeft(find.text('Channels')).dy;
    expect(tester.getTopLeft(find.text('row 0')).dy,
        greaterThanOrEqualTo(headerBottom));
  });

  testWidgets('the chrome tracks the finger instead of snapping',
      (tester) async {
    await tester.pumpWidget(harness(tester));
    expect(offsetOf(tester).hidden, 0);

    // Mid-drag, with the finger still down: the whole point of the change is
    // that the chrome is partway out here rather than already gone.
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(ListView)));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();

    final partway = offsetOf(tester).hidden;
    expect(partway, greaterThan(0));
    expect(partway, lessThan(1));
    expect(offsetOf(tester).animate, isFalse,
        reason: 'a drag must not be tweened, or the bars lag the thumb');

    // Reversing mid-drag brings it straight back.
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(offsetOf(tester).hidden, lessThan(partway));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('lifting the finger settles it, and scrolling back returns it',
      (tester) async {
    await tester.pumpWidget(harness(tester));

    await tester.fling(find.byType(ListView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();
    expect(offsetOf(tester).hidden, 1.0);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(offsetOf(tester).hidden, 0.0);
  });

  testWidgets('the header is off screen once the chrome is retired',
      (tester) async {
    await tester.pumpWidget(harness(tester));
    final restingTop = tester.getTopLeft(find.text('Channels')).dy;

    await tester.fling(find.byType(ListView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Channels')).dy, lessThan(restingTop));
  });
}
