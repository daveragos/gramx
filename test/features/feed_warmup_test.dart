import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

void main() {
  group('feedWarmupProvider', () {
    late ProviderContainer container;
    late FeedWarmupNotifier warmup;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
      warmup = container.read(feedWarmupProvider.notifier);
    });

    // Before the first fetch an empty feed shows a skeleton, not "no posts".
    test('starts warm, because nothing has been fetched yet', () {
      expect(container.read(feedWarmupProvider), isTrue);
    });

    test('finishing means an empty feed can be believed', () {
      warmup.finish();
      expect(container.read(feedWarmupProvider), isFalse);
    });

    test('starting again reopens the window', () {
      warmup.finish();
      warmup.start();
      expect(container.read(feedWarmupProvider), isTrue);
    });

    test('repeat calls are no-ops rather than rebuilds', () {
      var rebuilds = 0;
      container.listen(feedWarmupProvider, (_, _) => rebuilds++);

      warmup.start();
      expect(rebuilds, 0, reason: 'already warm');

      warmup.finish();
      warmup.finish();
      expect(rebuilds, 1, reason: 'one real change');
    });
  });
}
