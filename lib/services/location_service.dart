import 'package:geolocator/geolocator.dart';

class LocationResult {
  LocationResult({required this.lat, required this.lng, this.accuracy});

  final double lat;
  final double lng;
  final double? accuracy;
}

class LocationPermissionDenied implements Exception {
  LocationPermissionDenied(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper over geolocator's permission dance — the same two-step Android
/// 10+ flow (foreground first, background only after) is handled by the
/// background tracking service; this class only deals with one-shot foreground
/// location reads (used for mark-in and movement logging).
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  Future<LocationResult> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationPermissionDenied('Please turn on Location Services to mark attendance.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw LocationPermissionDenied('Location permission is required to mark attendance.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionDenied('Location permission was denied. Enable it from device Settings to continue.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    return LocationResult(lat: position.latitude, lng: position.longitude, accuracy: position.accuracy);
  }

  Future<bool> hasBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// Second step of Android's two-stage flow — must be called only after
  /// foreground ("while in use") permission is already granted.
  Future<bool> requestBackgroundPermission() async {
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always;
  }
}
