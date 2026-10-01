import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// A public channel a guest has added. [etag] and [lastModified] are HTTP
/// validators, so an unchanged channel refreshes with a small 304.
@immutable
class GuestChannel {
  final String username;
  final String title;
  final String? avatarUrl;
  final String? subscribers;
  final bool isVerified;
  final DateTime addedAt;
  final String? etag;
  final String? lastModified;

  const GuestChannel({
    required this.username,
    required this.title,
    this.avatarUrl,
    this.subscribers,
    this.isVerified = false,
    required this.addedAt,
    this.etag,
    this.lastModified,
  });

  GuestChannel copyWith({
    String? title,
    String? avatarUrl,
    String? subscribers,
    bool? isVerified,
    String? etag,
    String? lastModified,
  }) {
    return GuestChannel(
      username: username,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      subscribers: subscribers ?? this.subscribers,
      isVerified: isVerified ?? this.isVerified,
      addedAt: addedAt,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  /// Value equality, so recording an unchanged ETag doesn't publish new state
  /// and trigger another fetch. See `GuestChannelsNotifier.noteFetched`.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuestChannel &&
          other.username == username &&
          other.title == title &&
          other.avatarUrl == avatarUrl &&
          other.subscribers == subscribers &&
          other.isVerified == isVerified &&
          other.addedAt == addedAt &&
          other.etag == etag &&
          other.lastModified == lastModified;

  @override
  int get hashCode => Object.hash(
    username,
    title,
    avatarUrl,
    subscribers,
    isVerified,
    addedAt,
    etag,
    lastModified,
  );

  Map<String, dynamic> toJson() => {
    'username': username,
    'title': title,
    'avatarUrl': avatarUrl,
    'subscribers': subscribers,
    'isVerified': isVerified,
    'addedAt': addedAt.toIso8601String(),
    'etag': etag,
    'lastModified': lastModified,
  };

  /// Tolerates unknown or missing fields. Returns null only when there is no
  /// username, since such a channel can't be fetched.
  static GuestChannel? fromJson(Map<String, dynamic> json) {
    final username = json['username'];
    if (username is! String || username.isEmpty) return null;

    return GuestChannel(
      username: username,
      title: json['title'] as String? ?? username,
      avatarUrl: json['avatarUrl'] as String?,
      subscribers: json['subscribers'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      addedAt:
          DateTime.tryParse(json['addedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      etag: json['etag'] as String?,
      lastModified: json['lastModified'] as String?,
    );
  }
}

/// Persists the guest's channel list as a JSON file in app documents, like
/// settings and hidden channels.
class GuestChannelStore {
  static const String fileName = 'guest_channels.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<List<GuestChannel>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];

      return [
        for (final entry in decoded)
          if (entry is Map<String, dynamic>) ?GuestChannel.fromJson(entry),
      ];
    } catch (e) {
      // A corrupt file must not stop the app from starting.
      debugPrint('[Guest] Could not read the channel list: $e');
      return [];
    }
  }

  Future<void> save(List<GuestChannel> channels) async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode([for (final channel in channels) channel.toJson()]),
      );
    } catch (e) {
      debugPrint('[Guest] Could not save the channel list: $e');
    }
  }

  /// Removes the file entirely, for when guest mode is turned off.
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[Guest] Could not clear the channel list: $e');
    }
  }
}

final guestChannelStoreProvider = Provider<GuestChannelStore>(
  (ref) => GuestChannelStore(),
);
