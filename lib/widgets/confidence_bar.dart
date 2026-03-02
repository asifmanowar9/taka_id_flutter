import 'package:flutter/material.dart';

/// A labelled horizontal progress bar showing a classification confidence value.
class ConfidenceBar extends StatelessWidget {
  final String label;
  final double confidence;

  /// When true, renders slightly larger and in the primary green colour.
  final bool isTop;

  const ConfidenceBar({
    super.key,
    required this.label,
    required this.confidence,
    this.isTop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
              fontSize: isTop ? 14 : 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence,
              minHeight: isTop ? 10 : 7,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isTop ? const Color(0xFF006A4E) : Colors.blueGrey.shade300,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            '${(confidence * 100).toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isTop ? 13 : 12,
              color: isTop ? const Color(0xFF006A4E) : Colors.black54,
              fontWeight: isTop ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
