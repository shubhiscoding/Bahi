import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Simple key-value JSON cache backed by SQLite — used to mirror the
/// inventory/team lists for offline reads (design.md §9). Deliberately
/// not a typed relational schema: the app doesn't need to *query* this
/// data offline, just re-display the last known list, so a single
/// key -> JSON-blob table is the simplest thing that satisfies that.
class LocalCacheService {
  static Database? _db;

  static Future<Database> get _database async {
    if (_db != null) return _db!;

    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'bahi_cache.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE cache (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)',
        );
      },
    );
    return _db!;
  }

  /// Stores a JSON-encodable value (list/map) under a key.
  static Future<void> set(String key, dynamic value) async {
    final db = await _database;
    await db.insert(
      'cache',
      {
        'key': key,
        'value': jsonEncode(value),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Reads back a previously-stored value, or null if never cached.
  static Future<dynamic> get(String key) async {
    final db = await _database;
    final rows = await db.query('cache', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['value'] as String);
  }
}
