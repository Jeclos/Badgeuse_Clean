class PresenceEntity {
  final int? id;
  final int timestamp;
  final String type; // ENTRÉE, SORTIE, MANUAL, AUTO_OFFICE, AUTO_DEPOT, AUTO_HOME_TRAVEL
  final String locationName;
  final int? workLocationId;
  final int? enterTime;
  final int? exitTime;
  final String? enterType;
  final String? exitType;
  final bool locked;

  PresenceEntity({
    this.id,
    required this.timestamp,
    required this.type,
    required this.locationName,
    this.workLocationId,
    this.enterTime,
    this.exitTime,
    this.enterType,
    this.exitType,
    this.locked = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp,
        'type': type,
        'locationName': locationName,
        'workLocationId': workLocationId,
        'enterTime': enterTime,
        'exitTime': exitTime,
        'enterType': enterType,
        'exitType': exitType,
        'locked': locked ? 1 : 0,
      };

  factory PresenceEntity.fromMap(Map<String, dynamic> map) => PresenceEntity(
        id: map['id'],
        timestamp: map['timestamp'] ?? 0,
        type: map['type'] ?? 'ENTRÉE',
        locationName: map['locationName'] ?? '',
        workLocationId: map['workLocationId'],
        enterTime: map['enterTime'],
        exitTime: map['exitTime'],
        enterType: map['enterType'],
        exitType: map['exitType'],
        locked: (map['locked'] ?? 0) == 1,
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
        name: map['name'] ?? '',
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
        radius: (map['radius'] as num?)?.toDouble() ?? 300.0,
        isActive: (map['isActive'] ?? 1) == 1,
        geofenceUid: map['geofenceUid'] ?? '',
      );
}

class SettingsEntity {
  final int id;
  final double enterDistance;
  final double exitDistance;
  final int enterDelaySec;
  final int exitDelaySec;
  final int dailyWorkHours;
  final String employeeName;
  final String employeeAddress;
  final String employerName;
  final String employerAddress;
  final String cityPdf;
  final String badgeMode; // OFFICE, DEPOT, HOME_TRAVEL, MANUAL
  
  // Home / Travel
  final double homeLatitude;
  final double homeLongitude;
  final int travelTimeMin;

  // Depot
  final int depotStartHour;
  final int depotStartMinute;
  final int depotEndHour;
  final int depotEndMinute;
  final int depotDailyAdjustMin;

  // Lunch Break
  final bool lunchBreakEnabled;
  final int lunchStartHour;
  final int lunchStartMin;
  final int lunchEndHour;
  final int lunchEndMin;
  final int lunchDurationMin;
  final int lunchWindowStartHour;
  final int lunchWindowStartMinute;
  final int lunchWindowEndHour;
  final int lunchWindowEndMinute;
  final int lunchMinDurationMin;
  final int lunchDefaultDurationMin;

  SettingsEntity({
    this.id = 1,
    required this.enterDistance,
    this.exitDistance = 150.0,
    required this.enterDelaySec,
    required this.exitDelaySec,
    this.dailyWorkHours = 7,
    this.employeeName = '',
    this.employeeAddress = '',
    this.employerName = '',
    this.employerAddress = '',
    this.cityPdf = '',
    this.badgeMode = 'OFFICE',
    this.homeLatitude = 0.0,
    this.homeLongitude = 0.0,
    this.travelTimeMin = 0,
    this.depotStartHour = 7,
    this.depotStartMinute = 0,
    this.depotEndHour = 17,
    this.depotEndMinute = 0,
    this.depotDailyAdjustMin = 0,
    this.lunchBreakEnabled = false,
    this.lunchStartHour = 12,
    this.lunchStartMin = 0,
    this.lunchEndHour = 14,
    this.lunchEndMin = 0,
    this.lunchDurationMin = 45,
    this.lunchWindowStartHour = 12,
    this.lunchWindowStartMinute = 0,
    this.lunchWindowEndHour = 14,
    this.lunchWindowEndMinute = 0,
    this.lunchMinDurationMin = 45,
    this.lunchDefaultDurationMin = 45,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'enterDistance': enterDistance,
        'exitDistance': exitDistance,
        'enterDelaySec': enterDelaySec,
        'exitDelaySec': exitDelaySec,
        'dailyWorkHours': dailyWorkHours,
        'employeeName': employeeName,
        'employeeAddress': employeeAddress,
        'employerName': employerName,
        'employerAddress': employerAddress,
        'cityPdf': cityPdf,
        'badgeMode': badgeMode,
        'homeLatitude': homeLatitude,
        'homeLongitude': homeLongitude,
        'travelTimeMin': travelTimeMin,
        'depotStartHour': depotStartHour,
        'depotStartMinute': depotStartMinute,
        'depotEndHour': depotEndHour,
        'depotEndMinute': depotEndMinute,
        'depotDailyAdjustMin': depotDailyAdjustMin,
        'lunchBreakEnabled': lunchBreakEnabled ? 1 : 0,
        'lunchStartHour': lunchStartHour,
        'lunchStartMin': lunchStartMin,
        'lunchEndHour': lunchEndHour,
        'lunchEndMin': lunchEndMin,
        'lunchDurationMin': lunchDurationMin,
        'lunchWindowStartHour': lunchWindowStartHour,
        'lunchWindowStartMinute': lunchWindowStartMinute,
        'lunchWindowEndHour': lunchWindowEndHour,
        'lunchWindowEndMinute': lunchWindowEndMinute,
        'lunchMinDurationMin': lunchMinDurationMin,
        'lunchDefaultDurationMin': lunchDefaultDurationMin,
      };

  factory SettingsEntity.fromMap(Map<String, dynamic> map) => SettingsEntity(
        id: map['id'] ?? 1,
        enterDistance: (map['enterDistance'] as num?)?.toDouble() ?? 300.0,
        exitDistance: (map['exitDistance'] as num?)?.toDouble() ?? 150.0,
        enterDelaySec: map['enterDelaySec'] ?? 60,
        exitDelaySec: map['exitDelaySec'] ?? 60,
        dailyWorkHours: map['dailyWorkHours'] ?? 7,
        employeeName: map['employeeName'] ?? '',
        employeeAddress: map['employeeAddress'] ?? '',
        employerName: map['employerName'] ?? '',
        employerAddress: map['employerAddress'] ?? '',
        cityPdf: map['cityPdf'] ?? '',
        badgeMode: map['badgeMode'] ?? 'OFFICE',
        homeLatitude: (map['homeLatitude'] as num?)?.toDouble() ?? 0.0,
        homeLongitude: (map['homeLongitude'] as num?)?.toDouble() ?? 0.0,
        travelTimeMin: map['travelTimeMin'] ?? 0,
        depotStartHour: map['depotStartHour'] ?? 7,
        depotStartMinute: map['depotStartMinute'] ?? 0,
        depotEndHour: map['depotEndHour'] ?? 17,
        depotEndMinute: map['depotEndMinute'] ?? 0,
        depotDailyAdjustMin: map['depotDailyAdjustMin'] ?? 0,
        lunchBreakEnabled: (map['lunchBreakEnabled'] ?? 0) == 1,
        lunchStartHour: map['lunchStartHour'] ?? 12,
        lunchStartMin: map['lunchStartMin'] ?? 0,
        lunchEndHour: map['lunchEndHour'] ?? 14,
        lunchEndMin: map['lunchEndMin'] ?? 0,
        lunchDurationMin: map['lunchDurationMin'] ?? 45,
        lunchWindowStartHour: map['lunchWindowStartHour'] ?? 12,
        lunchWindowStartMinute: map['lunchWindowStartMinute'] ?? 0,
        lunchWindowEndHour: map['lunchWindowEndHour'] ?? 14,
        lunchWindowEndMinute: map['lunchWindowEndMinute'] ?? 0,
        lunchMinDurationMin: map['lunchMinDurationMin'] ?? 45,
        lunchDefaultDurationMin: map['lunchDefaultDurationMin'] ?? 45,
      );
}
