import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/database_helper.dart';
import '../data/models.dart';
import 'location_service.dart';

class BackgroundGeofenceService {
  static Future<void> initializeService() async {
    final hasPermission = await LocationService.instance.checkAndRequestPermissions();
    if (!hasPermission) return;

    final service = FlutterBackgroundService();

    // Create notification channel for Android to prevent startForeground crashes
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'badgeuse_auto_foreground',
      'Badgeuse Auto Service',
      description: 'Surveillance GPS en arrière-plan',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'badgeuse_auto_foreground',
        initialNotificationTitle: 'Badgeuse Auto',
        initialNotificationContent: 'Surveillance GPS active en arrière-plan',
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
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Badgeuse Auto",
          content: "Surveillance GPS active en arrière-plan",
        );
      }
    }

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
  });
}
