import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../services/classifier.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class ClassifierState {
  final XFile? selectedImage;
  final ClassificationResult? topResult;
  final List<ClassificationResult> topK;
  final bool isClassifying;

  const ClassifierState({
    this.selectedImage,
    this.topResult,
    this.topK = const [],
    this.isClassifying = false,
  });

  ClassifierState copyWith({
    XFile? selectedImage,
    ClassificationResult? topResult,
    List<ClassificationResult>? topK,
    bool? isClassifying,
    bool clearResult = false,
  }) => ClassifierState(
    selectedImage: selectedImage ?? this.selectedImage,
    topResult: clearResult ? null : (topResult ?? this.topResult),
    topK: topK ?? this.topK,
    isClassifying: isClassifying ?? this.isClassifying,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ClassifierNotifier extends AsyncNotifier<ClassifierState> {
  late final BanknoteClassifier _classifier;

  @override
  Future<ClassifierState> build() async {
    _classifier = BanknoteClassifier();
    await _classifier.loadModel();
    // Automatically disposes the native interpreter when provider is disposed.
    ref.onDispose(_classifier.dispose);
    return const ClassifierState();
  }

  /// Exposed so the UI can show the list of supported denominations.
  List<String> get labels => _classifier.labels;

  /// Run TFLite inference on [imageFile].
  /// Updates the provider state and returns the top result (or null on error).
  Future<ClassificationResult?> classify(XFile imageFile) async {
    final current = state.valueOrNull;
    if (current == null) return null;

    state = AsyncData(
      current.copyWith(
        selectedImage: imageFile,
        isClassifying: true,
        clearResult: true,
      ),
    );

    try {
      final topK = await _classifier.classifyTopK(imageFile, k: 3);
      final topResult = topK.isNotEmpty ? topK.first : null;

      state = AsyncData(
        ClassifierState(
          selectedImage: imageFile,
          topResult: topResult,
          topK: topK,
          isClassifying: false,
        ),
      );

      return topResult;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Reset back to the initial empty state (keeps model loaded).
  void reset() => state = const AsyncData(ClassifierState());
}

// ── Provider ──────────────────────────────────────────────────────────────────

final classifierProvider =
    AsyncNotifierProvider<ClassifierNotifier, ClassifierState>(
      ClassifierNotifier.new,
    );
