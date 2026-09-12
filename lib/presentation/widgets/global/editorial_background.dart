import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

class EditorialBackground extends StatelessWidget {
  final Widget child;
  final bool useCreamBase;

  const EditorialBackground({
    super.key,
    required this.child,
    this.useCreamBase = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Layer: Warm Background (#F7F4EF)
        if (useCreamBase)
          Positioned.fill(
            child: Container(color: AppTheme.backgroundWarm),
          ),

        // Branding Layer: Very Faint Decorative Illustration (around 2-4% opacity)
        Positioned.fill(
          child: Opacity(
            opacity: 0.025,
            child: Image.asset(
              'assets/branding/log-bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
        ),

        // Content Layer
        child,
      ],
    );
  }
}
