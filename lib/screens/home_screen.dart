import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/classifier_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/confidence_bar.dart';
import 'history_screen.dart';

// â”€â”€ Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Uses [ConsumerStatefulWidget] only for the [ImagePicker] instance and
/// mounted-safe async operations. All actual app state lives in Riverpod.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1024,
    );
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    final topResult = await ref
        .read(classifierProvider.notifier)
        .classify(file);

    if (!mounted || topResult == null) return;

    // Save to backend (history provider handles optimistic update).
    final classifierState = ref.read(classifierProvider).valueOrNull;
    await ref
        .read(historyProvider.notifier)
        .addRecord(
          topResult: topResult,
          topK: classifierState?.topK ?? [],
          imageFile: file,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Show a SnackBar on classifier errors (model load failure, inference crash).
    ref.listen<AsyncValue<ClassifierState>>(classifierProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Classifier error: ${next.error}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });

    final classifierAsync = ref.watch(classifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _AppBar(isLoading: classifierAsync.isLoading),
      body: classifierAsync.when(
        loading: () => const _ModelLoadingView(),
        error: (e, _) => _ModelErrorView(error: e.toString()),
        data: (state) => _BodyContent(
          state: state,
          hintLabels: ref.read(classifierProvider.notifier).labels,
        ),
      ),
      bottomNavigationBar: classifierAsync.maybeWhen(
        data: (_) => _BottomBar(onPickImage: _pickImage),
        orElse: () => null,
      ),
    );
  }
}

// â”€â”€ AppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isLoading;
  const _AppBar({required this.isLoading});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF006A4E),
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Row(
        children: [
          Text(
            'à§³',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 8),
          Text(
            'Taka Identifier',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
      actions: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: 'Classification history',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Body states â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ModelLoadingView extends StatelessWidget {
  const _ModelLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF006A4E)),
          SizedBox(height: 16),
          Text(
            'Loading classifier modelâ€¦',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ModelErrorView extends StatelessWidget {
  final String error;
  const _ModelErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Main body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BodyContent extends StatelessWidget {
  final ClassifierState state;
  final List<String> hintLabels;

  const _BodyContent({required this.state, required this.hintLabels});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ImageCard(image: state.selectedImage),
          const SizedBox(height: 16),
          if (state.isClassifying)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF006A4E)),
                  SizedBox(height: 12),
                  Text(
                    'Identifying banknoteâ€¦',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          if (!state.isClassifying && state.topResult != null) ...[
            _TopResultCard(state: state),
            const SizedBox(height: 12),
            if (state.topK.length > 1) _OtherResultsCard(state: state),
          ],
          if (!state.isClassifying && state.selectedImage == null)
            _HintChips(labels: hintLabels),
        ],
      ),
    );
  }
}

// â”€â”€ Image card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ImageCard extends StatelessWidget {
  final File? image;
  const _ImageCard({this.image});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: image != null
            ? Image.file(image!, fit: BoxFit.cover)
            : Container(
                color: const Color(0xFFE8F5E9),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 64,
                      color: Colors.green.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Select or capture a banknote image',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// â”€â”€ Result cards â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TopResultCard extends StatelessWidget {
  final ClassifierState state;
  const _TopResultCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final result = state.topResult!;
    final isHigh = result.confidence >= 0.75;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006A4E).withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF006A4E),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Identified as',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        result.label,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006A4E),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isHigh
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    result.confidencePercent,
                    style: TextStyle(
                      color: isHigh
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConfidenceBar(
              label: result.label,
              confidence: result.confidence,
              isTop: true,
            ),
            if (!isHigh) ...[
              const SizedBox(height: 8),
              const Text(
                'âš ï¸  Low confidence â€” try a clearer image',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OtherResultsCard extends StatelessWidget {
  final ClassifierState state;
  const _OtherResultsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Other possibilities',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            ...state.topK
                .skip(1)
                .map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ConfidenceBar(
                      label: r.label,
                      confidence: r.confidence,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Hint chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _HintChips extends StatelessWidget {
  final List<String> labels;
  const _HintChips({required this.labels});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Text(
            'Supports all Bangladeshi banknotes',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: labels
                .map(
                  (l) => Chip(
                    label: Text(l, style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFFE8F5E9),
                    side: const BorderSide(
                      color: Color(0xFF006A4E),
                      width: 0.5,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Bottom bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BottomBar extends StatelessWidget {
  final Future<void> Function(ImageSource) onPickImage;
  const _BottomBar({required this.onPickImage});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onPressed: () => onPickImage(ImageSource.gallery),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                primary: true,
                onPressed: () => onPickImage(ImageSource.camera),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 15)),
      style: ElevatedButton.styleFrom(
        backgroundColor: primary
            ? const Color(0xFF006A4E)
            : const Color(0xFFE8F5E9),
        foregroundColor: primary ? Colors.white : const Color(0xFF006A4E),
        elevation: primary ? 3 : 1,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: primary
              ? BorderSide.none
              : const BorderSide(color: Color(0xFF006A4E), width: 0.8),
        ),
      ),
    );
  }
}

// â”€â”€ State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
