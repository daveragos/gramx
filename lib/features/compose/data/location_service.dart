import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Where the device is, and why it could not say.
enum LocationFailure {
  /// The reader declined, or the OS did.
  noPermission,

  /// Location services are switched off at the device level, or the fix
  /// failed.
  unavailable,
}

/// One position, and what may be sent with it.
typedef DeviceLocation = ({double latitude, double longitude, double accuracy});

/// Asks the device where it is, once.
///
/// **Once** is the whole design. A live location — Telegram's "share for the
/// next hour" — needs a position stream that keeps running while the app is in
/// the background, which is a foreground service on Android, a background mode
/// on iOS, and a different permission on both. gramX asks for a single fix at
/// the moment somebody taps "send my location" and stops, so the permission it
/// declares is the while-in-use one and nothing here can leave a location
/// stream running behind the reader's back.
class LocationService {
  /// How long to wait for a fix before giving up.
  ///
  /// A cold GPS fix indoors can take longer than anyone will hold a phone
  /// still for. Giving up and saying so beats a spinner that never resolves.
  static const Duration timeout = Duration(seconds: 15);

  /// The accuracy asked for.
  ///
  /// Medium, not best: Telegram is being told roughly where somebody is, not
  /// navigating them, and asking for the best fix is what turns a two-second
  /// answer into a thirty-second one.
  static const LocationAccuracy accuracy = LocationAccuracy.medium;

  const LocationService();

  /// A single position, or why there is none.
  ///
  /// The permission is asked for here, at the moment it is needed and after
  /// the reader has chosen to send a location — never at launch, where a
  /// location prompt with no context is the one every reader declines.
  Future<({DeviceLocation? location, LocationFailure? failure})>
  current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (location: null, failure: LocationFailure.unavailable);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (location: null, failure: LocationFailure.noPermission);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );

      return (
        location: (
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        ),
        failure: null,
      );
    } catch (e) {
      debugPrint('[LocationService] fix failed: $e');
      return (location: null, failure: LocationFailure.unavailable);
    }
  }
}
