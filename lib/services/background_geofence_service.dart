import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../data/database_helper.dart';
import '../data/models.dart';
import 'location_service.dart';

class BackgroundGeofenceService {
  static StreamSubscription<Position>? _positionStreamSubscription;

  static Future<void> initializeService() async {
    final hasPermission = await LocationService.instance.checkAndRequestPermissions();
    if (!hasPermission) return;

    _positionStreamSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20, // Check every 20 meters moved
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      await _handlePositionUpdate(position);
    });
  }

  static Future<void> _handlePositionUpdate(Position position) async {
    try {
      final settings = await DatabaseHelper.instance.getSettings();
      if (settings.badgeMode == 'MANUAL') return;

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

        final radius = settings.enterDistance > 0 ? settings.enterDistance : 300.0;

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
