import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/classification_record.dart';
import '../services/api_service.dart';
import '../services/classifier.dart';
import '../services/local_db.dart';
import 'auth_provider.dart';

// ── ApiService provider ───────────────────────────────────────────────────────
// Rebuilt whenever the auth token changes (login / logout / token refresh).

final apiServiceProvider = Provider<ApiService>((ref) {
  final token = ref.watch(accessTokenProvider);
  return ApiService(authToken: token);
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class HistoryNotifier extends AsyncNotifier<List<ClassificationRecord>> {
  @override
  Future<List<ClassificationRecord>> build() async {
    // Rebuilds when the user logs in or out.
    final user = ref.watch(currentUserProvider);

    // sqflite is the source of truth — load immediately (works offline).
    final db = ref.read(localDbProvider);
    final local = await db.getAllRecords();

    // Background sync with the backend only when authenticated.
    if (user != null) {
      Future.microtask(_backgroundSync);
    }

    return local;
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  Future<void> _backgroundSync() async {
    try {
      final api = ref.read(apiServiceProvider);
      final db = ref.read(localDbProvider);
      final remote = await api.fetchHistory();

      // Upsert each remote record into sqflite (marks them synced).
      for (final record in remote) {
        await db.upsertRecord(record);
      }

      // Refresh state from sqflite — keeps any local-only unsynced records too.
      final merged = await db.getAllRecords();
      state = AsyncData(merged);
    } catch (_) {
      // Sync failed silently — local data continues to show.
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Persists a new classification to sqflite immediately, then syncs to the
  /// backend when the user is authenticated. Optimistic UI update throughout.
  Future<void> addRecord({
    required ClassificationResult topResult,
    required List<ClassificationResult> topK,
    required XFile imageFile,
  }) async {
    final db = ref.read(localDbProvider);

    final localPath = await _resolveLocalImagePath(imageFile);

    final localRecord = ClassificationRecord(
      label: topResult.label,
      confidence: topResult.confidence,
      topResults: topK
          .map((r) => TopResult(label: r.label, confidence: r.confidence))
          .toList(),
      localImagePath: localPath,
      timestamp: DateTime.now(),
      isSynced: false,
    );

    // 1. Persist locally — survives app restart even if never synced.
    await db.upsertRecord(localRecord);

    // 2. Optimistically prepend to in-memory list.
    final current = state.valueOrNull ?? [];
    state = AsyncData([localRecord, ...current]);

    // 3. Sync to backend only when authenticated.
    if (ref.read(currentUserProvider) == null) return;

    try {
      final saved = await ref
          .read(apiServiceProvider)
          .saveRecord(localRecord, imageFile);

      // Update sqflite row with server id + imageUrl.
      await db.upsertRecord(saved);

      // Swap the unsynced placeholder with the confirmed server record.
      final updated = state.valueOrNull ?? [];
      state = AsyncData(
        updated.map((r) {
          if (!r.isSynced &&
              r.localImagePath == localRecord.localImagePath &&
              r.timestamp == localRecord.timestamp) {
            return saved;
          }
          return r;
        }).toList(),
      );
    } catch (_) {
      // Keep the unsynced record — sqflite and UI already reflect it.
    }
  }

  /// Deletes a record from sqflite and (when synced + authenticated) from the
  /// backend as well.
  Future<void> deleteRecord(ClassificationRecord record) async {
    final db = ref.read(localDbProvider);

    // Remove from sqflite first.
    if (record.id == null) {
      await db.deleteByRowKey(
        '${record.localImagePath}_${record.timestamp.millisecondsSinceEpoch}',
      );
    } else {
      await db.deleteById(record.id!);
    }

    // Remove from in-memory list.
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current
          .where(
            (r) =>
                r.localImagePath != record.localImagePath ||
                r.timestamp != record.timestamp,
          )
          .toList(),
    );

    // Mirror deletion to backend when the record is synced and user is signed in.
    if (record.id != null && ref.read(currentUserProvider) != null) {
      try {
        await ref.read(apiServiceProvider).deleteRecord(record.id!);
      } catch (_) {
        // Backend deletion failed; local record is already removed.
      }
    }
  }

  /// Fetches from the backend, merges into sqflite, then refreshes state.
  Future<void> refresh() async {
    state = const AsyncLoading();
    final db = ref.read(localDbProvider);
    try {
      final remote = await ref.read(apiServiceProvider).fetchHistory();
      for (final record in remote) {
        await db.upsertRecord(record);
      }
      state = AsyncData(await db.getAllRecords());
    } catch (_) {
      // Backend unreachable — still show whatever is in sqflite.
      state = AsyncData(await db.getAllRecords());
    }
  }

  Future<String> _resolveLocalImagePath(XFile imageFile) async {
    if (!kIsWeb) return imageFile.path;
    final bytes = await imageFile.readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<ClassificationRecord>>(
      HistoryNotifier.new,
    );
