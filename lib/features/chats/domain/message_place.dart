import 'package:flutter/foundation.dart';

/// A point on the map somebody sent, and what Telegram calls it.
///
/// One type for both of Telegram's two shapes. A `messageLocation` is bare
/// coordinates; a `messageVenue` is the same coordinates with a name and a
/// street address on them — and everything that draws one draws the other with
/// a line more, so two models would be one model and a duplicate.
///
/// Its own small class rather than a field on [ChatMessage] for each part: four
/// nullable columns on every text message, to describe a thing almost no
/// message is, is how a bubble model gets to thirty fields.
@immutable
class MessagePlace {
  final double latitude;
  final double longitude;

  /// The venue's name, when it is a venue. Null for a plain location.
  final String? title;

  /// The street address, when Telegram gave one.
  final String? address;

  /// Seconds this live location keeps updating for. Zero for a still one,
  /// which is every location gramX itself sends.
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

  /// Whether it is *still* updating. A live location whose period has run out
  /// is a still one, and saying "live" over it would be a lie about something
  /// that stopped moving hours ago.
  bool get isLiveNow => isLive && expiresIn > 0;

  /// The `geo:` URI a maps app opens.
  ///
  /// Built rather than fetched: gramX draws no map. A static map image would
  /// mean an HTTP request to a tile provider, which is a third party this app
  /// does not talk to and a key it does not have — so the card says where the
  /// place is and hands the reader to whatever they already use for maps.
  ///
  /// The label is carried as a query so a venue arrives named rather than as a
  /// dropped pin with coordinates under it.
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

  /// The number, as Telegram carries it: digits, no leading `+`. Empty when the
  /// sender shared a contact whose number is hidden.
  final String phoneNumber;

  /// The Telegram account behind it, or zero when the contact is not on
  /// Telegram. Zero is what decides whether the card leads anywhere.
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

  /// Telegram stores numbers without the `+`, and a number shown without one
  /// is ambiguous about its country code.
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
