import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/classification_record.dart';

/// A dismissible list tile for a single [ClassificationRecord].
/// Swipe right-to-left to delete.
class HistoryTile extends StatelessWidget {
  final ClassificationRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const HistoryTile({
    super.key,
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(
        '${record.localImagePath}_${record.timestamp.millisecondsSinceEpoch}',
      ),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _Thumbnail(record: record),
        title: Text(
          record.label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          DateFormat('MMM d, yyyy  h:mm a').format(record.timestamp),
          style: const TextStyle(fontSize: 12, color: Colors.black45),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ConfidenceBadge(
              confidence: record.confidence,
              label: record.confidencePercent,
            ),
            const SizedBox(width: 4),
            if (!record.isSynced)
              const Tooltip(
                message: 'Not synced with server',
                child: Icon(
                  Icons.cloud_off_outlined,
                  size: 16,
                  color: Colors.orange,
                ),
              ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;
  final String label;

  const _ConfidenceBadge({required this.confidence, required this.label});

  Color get _color {
    if (confidence >= 0.75) return const Color(0xFF006A4E);
    if (confidence >= 0.5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final ClassificationRecord record;

  const _Thumbnail({required this.record});

  @override
  Widget build(BuildContext context) {
    final hasLocal =
        record.localImagePath.isNotEmpty &&
        File(record.localImagePath).existsSync();

    Widget child;
    if (hasLocal) {
      child = Image.file(File(record.localImagePath), fit: BoxFit.cover);
    } else if (record.imageUrl != null) {
      child = Image.network(
        record.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _PlaceholderIcon(),
      );
    } else {
      child = const _PlaceholderIcon();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 56, height: 56, child: child),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE8F5E9),
    child: const Icon(Icons.image_outlined, color: Colors.green, size: 28),
  );
}
