import 'dart:async';
import '../data/database_helper.dart';
import '../data/models.dart';
import 'location_service.dart';

class BackgroundGeofenceService {
  static Timer? _timer;

  static Future<void> initializeService() async {
    final hasPermission = await LocationService.instance.checkAndRequestPermissions();
    if (!hasPermission) return;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _checkLocation();
    });
  }

  static Future<void> _checkLocation() async {
    try {
      final settings = await DatabaseHelper.instance.getSettings();
      if (settings.badgeMode == 'MANUAL') return;

      final position = await LocationService.instance.getCurrentPosition();
      if (position == null) return;

      final locations = await DatabaseHelper.instance.getAllWorkLocations();
      final activeLocations = locations.where((l) => l.isActive).toList();
      if (activeLocations.isEmpty) return;

      final presences = await DatabaseHelper.instance.getAllPresences();
      final isWorking = presences.isNotEmpty && presences.first.type == 'ENTRÉE';
      final currentLocationName = isWorking ? presences.first.locationName : null;

      for (var loc in activeLocations) {
        final distance = LocationService.instance.calculateDistance(
          position.latitude,
          position.longitude,
          loc.latitude,
          loc.longitude,
        );

        final radius = loc.radius > 0 ? loc.radius : (settings.enterDistance > 0 ? settings.enterDistance : 300.0);

        if (distance <= radius) {
          if (!isWorking) {
            await DatabaseHelper.instance.insertPresence(
              PresenceEntity(
                timestamp: DateTime.now().millisecondsSinceEpoch,
                type: 'ENTRÉE',
                locationName: loc.name,
              ),
            );
            break;
          }
        } else {
          if (isWorking && currentLocationName == loc.name) {
            if (distance > radius + 30) {
              await DatabaseHelper.instance.insertPresence(
                PresenceEntity(
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                  type: 'SORTIE',
                  locationName: loc.name,
                ),
              );
              break;
            }
          }
        }
      }
    } catch (e) {
      // Handle error
    }
  }
}
