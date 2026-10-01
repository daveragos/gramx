import 'package:flutter/foundation.dart';

/// A point on the map somebody sent. Covers both `messageLocation` (bare
/// coordinates) and `messageVenue` (coordinates with a name and address).
@immutable
class MessagePlace {
  final double latitude;
  final double longitude;

  /// The venue's name, when it is a venue. Null for a plain location.
  final String? title;

  /// The street address, when Telegram gave one.
  final String? address;

  /// Seconds this live location keeps updating for. Zero for a still one.
  final int livePeriod;

  /// Seconds until a live location stops updating. Zero once it has, and for
  /// anything that was never live.
  final int expiresIn;

  const MessagePlace({
    required this.latitude,
    required this.longitude,
    this.title,
    this.address,
    this.livePeriod = 0,
    this.expiresIn = 0,
  });

  bool get isVenue => title != null && title!.isNotEmpty;

  /// Whether this is a location that was shared to keep updating.
  bool get isLive => livePeriod > 0;

  /// Whether it is still updating. A live location whose period has run out
  /// counts as a still one.
  bool get isLiveNow => isLive && expiresIn > 0;

  /// The `geo:` URI handed to the user's maps app. gramX draws no map, since
  /// that would need a third-party tile provider. A venue's name goes in the
  /// query so it opens labelled.
  String get geoUri {
    final point = '$latitude,$longitude';
    if (!isVenue) return 'geo:$point';
    return 'geo:$point?q=${Uri.encodeComponent(title!)}';
  }

  @override
  bool operator ==(Object other) =>
      other is MessagePlace &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.title == title &&
      other.address == address &&
      other.livePeriod == livePeriod &&
      other.expiresIn == expiresIn;

  @override
  int get hashCode =>
      Object.hash(latitude, longitude, title, address, livePeriod, expiresIn);
}

/// A contact card somebody sent.
@immutable
class MessageContactCard {
  final String firstName;
  final String lastName;

  /// Digits with no leading `+`, as Telegram stores it. Empty when the number
  /// is hidden.
  final String phoneNumber;

  /// The Telegram account behind it, or zero when the contact is not on
  /// Telegram.
  final int userId;

  const MessageContactCard({
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.userId,
  });

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? phoneNumber : name;
  }

  /// [phoneNumber] with the `+` Telegram leaves off.
  String? get formattedPhoneNumber =>
      phoneNumber.isEmpty ? null : '+$phoneNumber';

  /// Whether tapping the card can open a profile.
  bool get hasTelegramAccount => userId != 0;

  @override
  bool operator ==(Object other) =>
      other is MessageContactCard &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.phoneNumber == phoneNumber &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(firstName, lastName, phoneNumber, userId);
}
