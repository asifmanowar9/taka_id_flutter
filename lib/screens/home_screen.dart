import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/classifier_provider.dart';
import '../providers/history_provider.dart';
import '../utils/local_image_provider.dart';
import '../widgets/app_loader.dart';
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
  final _tts = FlutterTts();

  /// Maps English model labels → Bengali speech text.
  static const _banglaLabels = {
    '2 Taka': 'দুই টাকা',
    '5 Taka': 'পাঁচ টাকা',
    '10 Taka': 'দশ টাকা',
    '20 Taka': 'বিশ টাকা',
    '50 Taka': 'পঞ্চাশ টাকা',
    '100 Taka': 'একশো টাকা',
    '200 Taka': 'দুইশো টাকা',
    '500 Taka': 'পাঁচশো টাকা',
    '1000 Taka': 'এক হাজার টাকা',
  };

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('bn-BD');
    _tts.setSpeechRate(0.45);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String label, {bool isUnknown = false}) async {
    final text = isUnknown
        ? 'এটি কোনো বাংলাদেশি টাকা নয়'
        : (_banglaLabels[label] ?? label);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1024,
    );
    if (picked == null || !mounted) return;

    final topResult = await ref
        .read(classifierProvider.notifier)
        .classify(picked);

    if (!mounted || topResult == null) return;

    // Speak the result in Bengali.
    _speak(topResult.label, isUnknown: topResult.isUnknown);

    // Don't save non-banknote results to history.
    if (topResult.isUnknown) return;

    // Save to backend (history provider handles optimistic update).
    final classifierState = ref.read(classifierProvider).valueOrNull;
    await ref
        .read(historyProvider.notifier)
        .addRecord(
          topResult: topResult,
          topK: classifierState?.topK ?? [],
          imageFile: picked,
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
      backgroundColor: const Color(0xFFF4F9F6),
      appBar: _AppBar(isLoading: classifierAsync.isLoading),
      body: classifierAsync.when(
        loading: () => const _ModelLoadingView(),
        error: (e, _) => _ModelErrorView(error: e.toString()),
        data: (state) => _BodyContent(
          state: state,
          hintLabels: ref.read(classifierProvider.notifier).labels,
          onTapImage: () => _pickImage(ImageSource.camera),
          onRefresh: () async {
            ref.read(classifierProvider.notifier).reset();
          },
          onReplay: () {
            final result = ref.read(classifierProvider).valueOrNull?.topResult;
            if (result != null) {
              _speak(result.label, isUnknown: result.isUnknown);
            }
          },
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
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 6,
      shadowColor: const Color(0xFF006A4E).withAlpha(80),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00875A), Color(0xFF004D38)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.currency_exchange_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'TakaID',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 12),
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
          icon: const Icon(Icons.history_rounded),
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
    return const AppLoader(message: 'Loading classifier model\u2026');
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
  final VoidCallback onTapImage;
  final Future<void> Function() onRefresh;
  final VoidCallback onReplay;

  const _BodyContent({
    required this.state,
    required this.hintLabels,
    required this.onTapImage,
    required this.onRefresh,
    required this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF006A4E),
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ImageCard(image: state.selectedImage, onTap: onTapImage),
            const SizedBox(height: 16),
            if (state.isClassifying)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: AppLoader(message: 'Identifying banknote\u2026'),
              ),
            if (!state.isClassifying && state.topResult != null) ...[
              _TopResultCard(state: state, onReplay: onReplay),
              const SizedBox(height: 12),
              if (!state.topResult!.isUnknown && state.topK.length > 1)
                _OtherResultsCard(state: state),
            ],
            if (!state.isClassifying && state.selectedImage == null)
              _HintChips(labels: hintLabels),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Image card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ImageCard extends StatelessWidget {
  final XFile? image;
  final VoidCallback onTap;
  const _ImageCard({this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006A4E).withAlpha(50),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: image != null
              ? GestureDetector(
                  onTap: onTap,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _SelectedImage(image: image!),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withAlpha(140),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(110),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Tap to retake',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : InkWell(
                  onTap: onTap,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF006A4E), Color(0xFF004D38)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withAlpha(60),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 52,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Tap to scan a banknote',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Point camera at any Bangladeshi note',
                          style: TextStyle(
                            color: Colors.white.withAlpha(180),
                            fontSize: 12,
                          ),
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

class _SelectedImage extends StatelessWidget {
  final XFile image;

  const _SelectedImage({required this.image});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: image.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    }

    final provider = localImageProvider(image.path);
    if (provider == null) {
      return const Center(child: Icon(Icons.broken_image_outlined));
    }
    return Image(image: provider, fit: BoxFit.cover);
  }
}

// â”€â”€ Result cards â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TopResultCard extends StatelessWidget {
  final ClassifierState state;
  final VoidCallback onReplay;
  const _TopResultCard({required this.state, required this.onReplay});

  @override
  Widget build(BuildContext context) {
    final result = state.topResult!;

    // ── Unknown / not a banknote ──────────────────────────────────────────
    if (result.isUnknown) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFFB71C1C), Color(0xFF7F0000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha(60),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Not a Banknote',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No note detected — try a clearer image.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.volume_up_rounded,
                  color: Colors.white.withAlpha(200),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(25),
                ),
                tooltip: 'Replay voice',
                onPressed: onReplay,
              ),
            ],
          ),
        ),
      );
    }

    // ── Normal result ─────────────────────────────────────────────────────
    final isHigh = result.confidence >= 0.75;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF006A4E), Color(0xFF004D38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006A4E).withAlpha(90),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'IDENTIFIED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isHigh
                        ? Colors.greenAccent.withAlpha(45)
                        : Colors.orangeAccent.withAlpha(45),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isHigh
                          ? Colors.greenAccent.withAlpha(130)
                          : Colors.orangeAccent.withAlpha(130),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    result.confidencePercent,
                    style: TextStyle(
                      color: isHigh
                          ? Colors.greenAccent.shade200
                          : Colors.orangeAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.volume_up_rounded,
                    color: Colors.white,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha(25),
                  ),
                  tooltip: 'Replay voice',
                  onPressed: onReplay,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              result.label,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: result.confidence,
                minHeight: 7,
                backgroundColor: Colors.white.withAlpha(30),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isHigh ? Colors.greenAccent.shade200 : Colors.orangeAccent,
                ),
              ),
            ),
            if (!isHigh) ...[
              const SizedBox(height: 10),
              const Text(
                'Low confidence — try a clearer image',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDEDE8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF006A4E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Other possibilities',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF006A4E),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 1,
                color: const Color(0xFF006A4E).withAlpha(80),
              ),
              const SizedBox(width: 8),
              Text(
                'Supported denominations',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 1,
                color: const Color(0xFF006A4E).withAlpha(80),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: labels
                .map(
                  (l) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF006A4E).withAlpha(80),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      l,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF006A4E),
                        fontWeight: FontWeight.w600,
                      ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => onPickImage(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF006A4E),
                    side: const BorderSide(
                      color: Color(0xFF006A4E),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.photo_library_rounded, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00875A), Color(0xFF004D38)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF006A4E).withAlpha(90),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => onPickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text(
                      'Camera',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
