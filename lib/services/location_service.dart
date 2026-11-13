import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService instance = LocationService._init();

  LocationService._init();

  Future<bool> checkAndRequestPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.whileInUse) {
      await Permission.locationAlways.request();
      perm = await Geolocator.checkPermission();
    }

    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    await Permission.notification.request();
    return perm == LocationPermission.always;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
