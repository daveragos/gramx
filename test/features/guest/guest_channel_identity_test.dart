import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/guest/data/guest_channel_store.dart';

/// The guest feed spun forever on the home screen, and this is the seam that
/// caused it.
///
/// Fetching a channel's page records its ETag back onto the channel row. The
/// feed watched those rows, so finishing a fetch published new state, which
/// restarted the feed, which fetched again — a loop pointed at Telegram that
/// never settled and never painted a post.
///
/// Two things stop it, and both are checked here: a row that has not really
/// changed compares equal, and the feed's dependency is membership only.
void main() {
  GuestChannel channel({String? etag, String title = 'Ragoose Dumps'}) =>
      GuestChannel(
        username: 'ragoose_dumps',
        title: title,
        addedAt: DateTime.utc(2026, 1, 1),
        etag: etag,
      );

  group('GuestChannel equality', () {
    test('two rows with the same contents are equal', () {
      expect(channel(etag: 'W/"abc"'), channel(etag: 'W/"abc"'));
      expect(channel(etag: 'W/"abc"').hashCode,
          channel(etag: 'W/"abc"').hashCode);
    });

    // Without this the "did anything change?" guard is an identity check, which
    // is always false for a freshly built row — so every fetch counted as a
    // change and the loop ran.
    test('recording the same validator again is not a change', () {
      final before = channel(etag: 'W/"abc"');
      final after = before.copyWith(etag: 'W/"abc"');
      expect(after, before);
    });

    test('a new validator is a change', () {
      final before = channel(etag: 'W/"abc"');
      expect(before.copyWith(etag: 'W/"def"'), isNot(before));
    });

    test('a renamed channel is a change', () {
      expect(channel(title: 'Renamed'), isNot(channel()));
    });

    // copyWith takes null to mean "leave it alone", so a fetch that returns no
    // validator must not silently erase the one already stored.
    test('copyWith with nothing set changes nothing', () {
      final before = channel(etag: 'W/"abc"');
      expect(before.copyWith(), before);
    });
  });

  group('the feed key', () {
    // What guestChannelKeysProvider produces. A String, so Riverpod's
    // value comparison can see that nothing changed — two lists with equal
    // contents are never `==`, and that difference is the whole fix.
    String keyFor(List<GuestChannel> channels) =>
        channels.map((c) => c.username).join(',');

    test('rewriting a row leaves the key untouched', () {
      final before = [channel(etag: 'W/"abc"')];
      final after = [before.first.copyWith(etag: 'W/"def"')];
      expect(keyFor(after), keyFor(before));
    });

    test('adding a channel changes the key', () {
      final before = [channel()];
      final after = [
        ...before,
        GuestChannel(
          username: 'lidsverse',
          title: "Lid's Verse",
          addedAt: DateTime.utc(2026, 1, 2),
        ),
      ];
      expect(keyFor(after), isNot(keyFor(before)));
    });

    test('removing a channel changes the key', () {
      expect(keyFor([channel()]), isNot(keyFor(const [])));
    });
  });
}
