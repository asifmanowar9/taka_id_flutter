import 'package:flutter/foundation.dart';

/// A single entry in the top-K prediction list.
@immutable
class TopResult {
  final String label;
  final double confidence;

  const TopResult({required this.label, required this.confidence});

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  factory TopResult.fromJson(Map<String, dynamic> json) => TopResult(
    label: json['label'] as String,
    confidence: (json['confidence'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'label': label, 'confidence': confidence};
}

/// One complete classification event — stored locally and synced to the backend.
@immutable
class ClassificationRecord {
  /// MongoDB _id assigned by the backend (null until synced).
  final String? id;
  final String label;
  final double confidence;
  final List<TopResult> topResults;

  /// URL pointing to the image served by the backend.
  final String? imageUrl;

  /// Absolute path of the image on the device (used for display before sync).
  final String localImagePath;
  final DateTime timestamp;

  /// Whether this record has been successfully saved to the backend.
  final bool isSynced;

  const ClassificationRecord({
    this.id,
    required this.label,
    required this.confidence,
    required this.topResults,
    this.imageUrl,
    required this.localImagePath,
    required this.timestamp,
    this.isSynced = false,
  });

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  factory ClassificationRecord.fromJson(Map<String, dynamic> json) =>
      ClassificationRecord(
        id: json['_id'] as String?,
        label: json['label'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        topResults: (json['topResults'] as List<dynamic>)
            .map((e) => TopResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        imageUrl: json['imageUrl'] as String?,
        localImagePath: json['localImagePath'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
        isSynced: true,
      );

  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'label': label,
    'confidence': confidence,
    'topResults': topResults.map((r) => r.toJson()).toList(),
    if (imageUrl != null) 'imageUrl': imageUrl,
    'localImagePath': localImagePath,
    'timestamp': timestamp.toIso8601String(),
  };

  ClassificationRecord copyWith({
    String? id,
    String? label,
    double? confidence,
    List<TopResult>? topResults,
    String? imageUrl,
    String? localImagePath,
    DateTime? timestamp,
    bool? isSynced,
  }) => ClassificationRecord(
    id: id ?? this.id,
    label: label ?? this.label,
    confidence: confidence ?? this.confidence,
    topResults: topResults ?? this.topResults,
    imageUrl: imageUrl ?? this.imageUrl,
    localImagePath: localImagePath ?? this.localImagePath,
    timestamp: timestamp ?? this.timestamp,
    isSynced: isSynced ?? this.isSynced,
  );
}
