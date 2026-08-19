import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/settings/data/storage_repository.dart';

void main() {
  group('parseFolderTitle', () {
    // The field has been a plain String and a FormattedText across TDLib
    // versions, and arrives as a decoded map on some paths.
    test('reads a plain string', () {
      expect(parseFolderTitle('News'), 'News');
    });

    test('reads a FormattedText', () {
      final title = td.FormattedText.fromJson({
        '@type': 'formattedText',
        'text': 'Tech',
        'entities': [],
      });
      expect(parseFolderTitle(title), 'Tech');
    });

    test('reads a decoded map', () {
      expect(parseFolderTitle({'text': 'Science'}), 'Science');
    });

    test('falls back for null', () {
      expect(parseFolderTitle(null), 'Folder');
    });

    test('never returns empty for an unexpected shape', () {
      expect(parseFolderTitle(42), isNotEmpty);
    });
  });

  group('StorageUsage.formatBytes', () {
    test('scales through binary units', () {
      expect(StorageUsage.formatBytes(0), '0 B');
      expect(StorageUsage.formatBytes(512), '512 B');
      expect(StorageUsage.formatBytes(1024), '1.0 KB');
      expect(StorageUsage.formatBytes(1024 * 1024), '1.0 MB');
      expect(StorageUsage.formatBytes(1024 * 1024 * 1024), '1.0 GB');
    });

    test('drops the decimal once the number is large', () {
      expect(StorageUsage.formatBytes(150 * 1024 * 1024), '150 MB');
    });

    test('negative or zero reads as empty, not as a negative size', () {
      expect(StorageUsage.formatBytes(-1), '0 B');
      expect(const StorageUsage(fileCount: 0, totalBytes: 0).isEmpty, isTrue);
    });

    test('formattedSize matches formatBytes', () {
      const usage = StorageUsage(fileCount: 3, totalBytes: 2048);
      expect(usage.formattedSize, StorageUsage.formatBytes(2048));
    });
  });
}
