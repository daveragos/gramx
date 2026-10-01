import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/settings/data/app_settings.dart';
import 'package:gramx/features/feed/presentation/inline_player_budget.dart';

void main() {
  group('AppSettings round-trip', () {
    test('survives encode and decode', () {
      const settings = AppSettings(
        themeMode: AppThemeMode.dim,
        autoPlay: AutoPlayPolicy.never,
      );

      final restored = AppSettings.decode(settings.encode());

      expect(restored.themeMode, AppThemeMode.dim);
      expect(restored.autoPlay, AutoPlayPolicy.never);
      expect(restored, settings);
    });

    test('every theme mode round-trips', () {
      for (final mode in AppThemeMode.values) {
        final restored = AppSettings.decode(
          AppSettings(themeMode: mode).encode(),
        );
        expect(restored.themeMode, mode);
      }
    });
  });

  group('AppSettings decoding is tolerant', () {
    // A bad value falls back to its default rather than blocking startup.
    test('unknown values fall back to defaults', () {
      final restored = AppSettings.decode('{"themeMode":"neon"}');
      expect(restored.themeMode, AppThemeMode.dark);
    });

    test('missing keys fall back to defaults', () {
      final restored = AppSettings.decode('{}');
      expect(restored, const AppSettings());
    });

    test('a non-object payload falls back to defaults', () {
      expect(AppSettings.decode('[1,2,3]'), const AppSettings());
      expect(AppSettings.decode('"hello"'), const AppSettings());
    });

    test('unrecognised extra keys are ignored', () {
      final restored = AppSettings.decode(
        '{"themeMode":"light","somethingNew":42}',
      );
      expect(restored.themeMode, AppThemeMode.light);
    });
  });

  group('AppSettings.copyWith', () {
    test('changes one field and leaves the rest', () {
      const base = AppSettings(
        themeMode: AppThemeMode.light,
        autoPlay: AutoPlayPolicy.never,
      );

      final next = base.copyWith(themeMode: AppThemeMode.dim);

      expect(next.themeMode, AppThemeMode.dim);
      expect(next.autoPlay, AutoPlayPolicy.never);
    });
  });

  group('autoPlayEnabled', () {
    test('reflects the policy', () {
      expect(
        const AppSettings(autoPlay: AutoPlayPolicy.always).autoPlayEnabled,
        isTrue,
      );
      expect(
        const AppSettings(autoPlay: AutoPlayPolicy.never).autoPlayEnabled,
        isFalse,
      );
    });
  });

  group('autoDownloadImages', () {
    test('reflects the policy', () {
      expect(
        const AppSettings(
          autoDownloadImages: AutoDownloadPolicy.always,
        ).autoDownloadImagesEnabled,
        isTrue,
      );
      expect(
        const AppSettings(
          autoDownloadImages: AutoDownloadPolicy.never,
        ).autoDownloadImagesEnabled,
        isFalse,
      );
    });

    test('defaults to on', () {
      expect(const AppSettings().autoDownloadImagesEnabled, isTrue);
    });

    // Turning photos off to save data need not change autoplay.
    test('is independent of autoplay', () {
      const settings = AppSettings(
        autoPlay: AutoPlayPolicy.always,
        autoDownloadImages: AutoDownloadPolicy.never,
      );
      expect(settings.autoPlayEnabled, isTrue);
      expect(settings.autoDownloadImagesEnabled, isFalse);
    });

    // AppSettings is one value object, so every setting is persisted.
    test('survives a save and a reload', () {
      const settings = AppSettings(
        autoDownloadImages: AutoDownloadPolicy.never,
      );
      expect(
        AppSettings.decode(settings.encode()).autoDownloadImages,
        AutoDownloadPolicy.never,
      );
    });

    test('a settings file from before this option still reads', () {
      final restored = AppSettings.decode('{"themeMode":"dim"}');
      expect(restored.themeMode, AppThemeMode.dim);
      expect(restored.autoDownloadImagesEnabled, isTrue);
    });
  });

  group('InlinePlayerBudget', () {
    test('hands out no more than the cap', () {
      final budget = InlinePlayerBudget();

      for (var i = 0; i < InlinePlayerBudget.maxConcurrent; i++) {
        expect(budget.tryAcquire(), isTrue, reason: 'slot ${i + 1}');
      }

      expect(budget.tryAcquire(), isFalse);
      expect(budget.activeCount, InlinePlayerBudget.maxConcurrent);
    });

    test('releasing frees a slot', () {
      final budget = InlinePlayerBudget();
      while (budget.tryAcquire()) {}

      budget.release();

      expect(budget.hasCapacity, isTrue);
      expect(budget.tryAcquire(), isTrue);
    });

    // A tile can release on going off screen and again on dispose.
    test('releasing more often than acquiring cannot go negative', () {
      final budget = InlinePlayerBudget();
      budget.tryAcquire();

      budget.release();
      budget.release();
      budget.release();

      expect(budget.activeCount, 0);
      expect(budget.tryAcquire(), isTrue);
    });

    test('the cap is small enough to matter', () {
      expect(InlinePlayerBudget.maxConcurrent, lessThanOrEqualTo(4));
      expect(InlinePlayerBudget.maxConcurrent, greaterThan(0));
    });
  });
}
