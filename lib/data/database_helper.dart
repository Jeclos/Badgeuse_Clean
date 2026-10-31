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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE presence (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        type TEXT NOT NULL,
        locationName TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE work_locations (
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
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY,
        enterDistance REAL NOT NULL,
        enterDelaySec INTEGER NOT NULL,
        exitDelaySec INTEGER NOT NULL
      )
    ''');

    // Insert default settings
    await db.insert('settings', {
      'id': 1,
      'enterDistance': 300.0,
      'enterDelaySec': 60,
      'exitDelaySec': 60,
    });
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
    final db = await instance.database;
    return await db.insert('work_locations', location.toMap());
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
