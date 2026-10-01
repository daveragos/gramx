import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/app/theme/brand_assets.dart';
import 'package:gramx/app/widgets/mark_player.dart';

/// Somewhere to get a ticker from.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  // Each step lets the real decoder run, then advances the clock one vsync.
  Future<void> play(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 17));
    }
  }

  testWidgets('stops on the frame it was asked to, and says so', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    final vsync = tester.state<_HostState>(find.byType(_Host));

    var shown = 0;
    var stopped = false;
    final player = MarkPlayer(
      asset: BrandAssets.markAnimation,
      vsync: vsync,
      stopAt: 10,
      onFrame: (image) {
        shown++;
        image.dispose();
      },
      onStopped: () => stopped = true,
    );
    await tester.runAsync(player.start);
    await play(tester, () => stopped);

    expect(stopped, isTrue);
    // Late frames are skipped.
    expect(shown, inInclusiveRange(1, 11));
  });

  // The file has 149 frames, so frame 160 is only reached by looping.
  testWidgets('goes round again after the last frame', (tester) async {
    await tester.pumpWidget(const _Host());
    final vsync = tester.state<_HostState>(find.byType(_Host));

    var stopped = false;
    final player = MarkPlayer(
      asset: BrandAssets.markAnimation,
      vsync: vsync,
      stopAt: 160,
      onFrame: (image) => image.dispose(),
      onStopped: () => stopped = true,
    );
    await tester.runAsync(player.start);
    await play(tester, () => stopped);

    expect(stopped, isTrue);
  });

  testWidgets('a file it cannot read still reports that it stopped', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    final vsync = tester.state<_HostState>(find.byType(_Host));

    var stopped = false;
    final player = MarkPlayer(
      asset: 'assets/brand/missing.webp',
      vsync: vsync,
      stopAt: 10,
      onFrame: (image) => image.dispose(),
      onStopped: () => stopped = true,
    );
    await tester.runAsync(player.start);

    expect(stopped, isTrue);
  });
}
