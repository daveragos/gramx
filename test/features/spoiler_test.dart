import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/presentation/widgets/spoiler_cover.dart';

void main() {
  group('MediaItem.hasSpoiler', () {
    test('defaults to false', () {
      expect(
        const MediaItem(id: 'a', type: MediaType.photo).hasSpoiler,
        isFalse,
      );
    });

    test('survives a JSON round-trip', () {
      const item = MediaItem(id: 'a', type: MediaType.photo, hasSpoiler: true);
      expect(MediaItem.fromJson(item.toJson()).hasSpoiler, isTrue);
    });
  });

  group('SpoilerCover', () {
    Widget host() => MaterialApp(
      home: Scaffold(
        body: SpoilerCover(
          label: 'Photo',
          child: Container(key: const Key('media')),
        ),
      ),
    );

    testWidgets('covers the media until tapped', (tester) async {
      await tester.pumpWidget(host());

      expect(find.text('Tap to reveal'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('reveals on tap', (tester) async {
      await tester.pumpWidget(host());

      await tester.tap(find.text('Tap to reveal'));
      await tester.pumpAndSettle();

      expect(find.text('Tap to reveal'), findsNothing);
      expect(find.byKey(const Key('media')), findsOneWidget);
    });

    // Re-hiding on rebuild would flicker the cover back over media the reader
    // already chose to see.
    testWidgets('stays revealed across a rebuild', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('Tap to reveal'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.text('Tap to reveal'), findsNothing);
    });

    testWidgets('announces itself as hidden to a screen reader', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      final semantics = tester.getSemantics(find.byType(SpoilerCover));
      expect(semantics.label, contains('Hidden by a spoiler'));
      expect(semantics.label, contains('Photo'));
    });
  });
}
