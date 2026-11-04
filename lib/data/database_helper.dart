import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('badgeuse.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS presence (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        type TEXT NOT NULL,
        locationName TEXT NOT NULL,
        workLocationId INTEGER,
        enterTime INTEGER,
        exitTime INTEGER,
        enterType TEXT,
        exitType TEXT,
        locked INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS work_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius REAL NOT NULL,
        isActive INTEGER NOT NULL,
        geofenceUid TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY,
        enterDistance REAL NOT NULL,
        exitDistance REAL NOT NULL,
        enterDelaySec INTEGER NOT NULL,
        exitDelaySec INTEGER NOT NULL,
        dailyWorkHours INTEGER NOT NULL,
        employeeName TEXT,
        employeeAddress TEXT,
        employerName TEXT,
        employerAddress TEXT,
        cityPdf TEXT,
        badgeMode TEXT,
        homeLatitude REAL,
        homeLongitude REAL,
        travelTimeMin INTEGER,
        depotStartHour INTEGER,
        depotStartMinute INTEGER,
        depotEndHour INTEGER,
        depotEndMinute INTEGER,
        depotDailyAdjustMin INTEGER,
        lunchBreakEnabled INTEGER,
        lunchStartHour INTEGER,
        lunchStartMin INTEGER,
        lunchEndHour INTEGER,
        lunchEndMin INTEGER,
        lunchDurationMin INTEGER,
        lunchWindowStartHour INTEGER,
        lunchWindowStartMinute INTEGER,
        lunchWindowEndHour INTEGER,
        lunchWindowEndMinute INTEGER,
        lunchMinDurationMin INTEGER,
        lunchDefaultDurationMin INTEGER
      )
    ''');

    // Insert default settings if not exists
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM settings')) ?? 0;
    if (count == 0) {
      await db.insert('settings', {
        'id': 1,
        'enterDistance': 300.0,
        'exitDistance': 150.0,
        'enterDelaySec': 60,
        'exitDelaySec': 60,
        'dailyWorkHours': 7,
        'employeeName': '',
        'employeeAddress': '',
        'employerName': '',
        'employerAddress': '',
        'cityPdf': '',
        'badgeMode': 'OFFICE',
        'homeLatitude': 0.0,
        'homeLongitude': 0.0,
        'travelTimeMin': 0,
        'depotStartHour': 7,
        'depotStartMinute': 0,
        'depotEndHour': 17,
        'depotEndMinute': 0,
        'depotDailyAdjustMin': 0,
        'lunchBreakEnabled': 0,
        'lunchStartHour': 12,
        'lunchStartMin': 0,
        'lunchEndHour': 14,
        'lunchEndMin': 0,
        'lunchDurationMin': 45,
        'lunchWindowStartHour': 12,
        'lunchWindowStartMinute': 0,
        'lunchWindowEndHour': 14,
        'lunchWindowEndMinute': 0,
        'lunchMinDurationMin': 45,
        'lunchDefaultDurationMin': 45,
      });
    }
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS presence');
    await db.execute('DROP TABLE IF EXISTS work_locations');
    await db.execute('DROP TABLE IF EXISTS settings');
    await _createDB(db, newVersion);
  }

  // Presence methods
  Future<int> insertPresence(PresenceEntity presence) async {
    final db = await instance.database;
    return await db.insert('presence', presence.toMap());
  }

  Future<List<PresenceEntity>> getAllPresences() async {
    final db = await instance.database;
    final result = await db.query('presence', orderBy: 'timestamp DESC');
    return result.map((map) => PresenceEntity.fromMap(map)).toList();
  }

  Future<int> clearPresences() async {
    final db = await instance.database;
    return await db.delete('presence');
  }

  // Work Locations methods
  Future<int> insertWorkLocation(WorkLocationEntity location) async {
    final dbInstance = await instance.database;
    return await dbInstance.insert('work_locations', location.toMap());
  }

  Future<List<WorkLocationEntity>> getAllWorkLocations() async {
    final db = await instance.database;
    final result = await db.query('work_locations');
    return result.map((map) => WorkLocationEntity.fromMap(map)).toList();
  }

  Future<int> deleteWorkLocation(int id) async {
    final db = await instance.database;
    return await db.delete('work_locations', where: 'id = ?', whereArgs: [id]);
  }

  // Settings methods
  Future<SettingsEntity> getSettings() async {
    final db = await instance.database;
    final result = await db.query('settings', where: 'id = ?', whereArgs: [1]);
    if (result.isNotEmpty) {
      return SettingsEntity.fromMap(result.first);
    }
    return SettingsEntity(enterDistance: 300.0, enterDelaySec: 60, exitDelaySec: 60);
  }

  Future<int> updateSettings(SettingsEntity settings) async {
    final db = await instance.database;
    return await db.update('settings', settings.toMap(), where: 'id = ?', whereArgs: [1]);
  }
}
