import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../data/database_helper.dart';
import '../data/models.dart';
import 'location_service.dart';

class BackgroundGeofenceService {
  static StreamSubscription<Position>? _positionStreamSubscription;

  static Future<void> initializeService() async {
    final hasPermission = await LocationService.instance.checkAndRequestPermissions();
    if (!hasPermission) {
      debugPrint('GEOFENCE: permission refusée');
      return;
    }

    _positionStreamSubscription?.cancel();

    late LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Badgeuse active',
          notificationText: 'Détection de présence en cours',
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) async {
        debugPrint('GEOFENCE: position ${position.latitude}, ${position.longitude}');
        await _handlePositionUpdate(position);
      },
      onError: (e) => debugPrint('GEOFENCE: erreur flux $e'),
    );

    // Vérification immédiate au démarrage
    final first = await LocationService.instance.getCurrentPosition();
    if (first != null) {
      debugPrint('GEOFENCE: position initiale ${first.latitude}, ${first.longitude}');
      await _handlePositionUpdate(first);
    }
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
            debugPrint('GEOFENCE: ENTREE enregistrée pour ${loc.name}');
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
              debugPrint('GEOFENCE: SORTIE enregistrée pour ${loc.name}');
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('GEOFENCE: $e');
    }
  }
}
