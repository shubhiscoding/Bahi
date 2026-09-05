import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
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

  /// Only a genuine connectivity/timeout failure should trigger the
  /// stale-cache fallback below. A real bug found in prod: the original
  /// version of this check was a bare `catch (e)` around BOTH the HTTP
  /// call and the JSON→model mapping — so a mapping bug (or any other
  /// non-network exception) on an otherwise-successful response got
  /// silently treated as "offline" and served the stale cached blob
  /// forever (no TTL exists), masking the real error completely. A DB
  /// fix landed, the API started returning correct data, and the app
  /// kept showing the pre-fix cached value with zero error/log anywhere.
  /// Anything that isn't recognizably a connectivity issue must rethrow
  /// immediately instead of silently falling back.
  static bool _isNetworkFailure(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        default:
          return false;
      }
    }
    return e is SocketException;
  }

  /// Generic "try the network, fall back to the last cached snapshot"
  /// wrapper for a single object (Phase 12 §A) — same shape every
  /// repository was hand-rolling individually (see InventoryRepository.
  /// watchItems/BuyerRepository.watchBuyers, the original Phase 4/7
  /// pattern), pulled out once so the remaining read paths (business,
  /// units, buyer detail, bill/deposit detail, price history) don't each
  /// re-duplicate it. Rethrows if the fetch fails AND nothing was ever
  /// cached under this key — never fabricate data that was never seen.
  static Future<T> fetchWithFallback<T>({
    required String key,
    required Future<T> Function() fetch,
    required Map<String, dynamic> Function(T) toJson,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final value = await fetch();
      await set(key, toJson(value));
      return value;
    } catch (e) {
      if (!_isNetworkFailure(e)) rethrow;
      final cached = await get(key);
      if (cached != null) return fromJson(Map<String, dynamic>.from(cached));
      rethrow;
    }
  }

  /// Same as [fetchWithFallback], for a list of objects (item/buyer/unit/
  /// bill/deposit lists).
  static Future<List<T>> fetchListWithFallback<T>({
    required String key,
    required Future<List<T>> Function() fetch,
    required Map<String, dynamic> Function(T) toJson,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final list = await fetch();
      await set(key, list.map(toJson).toList());
      return list;
    } catch (e) {
      if (!_isNetworkFailure(e)) rethrow;
      final cached = await get(key);
      if (cached != null) {
        return (cached as List).map((json) => fromJson(Map<String, dynamic>.from(json))).toList();
      }
      rethrow;
    }
  }
}
