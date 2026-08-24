import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';

Widget harness({required bool centerTitle}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        child: ChromeHeaderRow(
          title: 'gramX',
          centerTitle: centerTitle,
          // A wide leading widget, like the feed's account avatar tap
          // target, is exactly what pushed the title off-center before.
          leading: const SizedBox(width: 120),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('centerTitle false keeps the title left-aligned after leading',
      (tester) async {
    await tester.pumpWidget(harness(centerTitle: false));

    final rowLeft = tester.getTopLeft(find.byType(ChromeHeaderRow)).dx;
    final rowRight = tester.getTopRight(find.byType(ChromeHeaderRow)).dx;
    final rowCenter = (rowLeft + rowRight) / 2;
    final titleCenter = tester.getCenter(find.text('gramX')).dx;

    // The wide leading widget should push an uncentered title well past
    // the row's midpoint, not leave it centered.
    expect(titleCenter, greaterThan(rowCenter));
  });

  testWidgets('centerTitle true centers the wordmark regardless of leading width',
      (tester) async {
    await tester.pumpWidget(harness(centerTitle: true));

    final rowLeft = tester.getTopLeft(find.byType(ChromeHeaderRow)).dx;
    final rowRight = tester.getTopRight(find.byType(ChromeHeaderRow)).dx;
    final rowCenter = (rowLeft + rowRight) / 2;
    final titleCenter = tester.getCenter(find.text('gramX')).dx;

    expect(titleCenter, closeTo(rowCenter, 1.0));
  });
}
