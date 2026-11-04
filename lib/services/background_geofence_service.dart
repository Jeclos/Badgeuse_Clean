import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../data/database_helper.dart';
import '../data/models.dart';
import 'location_service.dart';

int? _pendingEnterTimestamp;
String? _pendingEnterLocation;

int? _pendingExitTimestamp;
String? _pendingExitLocation;

class BackgroundGeofenceService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: false,
        notificationChannelId: 'badgeuse_auto_geofence',
        initialNotificationTitle: 'Badgeuse Auto',
        initialNotificationContent: 'Surveillance GPS et géofencing actifs',
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
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  Timer.periodic(const Duration(seconds: 30), (timer) async {
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

      final now = DateTime.now().millisecondsSinceEpoch;

      for (var loc in activeLocations) {
        final distance = LocationService.instance.calculateDistance(
          position.latitude,
          position.longitude,
          loc.latitude,
          loc.longitude,
        );

        final radius = settings.enterDistance > 0 ? settings.enterDistance : 300.0;
        final enterDelayMs = settings.enterDelaySec * 1000;
        final exitDelayMs = settings.exitDelaySec * 1000;

        if (distance <= radius) {
          // Inside location radius
          _pendingExitTimestamp = null;
          _pendingExitLocation = null;

          if (!isWorking) {
            if (_pendingEnterLocation == loc.name) {
              if (_pendingEnterTimestamp != null &&
                  now - _pendingEnterTimestamp! >= enterDelayMs) {
                // Confirm Entry after delay
                await DatabaseHelper.instance.insertPresence(
                  PresenceEntity(
                    timestamp: now,
                    type: 'ENTRÉE',
                    locationName: loc.name,
                  ),
                );
                _pendingEnterTimestamp = null;
                _pendingEnterLocation = null;
                break;
              }
            } else {
              _pendingEnterTimestamp = now;
              _pendingEnterLocation = loc.name;
            }
          }
        } else {
          // Outside location radius
          _pendingEnterTimestamp = null;
          _pendingEnterLocation = null;

          if (isWorking && currentLocationName == loc.name) {
            if (distance > radius + 30) {
              if (_pendingExitLocation == loc.name) {
                if (_pendingExitTimestamp != null &&
                    now - _pendingExitTimestamp! >= exitDelayMs) {
                  // Confirm Exit after delay & verification
                  await DatabaseHelper.instance.insertPresence(
                    PresenceEntity(
                      timestamp: now,
                      type: 'SORTIE',
                      locationName: loc.name,
                    ),
                  );
                  _pendingExitTimestamp = null;
                  _pendingExitLocation = null;
                  break;
                }
              } else {
                _pendingExitTimestamp = now;
                _pendingExitLocation = loc.name;
              }
            }
          }
        }
      }
    } catch (e) {
      // Handle background error
    }
  });
}
