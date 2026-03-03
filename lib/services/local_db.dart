import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/classification_record.dart';

/// SQLite-backed local store for [ClassificationRecord]s.
///
/// Acts as the source of truth on startup — the app reads from here first,
/// then syncs to the backend in the background.
class LocalDb {
  static const _dbName = 'taka_id.db';
  static const _table = 'history_records';
  static const _version = 1;

  Database? _db;

  // Lazy-open the database on first access.
  Future<Database> get _database async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, _dbName),
      version: _version,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_table (
          rowkey           TEXT PRIMARY KEY,
          id               TEXT,
          label            TEXT NOT NULL,
          confidence       REAL NOT NULL,
          top_results      TEXT NOT NULL,
          image_url        TEXT,
          local_image_path TEXT NOT NULL,
          timestamp        INTEGER NOT NULL,
          is_synced        INTEGER NOT NULL DEFAULT 0
        )
      '''),
    );
  }

  // ── rowkey helpers ─────────────────────────────────────────────────────────

  /// Stable primary key: server id for synced records,
  /// "localPath_timestampMs" for unsynced ones.
  static String rowKey(ClassificationRecord r) =>
      r.id ?? '${r.localImagePath}_${r.timestamp.millisecondsSinceEpoch}';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Insert or replace a record (identified by [rowKey]).
  Future<void> upsertRecord(ClassificationRecord record) async {
    final db = await _database;
    await db.insert(
      _table,
      _toRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Return all records ordered by most-recent first.
  Future<List<ClassificationRecord>> getAllRecords() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'timestamp DESC');
    return rows.map(_fromRow).toList();
  }

  /// Delete a record by its computed rowkey (used for unsynced records).
  Future<void> deleteByRowKey(String key) async {
    final db = await _database;
    await db.delete(_table, where: 'rowkey = ?', whereArgs: [key]);
  }

  /// Delete a synced record by its server-assigned id.
  Future<void> deleteById(String id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> _toRow(ClassificationRecord r) => {
    'rowkey': rowKey(r),
    'id': r.id,
    'label': r.label,
    'confidence': r.confidence,
    'top_results': jsonEncode(r.topResults.map((t) => t.toJson()).toList()),
    'image_url': r.imageUrl,
    'local_image_path': r.localImagePath,
    'timestamp': r.timestamp.millisecondsSinceEpoch,
    'is_synced': r.isSynced ? 1 : 0,
  };

  ClassificationRecord _fromRow(Map<String, dynamic> row) {
    final topResults =
        (jsonDecode(row['top_results'] as String) as List<dynamic>)
            .map((e) => TopResult.fromJson(e as Map<String, dynamic>))
            .toList();
    return ClassificationRecord(
      id: row['id'] as String?,
      label: row['label'] as String,
      confidence: row['confidence'] as double,
      topResults: topResults,
      imageUrl: row['image_url'] as String?,
      localImagePath: row['local_image_path'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      isSynced: (row['is_synced'] as int) == 1,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final localDbProvider = Provider<LocalDb>((_) => LocalDb());
