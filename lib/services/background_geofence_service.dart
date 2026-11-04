import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../data/database_helper.dart';
import '../data/models.dart';
import 'location_service.dart';

class BackgroundGeofenceService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'badgeuse_auto_geofence',
        initialNotificationTitle: 'Badgeuse Auto',
        initialNotificationContent: 'Surveillance GPS en arrière-plan active',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: (ServiceInstance service) => true,
      ),
    );

    await service.startService();
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    Timer.periodic(const Duration(seconds: 60), (timer) async {
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

          final radius = settings.enterDistance > 0 ? settings.enterDistance : 300.0;

          if (distance <= radius) {
            // Entered location
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
            // Exited location
            if (isWorking && currentLocationName == loc.name) {
              // Check if far enough to trigger exit (e.g. radius + 50m)
              if (distance > radius + 50) {
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
        // Handle background error
      }
    });
  }
}
