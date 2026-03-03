import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

/// Full-screen loading overlay used throughout the app.
///
/// Uses [LoadingAnimationWidget.hexagonDots] for a modern branded look.
/// Wrap in a [Stack] to overlay on top of existing content.
class AppLoader extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;

  /// When true, renders on a semi-transparent white background (overlay mode).
  /// When false, renders on the scaffold background (full-page mode).
  final bool overlay;

  const AppLoader({
    super.key,
    this.message,
    this.size = 52,
    this.color,
    this.overlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF006A4E);

    final content = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.hexagonDots(color: c, size: size),
          if (message != null) ...[
            const SizedBox(height: 20),
            Text(
              message!,
              style: TextStyle(
                color: c,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );

    if (overlay) {
      return Container(color: Colors.white.withAlpha(230), child: content);
    }

    return content;
  }
}
