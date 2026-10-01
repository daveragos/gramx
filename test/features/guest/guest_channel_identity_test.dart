import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/guest/data/guest_channel_store.dart';

/// A fetch writes its ETag back onto the channel row, and the feed watches the
/// rows. These tests keep that from becoming a refetch loop: an unchanged row
/// compares equal, and the feed depends only on which channels exist.
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
      expect(
        channel(etag: 'W/"abc"').hashCode,
        channel(etag: 'W/"abc"').hashCode,
      );
    });

    // Value equality, so a freshly built but identical row is not a change.
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

    // copyWith treats null as "keep", so a fetch without a validator keeps the
    // stored one.
    test('copyWith with nothing set changes nothing', () {
      final before = channel(etag: 'W/"abc"');
      expect(before.copyWith(), before);
    });
  });

  group('the feed key', () {
    // What guestChannelKeysProvider produces: a String, because two lists with
    // equal contents are not `==` and Riverpod would see a change.
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
