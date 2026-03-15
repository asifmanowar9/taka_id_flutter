import 'dart:io';

import 'package:flutter/material.dart';

import '../models/classification_record.dart';

class RecordImage extends StatelessWidget {
  final ClassificationRecord record;
  final BoxFit fit;
  final Widget placeholder;

  const RecordImage({
    super.key,
    required this.record,
    required this.placeholder,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocal =
        record.localImagePath.isNotEmpty &&
        File(record.localImagePath).existsSync();

    if (hasLocal) {
      return Image.file(File(record.localImagePath), fit: fit);
    }
    if (record.imageUrl != null) {
      return Image.network(
        record.imageUrl!,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    return placeholder;
  }
}
