import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';

Post post({
  String id = '-1_1',
  String? text,
  String channelTitle = 'Channel',
  String? username,
}) =>
    Post(
      id: id,
      chatId: -1,
      channelId: '-1',
      messageId: 1,
      channelTitle: channelTitle,
      channelUsername: username,
      text: text,
      publishedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('matchLoadedPosts', () {
    test('matches post body text', () {
      final posts = [post(text: 'Flutter 4 is out'), post(id: '-1_2', text: 'unrelated')];
      expect(matchLoadedPosts(posts, 'flutter'), hasLength(1));
    });

    test('matches channel title and username', () {
      final posts = [
        post(id: '-1_1', channelTitle: 'Dart News'),
        post(id: '-1_2', username: 'dartlang'),
        post(id: '-1_3', text: 'nothing here'),
      ];

      expect(matchLoadedPosts(posts, 'dart').map((p) => p.id), ['-1_1', '-1_2']);
    });

    test('is case insensitive', () {
      final posts = [post(text: 'Telegram Channels')];
      expect(matchLoadedPosts(posts, 'TELEGRAM'), hasLength(1));
      expect(matchLoadedPosts(posts, 'channels'), hasLength(1));
    });

    test('an empty query returns everything', () {
      final posts = [post(), post(id: '-1_2')];
      expect(matchLoadedPosts(posts, ''), hasLength(2));
      expect(matchLoadedPosts(posts, '   '), hasLength(2));
    });

    test('a post with no text is not matched by body', () {
      final posts = [post(channelTitle: 'Photos')];
      expect(matchLoadedPosts(posts, 'sunset'), isEmpty);
    });

    test('surrounding whitespace in the query is ignored', () {
      final posts = [post(text: 'hello world')];
      expect(matchLoadedPosts(posts, '  world  '), hasLength(1));
    });
  });
}
