import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/classification_record.dart';

/// localStorage-backed local store for [ClassificationRecord]s.
/// Web implementation — uses window.localStorage via dart:html.
class LocalDb {
  static const _storageKey = 'taka_id_records';

  static String rowKey(ClassificationRecord r) =>
      r.id ?? '${r.localImagePath}_${r.timestamp.millisecondsSinceEpoch}';

  Future<void> upsertRecord(ClassificationRecord record) async {
    final records = await getAllRecords();
    final key = rowKey(record);
    final idx = records.indexWhere((r) => rowKey(r) == key);
    if (idx >= 0) {
      records[idx] = record;
    } else {
      records.add(record);
    }
    _persist(records);
  }

  Future<List<ClassificationRecord>> getAllRecords() async {
    final raw = html.window.localStorage[_storageKey];
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ClassificationRecord.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteByRowKey(String key) async {
    final records = await getAllRecords();
    records.removeWhere((r) => rowKey(r) == key);
    _persist(records);
  }

  Future<void> deleteById(String id) async {
    final records = await getAllRecords();
    records.removeWhere((r) => r.id == id);
    _persist(records);
  }

  void _persist(List<ClassificationRecord> records) {
    html.window.localStorage[_storageKey] =
        jsonEncode(records.map((r) => r.toJson()).toList());
  }
}

final localDbProvider = Provider<LocalDb>((_) => LocalDb());
