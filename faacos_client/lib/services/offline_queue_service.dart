import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, 'offline_sync.db');

    return await openDatabase(
      pathString,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type TEXT,
            payload TEXT,
            timestamp INTEGER,
            retry_count INTEGER DEFAULT 0,
            status TEXT DEFAULT 'pending'
          )
        ''');
      },
    );
  }

  Future<int> addToQueue(String actionType, Map<String, dynamic> payload) async {
    final db = await database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('sync_queue', {
      'action_type': actionType,
      'payload': json.encode(payload),
      'timestamp': timestamp,
      'retry_count': 0,
      'status': 'pending',
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> getPendingItems() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: "status = 'pending' AND retry_count < 3",
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> markAsSynced(int id) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'status': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> incrementRetry(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  Future<void> markAsFailed(int id) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'status': 'failed'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
