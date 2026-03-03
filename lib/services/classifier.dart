import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

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

/// Wraps TFLite inference for the Bangladeshi banknote classifier.
///
/// Usage:
///   final classifier = BanknoteClassifier();
///   await classifier.loadModel();
///   final result = await classifier.classify(imageFile);
///   classifier.dispose();
class BanknoteClassifier {
  static const String _modelAsset = 'assets/model/banknote_classifier.tflite';
  static const String _labelsAsset = 'assets/labels.txt';

  /// Model input spatial size — confirmed from convert_model.py output:
  ///   Model input shape: (None, 224, 224, 3)
  static const int inputSize = 224;

  /// Predictions below this threshold are reported as "Not a Banknote".
  /// Tune this value if legitimate notes are rejected or non-notes slip through.
  static const double confidenceThreshold = 0.70;

  /// The model contains a built-in Rescaling layer that divides pixels by 255.
  /// Therefore the app must feed RAW [0, 255] float32 values — do NOT
  /// normalise again here, or inference will be wrong.
  static const bool modelHasBuiltInRescaling = true;

  /// Only relevant when [modelHasBuiltInRescaling] is false.
  /// Set to true for MobileNet-style [-1, 1] normalisation.
  static const bool useMobileNetNormalization = false;

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<String> get labels => List.unmodifiable(_labels);

  // ── Public API ──────────────────────────────────────────────────────────

  /// Load the TFLite model and labels from Flutter assets.
  /// Call this once, e.g. in initState() or during app startup.
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
      _interpreter!.allocateTensors();

      final raw = await rootBundle.loadString(_labelsAsset);
      _labels = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      _isLoaded = true;
    } catch (e) {
      _isLoaded = false;
      rethrow;
    }
  }

  /// Classify [imageFile] and return the top prediction.
  /// Returns null if the model is not loaded or the image cannot be decoded.
  Future<ClassificationResult?> classify(File imageFile) async {
    if (!_isLoaded || _interpreter == null) return null;

    // ── 1. Decode image ────────────────────────────────────────────────
    final bytes = await imageFile.readAsBytes();
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // ── 2. Resize to model input ───────────────────────────────────────
    final resized = img.copyResize(
      decoded,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    // ── 3. Build Float32 tensor [1, H, W, 3] ──────────────────────────
    final input = _imageToTensor(resized);

    // ── 4. Prepare output buffer ───────────────────────────────────────
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final numClasses = outputShape.last;
    // Support both [1, N] and [N] output shapes
    final output = List.generate(
      outputShape[0],
      (_) => List<double>.filled(numClasses, 0.0),
    );

    // ── 5. Run inference ───────────────────────────────────────────────
    _interpreter!.run(input, output);

    // ── 6. Pick argmax ─────────────────────────────────────────────────
    final probabilities = output[0];
    int maxIdx = 0;
    double maxProb = probabilities[0];
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIdx = i;
      }
    }

    final label = maxIdx < _labels.length ? _labels[maxIdx] : 'Class $maxIdx';
    if (maxProb < confidenceThreshold) {
      return ClassificationResult(
        label: 'Not a Banknote',
        confidence: maxProb,
        isUnknown: true,
      );
    }
    return ClassificationResult(label: label, confidence: maxProb);
  }

  /// Return the top-[k] predictions sorted by confidence (highest first).
  Future<List<ClassificationResult>> classifyTopK(
    File imageFile, {
    int k = 3,
  }) async {
    if (!_isLoaded || _interpreter == null) return [];

    final bytes = await imageFile.readAsBytes();
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return [];

    final resized = img.copyResize(
      decoded,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    final input = _imageToTensor(resized);
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final numClasses = outputShape.last;
    final output = List.generate(
      outputShape[0],
      (_) => List<double>.filled(numClasses, 0.0),
    );
    _interpreter!.run(input, output);

    final probs = output[0];
    final indexed = List.generate(
      probs.length,
      (i) => ClassificationResult(
        label: i < _labels.length ? _labels[i] : 'Class $i',
        confidence: probs[i],
      ),
    );
    indexed.sort((a, b) => b.confidence.compareTo(a.confidence));
    final topList = indexed.take(k).toList();

    // If the best match is below the threshold, treat as unknown.
    if (topList.isNotEmpty && topList.first.confidence < confidenceThreshold) {
      return [
        ClassificationResult(
          label: 'Not a Banknote',
          confidence: topList.first.confidence,
          isUnknown: true,
        ),
      ];
    }
    return topList;
  }

  /// Release native resources.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  /// Convert a decoded [img.Image] to a Float32 tensor shaped [1, H, W, 3].
  List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    return List.generate(1, (_) {
      return List.generate(inputSize, (y) {
        return List.generate(inputSize, (x) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();

          if (modelHasBuiltInRescaling) {
            // Model has a Rescaling layer — pass raw [0, 255] float32 values.
            return [r, g, b];
          } else if (useMobileNetNormalization) {
            // MobileNet: [0,255] → [-1, 1]
            return [(r / 127.5) - 1.0, (g / 127.5) - 1.0, (b / 127.5) - 1.0];
          } else {
            // Simple: [0,255] → [0, 1]
            return [r / 255.0, g / 255.0, b / 255.0];
          }
        });
      });
    });
  }
}
