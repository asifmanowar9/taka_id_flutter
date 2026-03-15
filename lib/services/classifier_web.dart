import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Holds the result of a single classification.
class ClassificationResult {
  final String label;
  final double confidence;

  /// True when confidence is below [BanknoteClassifier.confidenceThreshold].
  /// The image is likely not a Bangladeshi banknote.
  final bool isUnknown;

  const ClassificationResult({
    required this.label,
    required this.confidence,
    this.isUnknown = false,
  });

  /// Confidence as a human-readable percentage string, e.g. "97.3%"
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
}

/// Web stub for the banknote classifier. The model is not available on web,
/// so this provides labels and returns a safe placeholder result.
class BanknoteClassifier {
  static const String _labelsAsset = 'assets/labels.txt';

  /// Model input spatial size — kept for API parity.
  static const int inputSize = 128;

  /// Predictions below this threshold are reported as "Not a Banknote".
  static const double confidenceThreshold = 0.40;

  static const bool modelHasBuiltInRescaling = false;
  static const bool useMobileNetNormalization = false;
  static const bool useResNet50Preprocessing = false;

  List<String> _labels = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<String> get labels => List.unmodifiable(_labels);

  Future<void> loadModel() async {
    try {
      final raw = await rootBundle.loadString(_labelsAsset);
      _labels = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      _isLoaded = true;
    } catch (_) {
      _labels = const [];
      _isLoaded = false;
    }
  }

  Future<ClassificationResult?> classify(XFile imageFile) async {
    if (!_isLoaded) return null;
    return const ClassificationResult(
      label: 'Not a Banknote',
      confidence: 0.0,
      isUnknown: true,
    );
  }

  Future<List<ClassificationResult>> classifyTopK(
    XFile imageFile, {
    int k = 3,
  }) async {
    if (!_isLoaded) return [];
    return const [
      ClassificationResult(
        label: 'Not a Banknote',
        confidence: 0.0,
        isUnknown: true,
      ),
    ];
  }

  void dispose() {
    _isLoaded = false;
  }
}
