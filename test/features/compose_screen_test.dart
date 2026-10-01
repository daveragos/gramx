import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/app/widgets/pill_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/compose/domain/compose_draft.dart';
import 'package:gramx/features/compose/domain/compose_target.dart';
import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/compose/presentation/compose_screen.dart';
import 'package:gramx/infrastructure/database/database.dart';

class _FixedTargets extends ComposeTargetsNotifier {
  _FixedTargets(this._targets);

  final List<ComposeTarget> _targets;

  @override
  List<ComposeTarget> build() => _targets;
}

const _channel = ComposeTarget(
  chatId: -100100,
  title: 'My Channel',
  kind: ComposeTargetKind.channel,
);

const _saved = ComposeTarget(
  chatId: 42,
  title: 'Dawit B',
  kind: ComposeTargetKind.savedMessages,
);

Widget _host(
  List<ComposeTarget> targets, {
  ComposeLengthLimits limits = ComposeLengthLimits.free,
}) => ProviderScope(
  overrides: [
    composeTargetsProvider.overrideWith(() => _FixedTargets(targets)),
    // The real limits come from TDLib. See composeLengthLimitsProvider.
    composeLengthLimitsProvider.overrideWith((ref) async => limits),
    activeAccountProvider.overrideWith(
      (ref) => Stream.value(
        Account(
          id: 1,
          telegramUserId: '42',
          displayName: 'Dawit B',
          isActive: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ),
    ),
  ],
  child: const MaterialApp(home: ComposeScreen()),
);

/// Whether the Post button would do anything if tapped.
bool _postEnabled(WidgetTester tester) {
  // PillButton draws an ElevatedButton, which holds the enabled state.
  final button = tester.widget<ElevatedButton>(
    find.descendant(
      of: find.byType(PillButton),
      matching: find.byType(ElevatedButton),
    ),
  );
  return button.onPressed != null;
}

void main() {
  group('the composer', () {
    testWidgets('starts on the first destination without being asked', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const [_channel]));
      await tester.pump();

      expect(find.text('My Channel'), findsWidgets);
      expect(
        find.text(AppStrings.composePostingTo('My Channel')),
        findsOneWidget,
      );
    });

    // TDLib titles Saved Messages with the account holder's own name, so the
    // pill would otherwise read as posting to a person.
    testWidgets('names Saved Messages for what it is, not who you are', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const [_saved]));
      await tester.pump();

      expect(find.text(AppStrings.composeSavedMessages), findsWidgets);
      expect(find.text('Dawit B'), findsNothing);
    });

    testWidgets('will not post an empty draft', (tester) async {
      await tester.pumpWidget(_host(const [_channel]));
      await tester.pump();

      expect(_postEnabled(tester), isFalse);
    });

    testWidgets('lights up once something is written', (tester) async {
      await tester.pumpWidget(_host(const [_channel]));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hello channel');
      await tester.pump();

      expect(_postEnabled(tester), isTrue);
    });

    testWidgets('whitespace is not something written', (tester) async {
      await tester.pumpWidget(_host(const [_channel]));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '   \n ');
      await tester.pump();

      expect(_postEnabled(tester), isFalse);
    });

    // A control that renders but does nothing is a bug.
    testWidgets('with nowhere to post, it says so and offers nothing', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const []));
      await tester.pump();

      expect(find.text(AppStrings.composeTargetsEmpty), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(_postEnabled(tester), isFalse);
    });

    testWidgets('closing an untouched draft asks nothing', (tester) async {
      await tester.pumpWidget(_host(const [_channel]));
      await tester.pump();

      await tester.tap(find.byTooltip(AppStrings.composeClose));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.composeDiscardTitle), findsNothing);
    });

    // Discarding is irreversible, so it asks first.
    testWidgets('closing a written draft asks before throwing it away', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const [_channel]));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'half a thought');
      await tester.pump();

      await tester.tap(find.byTooltip(AppStrings.composeClose));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.composeDiscardTitle), findsOneWidget);

      await tester.tap(find.text(AppStrings.composeDiscardCancel));
      await tester.pumpAndSettle();

      expect(find.text('half a thought'), findsOneWidget);
    });

    // Checked as geometry: close top-left, Post top-right, avatar in the
    // gutter, and the destination pill above the text field.
    testWidgets('puts the destination above the writing', (tester) async {
      await tester.pumpWidget(_host(const [_channel]));
      await tester.pump();

      final close = tester.getCenter(find.byTooltip(AppStrings.composeClose));
      final post = tester.getCenter(find.byType(PillButton));
      expect(close.dx, lessThan(post.dx));
      expect(
        (close.dy - post.dy).abs(),
        lessThan(24),
        reason: 'they share the top bar',
      );

      final avatar = tester.getTopRight(find.byType(CircleAvatar).first);
      final pill = tester.getTopLeft(
        find.byIcon(Icons.keyboard_arrow_down_rounded),
      );
      final field = tester.getTopLeft(find.byType(TextField));

      expect(
        pill.dx,
        greaterThan(avatar.dx),
        reason: 'the pill sits in the column beside the avatar',
      );
      expect(
        field.dy,
        greaterThan(pill.dy),
        reason: 'the writing starts under the destination',
      );

      final footer = tester.getTopLeft(
        find.text(AppStrings.composePostingTo('My Channel')),
      );
      expect(
        footer.dy,
        greaterThan(field.dy),
        reason: 'where it posts is restated at the bottom, above the tools',
      );
    });

    // Premium accounts get a larger caption limit.
    testWidgets('a Premium account gets the room it pays for', (tester) async {
      await tester.pumpWidget(
        _host(const [_channel], limits: ComposeLengthLimits.premium),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x' * 6000);
      await tester.pump();

      expect(_postEnabled(tester), isTrue);
    });

    testWidgets('and a free one is told where its own line is', (tester) async {
      await tester.pumpWidget(_host(const [_channel]));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x' * 6000);
      await tester.pump();

      expect(_postEnabled(tester), isFalse);
    });
  });
}
