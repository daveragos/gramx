import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:gramx/features/feed/domain/seen_posts.dart';

/// The reader's [SeenPosts], kept on disk between launches.
///
/// Nothing watches it: the feed reads it when it admits posts, and the read
/// queue when it works out how far Telegram's cursor may move. So it holds its
/// record in a field and has no state to rebuild anyone with.
class SeenPostsNotifier extends Notifier<void> {
  static const String _fileName = 'seen_posts.json';

  /// How long changes gather before they are written. A scroll marks a post
  /// seen every half second or so; one write covers the run.
  static const Duration _saveDelay = Duration(seconds: 1);

  SeenPosts _seen = SeenPosts();
  Timer? _saveTimer;
  final Completer<void> _loaded = Completer<void>();

  @override
  void build() {
    ref.onDispose(() {
      if (_saveTimer?.isActive ?? false) {
        _saveTimer!.cancel();
        _save();
      }
    });
    _load();
  }

  /// Completes once the record has been read from disk. The feed waits on it
  /// before its first stage, or a launch would briefly offer posts it had
  /// already shown.
  Future<void> get ready => _loaded.future;

  Set<String> get postIds => _seen.postIds;

  Set<int> idsIn(int chatId) => _seen.idsIn(chatId);

  bool containsPost(String postId) {
    final parsed = _parse(postId);
    return parsed != null && _seen.contains(parsed.chatId, parsed.messageId);
  }

  /// Remembers that the reader has seen [postId] (`chatId_messageId`).
  void add(String postId) {
    final parsed = _parse(postId);
    if (parsed == null) return;
    if (_seen.add(parsed.chatId, parsed.messageId)) _scheduleSave();
  }

  /// Forgets what Telegram's cursor for [chatId] now covers.
  void settle(int chatId, int cursor) {
    if (_seen.settle(chatId, cursor)) _scheduleSave();
  }

  /// Forgets everything. Chats are account-scoped, so this goes with signing
  /// out.
  Future<void> clear() async {
    _saveTimer?.cancel();
    _seen = SeenPosts();
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[SeenPosts] Could not delete the record: $e');
    }
  }

  static ({int chatId, int messageId})? _parse(String postId) {
    final separator = postId.indexOf('_');
    if (separator <= 0) return null;
    final chatId = int.tryParse(postId.substring(0, separator));
    final messageId = int.tryParse(postId.substring(separator + 1));
    if (chatId == null || messageId == null) return null;
    return (chatId: chatId, messageId: messageId);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _save);
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> _load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final loaded = SeenPosts.fromJson(
          jsonDecode(await file.readAsString()),
        );
        // Anything marked while the file was being read is kept too.
        for (final postId in _seen.postIds) {
          final parsed = _parse(postId)!;
          loaded.add(parsed.chatId, parsed.messageId);
        }
        _seen = loaded;
      }
    } catch (e) {
      debugPrint('[SeenPosts] Could not read the record: $e');
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
    }
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(_seen.toJson()));
    } catch (e) {
      debugPrint('[SeenPosts] Could not save the record: $e');
    }
  }
}

final seenPostsProvider = NotifierProvider<SeenPostsNotifier, void>(
  SeenPostsNotifier.new,
);
