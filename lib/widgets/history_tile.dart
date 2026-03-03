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
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _Thumbnail(record: record),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'MMM d, yyyy  h:mm a',
                          ).format(record.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ConfidenceBadge(
                        confidence: record.confidence,
                        label: record.confidencePercent,
                      ),
                      const SizedBox(height: 6),
                      if (!record.isSynced)
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 14,
                          color: Colors.orange,
                        )
                      else
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Colors.black26,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withAlpha(80), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w800,
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
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 64, height: 64, child: child),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE8F5EE),
    child: const Icon(Icons.image_outlined, color: Color(0xFF006A4E), size: 28),
  );
}
