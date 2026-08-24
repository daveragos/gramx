import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// A public channel a guest has added, and what we know about it.
///
/// [etag] and [lastModified] are HTTP validators, not display data: sending
/// them back turns an unchanged channel's refresh into a 304 of a couple of
/// hundred bytes instead of thirty kilobytes of HTML. They live beside the
/// channel because they are per-channel and change on every fetch.
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

  /// Tolerant, like `AppSettings.decode`: a field this version does not
  /// recognise, or one that has gone missing, costs that field rather than the
  /// whole list. Returns null only when there is no username to key on, since
  /// a channel without one cannot be fetched.
  static GuestChannel? fromJson(Map<String, dynamic> json) {
    final username = json['username'];
    if (username is! String || username.isEmpty) return null;

    return GuestChannel(
      username: username,
      title: json['title'] as String? ?? username,
      avatarUrl: json['avatarUrl'] as String?,
      subscribers: json['subscribers'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      etag: json['etag'] as String?,
      lastModified: json['lastModified'] as String?,
    );
  }
}

/// Persists the guest's channel list as JSON in app documents.
///
/// A file rather than a Drift table, matching how settings and hidden channels
/// are already stored: it is one small list, always read and written whole, and
/// a table would mean a schema migration for something no query ever joins.
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
      // A corrupt list should cost the list, never the app's ability to start.
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

final guestChannelStoreProvider =
    Provider<GuestChannelStore>((ref) => GuestChannelStore());
