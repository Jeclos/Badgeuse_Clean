import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../data/database_helper.dart';
import '../data/models.dart';
import 'location_service.dart';

class BackgroundGeofenceService {
  static StreamSubscription<Position>? _positionStreamSubscription;

  static DateTime? _pendingEnterTime;
  static String? _pendingEnterLocation;

  static DateTime? _pendingExitTime;
  static String? _pendingExitLocation;

  static Future<void> initializeService() async {
    final hasPermission = await LocationService.instance.checkAndRequestPermissions();
    if (!hasPermission) return;

    _positionStreamSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Check every 10 meters moved
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

      final now = DateTime.now();

      for (var loc in activeLocations) {
        final distance = LocationService.instance.calculateDistance(
          position.latitude,
          position.longitude,
          loc.latitude,
          loc.longitude,
        );

        final radius = loc.radius > 0 ? loc.radius : (settings.enterDistance > 0 ? settings.enterDistance : 300.0);
        final enterDelaySec = settings.enterDelaySec;
        final exitDelaySec = settings.exitDelaySec;

        if (distance <= radius) {
          // Inside location radius
          _pendingExitTime = null;
          _pendingExitLocation = null;

          if (!isWorking) {
            if (_pendingEnterLocation == loc.name) {
              if (_pendingEnterTime != null &&
                  now.difference(_pendingEnterTime!).inSeconds >= enterDelaySec) {
                // Confirm Entry after delay
                await DatabaseHelper.instance.insertPresence(
                  PresenceEntity(
                    timestamp: now.millisecondsSinceEpoch,
                    type: 'ENTRÉE',
                    locationName: loc.name,
                  ),
                );
                _pendingEnterTime = null;
                _pendingEnterLocation = null;
                break;
              }
            } else {
              _pendingEnterTime = now;
              _pendingEnterLocation = loc.name;
            }
          }
        } else {
          // Outside location radius
          _pendingEnterTime = null;
          _pendingEnterLocation = null;

          if (isWorking && currentLocationName == loc.name) {
            if (distance > radius + 30) {
              if (_pendingExitLocation == loc.name) {
                if (_pendingExitTime != null &&
                    now.difference(_pendingExitTime!).inSeconds >= exitDelaySec) {
                  // Confirm Exit after delay
                  await DatabaseHelper.instance.insertPresence(
                    PresenceEntity(
                      timestamp: now.millisecondsSinceEpoch,
                      type: 'SORTIE',
                      locationName: loc.name,
                    ),
                  );
                  _pendingExitTime = null;
                  _pendingExitLocation = null;
                  break;
                }
              } else {
                _pendingExitTime = now;
                _pendingExitLocation = loc.name;
              }
            }
          }
        }
      }
    } catch (e) {
      // Handle error
    }
  }
}
