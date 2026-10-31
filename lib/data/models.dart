class PresenceEntity {
  final int? id;
  final int timestamp;
  final String type; // ENTER, EXIT, MANUAL
  final String locationName;

  PresenceEntity({
    this.id,
    required this.timestamp,
    required this.type,
    required this.locationName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp,
        'type': type,
        'locationName': locationName,
      };

  factory PresenceEntity.fromMap(Map<String, dynamic> map) => PresenceEntity(
        id: map['id'],
        timestamp: map['timestamp'],
        type: map['type'],
        locationName: map['locationName'],
      );
}

class WorkLocationEntity {
  final int? id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;
  final bool isActive;
  final String geofenceUid;

  WorkLocationEntity({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.isActive,
    required this.geofenceUid,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'isActive': isActive ? 1 : 0,
        'geofenceUid': geofenceUid,
      };

  factory WorkLocationEntity.fromMap(Map<String, dynamic> map) => WorkLocationEntity(
        id: map['id'],
        name: map['name'],
        latitude: map['latitude'],
        longitude: map['longitude'],
        radius: map['radius'],
        isActive: map['isActive'] == 1,
        geofenceUid: map['geofenceUid'],
      );
}

class SettingsEntity {
  final int id;
  final double enterDistance;
  final int enterDelaySec;
  final int exitDelaySec;

  SettingsEntity({
    this.id = 1,
    required this.enterDistance,
    required this.enterDelaySec,
    required this.exitDelaySec,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'enterDistance': enterDistance,
        'enterDelaySec': enterDelaySec,
        'exitDelaySec': exitDelaySec,
      };

  factory SettingsEntity.fromMap(Map<String, dynamic> map) => SettingsEntity(
        id: map['id'] ?? 1,
        enterDistance: (map['enterDistance'] as num?)?.toDouble() ?? 300.0,
        enterDelaySec: map['enterDelaySec'] ?? 60,
        exitDelaySec: map['exitDelaySec'] ?? 60,
      );
}
