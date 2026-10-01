import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/config/app_links.dart';

void main() {
  group('AppLinks', () {
    final links = {
      'support': AppLinks.support,
      'repository': AppLinks.repository,
    };

    test('every link is absolute and https', () {
      for (final entry in links.entries) {
        final uri = Uri.tryParse(entry.value);
        expect(uri, isNotNull, reason: entry.key);
        expect(uri!.isAbsolute, isTrue, reason: entry.key);
        expect(uri.scheme, 'https', reason: entry.key);
        expect(uri.host, isNotEmpty, reason: entry.key);
      }
    });

    // The privacy policy says these links are the same for everybody.
    test('no link carries a query or a fragment', () {
      for (final entry in links.entries) {
        final uri = Uri.parse(entry.value);
        expect(uri.hasQuery, isFalse, reason: entry.key);
        expect(uri.hasFragment, isFalse, reason: entry.key);
      }
    });

    test('the source link points at this project', () {
      final uri = Uri.parse(AppLinks.repository);
      expect(uri.host, 'github.com');
      expect(uri.path, '/daveragos/gramx');
    });
  });
}
