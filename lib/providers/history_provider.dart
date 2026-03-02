import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/classification_record.dart';
import '../services/api_service.dart';
import '../services/classifier.dart';

// ── ApiService provider ───────────────────────────────────────────────────────

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// ── Notifier ──────────────────────────────────────────────────────────────────

class HistoryNotifier extends AsyncNotifier<List<ClassificationRecord>> {
  @override
  Future<List<ClassificationRecord>> build() => _fetchFromBackend();

  Future<List<ClassificationRecord>> _fetchFromBackend() async {
    try {
      return await ref.read(apiServiceProvider).fetchHistory();
    } catch (_) {
      // Backend unreachable — start with empty list (offline mode).
      return [];
    }
  }

  /// Saves a new classification result to the backend.
  /// Optimistically inserts a local record immediately so the history list
  /// updates without waiting for the network.
  Future<void> addRecord({
    required ClassificationResult topResult,
    required List<ClassificationResult> topK,
    required File imageFile,
  }) async {
    final api = ref.read(apiServiceProvider);

    // Build an unsynced local record.
    final localRecord = ClassificationRecord(
      label: topResult.label,
      confidence: topResult.confidence,
      topResults: topK
          .map((r) => TopResult(label: r.label, confidence: r.confidence))
          .toList(),
      localImagePath: imageFile.path,
      timestamp: DateTime.now(),
      isSynced: false,
    );

    // Optimistically prepend to list.
    final current = state.valueOrNull ?? [];
    state = AsyncData([localRecord, ...current]);

    try {
      final saved = await api.saveRecord(localRecord, imageFile);

      // Replace the unsynced placeholder with the confirmed server record.
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
      // Keep the unsynced record — user can still see it locally.
    }
  }

  /// Deletes a record both from the backend and the local list.
  Future<void> deleteRecord(ClassificationRecord record) async {
    if (record.id == null) {
      // Not yet synced — only remove locally.
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
      return;
    }

    try {
      await ref.read(apiServiceProvider).deleteRecord(record.id!);
      final current = state.valueOrNull ?? [];
      state = AsyncData(current.where((r) => r.id != record.id).toList());
    } catch (_) {
      // Optionally surface this error in the UI via ref.listen in the screen.
    }
  }

  /// Re-fetches the full list from the backend.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchFromBackend);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<ClassificationRecord>>(
      HistoryNotifier.new,
    );
