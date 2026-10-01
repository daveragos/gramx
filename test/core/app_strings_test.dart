import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/l10n/app_strings.dart';

void main() {
  group('pluralised strings', () {
    test('new-posts pill', () {
      expect(AppStrings.newPostsPill(1), '1 new post');
      expect(AppStrings.newPostsPill(2), '2 new posts');
      expect(AppStrings.newPostsPill(0), '0 new posts');
    });

    test('folder channel count', () {
      expect(AppStrings.folderChannelCount(1), '1 channel');
      expect(AppStrings.folderChannelCount(0), '0 channels');
      expect(AppStrings.folderChannelCount(7), '7 channels');
    });

    test('subscriber count', () {
      expect(AppStrings.subscriberCount(1), '1 subscriber');
      expect(AppStrings.subscriberCount(1200), '1200 subscribers');
    });

    test('reply label collapses to a bare verb at zero', () {
      expect(AppStrings.a11yReplyWithCount(0), 'Reply');
      expect(AppStrings.a11yReplyWithCount(3), 'Reply, 3 comments');
    });
  });

  group('interpolated strings', () {
    test('include their argument', () {
      expect(AppStrings.feedEmptyTitle('Tech'), contains('Tech'));
      expect(AppStrings.feedPrivateChannel('News'), contains('News'));
      expect(AppStrings.settingsStorageFreed('1.4 GB'), contains('1.4 GB'));
      expect(AppStrings.commentFailed('boom'), contains('boom'));
      expect(AppStrings.a11yCurrentReaction('🔥'), contains('🔥'));
      expect(AppStrings.mediaPosition('Photo', 2, 4), 'Photo 2 of 4');
      expect(AppStrings.forwardSent('Saved'), contains('Saved'));
      expect(AppStrings.forwardFailed('Saved'), contains('Saved'));
    });
  });

  group('constants', () {
    test('are non-empty', () {
      expect(AppStrings.appName, isNotEmpty);
      expect(AppStrings.settingsTitle, isNotEmpty);
      expect(AppStrings.bookmarksEmptyBody, isNotEmpty);
      expect(AppStrings.postNotLinkable, isNotEmpty);
      expect(AppStrings.foldersEmptyBody, isNotEmpty);
    });

    test('multi-line concatenations did not lose their spaces', () {
      // Adjacent literals glue words together if a trailing space is dropped.
      for (final s in [
        AppStrings.foldersEmptyBody,
        AppStrings.bookmarksEmptyBody,
        AppStrings.settingsLogOutBody,
        AppStrings.onboardingLoggedInBody,
        AppStrings.onboardingLoggedOutBody,
      ]) {
        expect(
          RegExp(r'[a-z][A-Z]').hasMatch(s),
          isFalse,
          reason: 'looks like a missing space: $s',
        );
      }
    });
  });
}
