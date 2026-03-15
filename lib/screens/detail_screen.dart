import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/classification_record.dart';
import '../providers/history_provider.dart';
import '../utils/local_image_provider.dart';
import '../widgets/confidence_bar.dart';

class DetailScreen extends ConsumerWidget {
  final ClassificationRecord record;

  const DetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHigh = record.confidence >= 0.75;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F6),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, ref),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Main result card ──────────────────────────────────
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Identified as',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      record.label,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF006A4E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isHigh
                                      ? Colors.green.shade100
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  record.confidencePercent,
                                  style: TextStyle(
                                    color: isHigh
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 13,
                                color: Colors.black45,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat(
                                  'MMMM d, yyyy — h:mm a',
                                ).format(record.timestamp),
                                style: const TextStyle(
                                  color: Colors.black45,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (!record.isSynced) ...[
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(
                                  Icons.cloud_off_outlined,
                                  size: 14,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Not synced with server',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Confidence breakdown card ──────────────────────────
                  if (record.topResults.isNotEmpty)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Confidence breakdown',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...record.topResults.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ConfidenceBar(
                                  label: entry.value.label,
                                  confidence: entry.value.confidence,
                                  isTop: entry.key == 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, WidgetRef ref) {
    final provider = localImageProvider(record.localImagePath);

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF004D38),
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete record',
          onPressed: () => _confirmDelete(context, ref),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: provider != null
            ? Image(image: provider, fit: BoxFit.cover)
            : record.imageUrl != null
            ? Image.network(
                record.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _PlaceholderBg(),
              )
            : const _PlaceholderBg(),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: const Text(
          'This will permanently remove this classification record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(historyProvider.notifier).deleteRecord(record);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _PlaceholderBg extends StatelessWidget {
  const _PlaceholderBg();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF004D38),
    child: const Center(
      child: Icon(Icons.image_outlined, size: 80, color: Colors.white24),
    ),
  );
}
