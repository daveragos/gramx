import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/app/app_shell.dart';

void main() {
  group('ShellTab', () {
    // StatefulNavigationShell addresses branches by index, so the order matters.
    test('order and paths are pinned', () {
      expect(ShellTab.values.map((t) => t.path), [
        '/home',
        '/search',
        '/channels',
        '/activity',
        '/messages',
      ]);
    });

    test('indices match declaration order', () {
      expect(ShellTab.home.index, 0);
      expect(ShellTab.search.index, 1);
      expect(ShellTab.channels.index, 2);
      expect(ShellTab.activity.index, 3);
      expect(ShellTab.messages.index, 4);
    });

    test('every tab has a label and a distinct selected icon', () {
      for (final tab in ShellTab.values) {
        expect(tab.label, isNotEmpty);
        expect(
          tab.icon,
          isNot(tab.activeIcon),
          reason: '${tab.name} needs a distinct selected state',
        );
      }
    });

    test('paths are unique', () {
      final paths = ShellTab.values.map((t) => t.path).toSet();
      expect(paths, hasLength(ShellTab.values.length));
    });
  });
}
