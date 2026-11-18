import 'package:flutter/foundation.dart';
import 'package:native_geofence/native_geofence.dart';
import '../data/database_helper.dart';
import '../data/models.dart';
import 'location_service.dart';

class BackgroundGeofenceService {
  /// À appeler au démarrage ET à chaque modification des lieux ou des réglages.
  static Future<void> initializeService() async {
    debugPrint('GEOFENCE: init démarrée');
    if (!await LocationService.instance.checkAndRequestPermissions()) {
      debugPrint('GEOFENCE: permission refusée');
      return;
    }

    try {
      await NativeGeofenceManager.instance.initialize();
      await NativeGeofenceManager.instance.removeAllGeofences();

      final settings = await DatabaseHelper.instance.getSettings();
      debugPrint('GEOFENCE: mode=${settings.badgeMode}');
      if (settings.badgeMode == 'MANUAL') return;

      final locations = await DatabaseHelper.instance.getAllWorkLocations();
      debugPrint('GEOFENCE: ${locations.length} lieux, ${locations.where((l) => l.isActive).length} actifs');

      for (final loc in locations.where((l) => l.isActive)) {
        final radius = loc.radius > 0
            ? loc.radius
            : (settings.enterDistance > 0 ? settings.enterDistance : 300.0);

        final zone = Geofence(
          id: loc.geofenceUid.isNotEmpty ? loc.geofenceUid : loc.name,
          location: Location(latitude: loc.latitude, longitude: loc.longitude),
          radiusMeters: radius.clamp(100.0, 5000.0).toDouble(),
          triggers: {GeofenceEvent.enter, GeofenceEvent.exit},
          iosSettings: const IosGeofenceSettings(initialTrigger: true),
          androidSettings: const AndroidGeofenceSettings(
            initialTriggers: {GeofenceEvent.enter},
          ),
        );
        await NativeGeofenceManager.instance.createGeofence(zone, geofenceTriggered);
        debugPrint('GEOFENCE: zone créée ${loc.name} id=${zone.id} rayon=${zone.radiusMeters} lat=${loc.latitude} lon=${loc.longitude}');
      }
    } catch (e) {
      debugPrint('GEOFENCE init error: $e');
    }
  }
}

/// Tourne dans un isolate séparé, même appli fermée.
@pragma('vm:entry-point')
Future<void> geofenceTriggered(GeofenceCallbackParams params) async {
  try {
    debugPrint('GEOFENCE: callback ${params.event} ${params.geofences.map((g) => g.id).toList()}');
    final settings = await DatabaseHelper.instance.getSettings();
    if (settings.badgeMode == 'MANUAL') return;

    final presences = await DatabaseHelper.instance.getAllPresences();
    final last = presences.isNotEmpty ? presences.first : null;
    final isWorking = last != null && last.type == 'ENTRÉE';
    debugPrint('GEOFENCE: mode=${settings.badgeMode} isWorking=$isWorking dernier=${last?.type} ${last?.locationName}');

    final locations = await DatabaseHelper.instance.getAllWorkLocations();

    for (final g in params.geofences) {
      final matches = locations.where((l) =>
          (l.geofenceUid.isNotEmpty ? l.geofenceUid : l.name) == g.id);
      if (matches.isEmpty) {
        debugPrint('GEOFENCE: aucun lieu ne correspond à ${g.id}');
        continue;
      }
      final name = matches.first.name;

      if (params.event == GeofenceEvent.enter && !isWorking) {
        await DatabaseHelper.instance.insertPresence(PresenceEntity(
          timestamp: DateTime.now().millisecondsSinceEpoch,
          type: 'ENTRÉE',
          locationName: name,
        ));
        debugPrint('GEOFENCE: ENTREE $name');
      } else if (params.event == GeofenceEvent.exit &&
          isWorking && last?.locationName == name) {
        await DatabaseHelper.instance.insertPresence(PresenceEntity(
          timestamp: DateTime.now().millisecondsSinceEpoch,
          type: 'SORTIE',
          locationName: name,
        ));
        debugPrint('GEOFENCE: SORTIE $name');
      }
    }
  } catch (e) {
    debugPrint('GEOFENCE callback: $e');
  }
}
