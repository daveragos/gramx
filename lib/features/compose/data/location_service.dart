import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Why the device location could not be read.
enum LocationFailure {
  /// The user or the OS denied permission.
  noPermission,

  /// Location services are off, or the fix failed.
  unavailable,
}

/// One position fix.
typedef DeviceLocation = ({double latitude, double longitude, double accuracy});

/// Reads the device location once. Live location would need background
/// location access, so only the while-in-use permission is used.
class LocationService {
  /// How long to wait for a fix before giving up.
  static const Duration timeout = Duration(seconds: 15);

  /// Medium accuracy, since the best accuracy can take much longer to fix.
  static const LocationAccuracy accuracy = LocationAccuracy.medium;

  const LocationService();

  /// A single position, or the reason there is none. Requests the permission
  /// if needed, so it is only asked for when the user sends a location.
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
