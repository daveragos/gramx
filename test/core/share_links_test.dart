import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/core/navigation/share_intake.dart';

void main() {
  group('sharedText', () {
    test('reads the text of a share link', () {
      final uri = Uri.parse('gramx://share?text=Hello%20there');
      expect(ShareLinks.sharedText(uri), 'Hello there');
    });

    test('keeps an escaped plus, which a bare one would turn into a space', () {
      final uri = Uri.parse('gramx://share?text=1%2B1%3D2%20%26%20more');
      expect(ShareLinks.sharedText(uri), '1+1=2 & more');
    });

    test('ignores other links and empty shares', () {
      expect(ShareLinks.sharedText(Uri.parse('https://t.me/durov')), isNull);
      expect(ShareLinks.sharedText(Uri.parse('gramx://other?text=a')), isNull);
      expect(
        ShareLinks.sharedText(Uri.parse('gramx://share?text=%20')),
        isNull,
      );
      expect(ShareLinks.sharedText(Uri.parse('gramx://share')), isNull);
    });
  });

  group('telegramLinkIn', () {
    test('finds a lone Telegram link', () {
      expect(
        ShareLinks.telegramLinkIn('https://t.me/durov'),
        Uri.parse('https://t.me/durov'),
      );
      expect(
        ShareLinks.telegramLinkIn(' tg://resolve?domain=durov\n'),
        Uri.parse('tg://resolve?domain=durov'),
      );
    });

    test('adds the scheme a typed link leaves out', () {
      expect(
        ShareLinks.telegramLinkIn('t.me/durov/42'),
        Uri.parse('https://t.me/durov/42'),
      );
    });

    test('leaves text and other links for the composer', () {
      expect(ShareLinks.telegramLinkIn('look https://t.me/durov'), isNull);
      expect(ShareLinks.telegramLinkIn('https://example.com/t.me'), isNull);
      expect(ShareLinks.telegramLinkIn('durov'), isNull);
      expect(ShareLinks.telegramLinkIn(''), isNull);
    });
  });

  group('a share reaching PendingDeepLink', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    void offer(String text) {
      final encoded = Uri.encodeQueryComponent(text).replaceAll('+', '%20');
      container
          .read(pendingDeepLinkProvider.notifier)
          .offer(Uri.parse('gramx://share?text=$encoded'));
    }

    test('opens a shared Telegram link', () {
      offer('https://t.me/durov');

      expect(
        container.read(pendingDeepLinkProvider),
        Uri.parse('https://t.me/durov'),
      );
      expect(container.read(pendingSharedTextProvider), isNull);
    });

    test('sends anything else to the composer', () {
      offer('Worth a read: https://example.com');

      expect(container.read(pendingDeepLinkProvider), isNull);
      expect(
        container.read(pendingSharedTextProvider),
        'Worth a read: https://example.com',
      );
    });

    test('hands the text over once', () {
      offer('hello');

      final notifier = container.read(pendingSharedTextProvider.notifier);
      expect(notifier.take(), 'hello');
      expect(notifier.take(), isNull);
    });
  });
}
