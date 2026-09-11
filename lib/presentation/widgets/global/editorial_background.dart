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
        // Base Layer: Cream Background if requested
        if (useCreamBase)
          Positioned.fill(
            child: Container(color: AppTheme.cream),
          ),

        // Branding Layer: Asset Image with low opacity
        Positioned.fill(
          child: Opacity(
            opacity: 0.08,
            child: Image.asset(
              'assets/branding/log-bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
        ),

        // Tint Layer: Warm Espresso overlay with subtle opacity
        Positioned.fill(
          child: Container(
            color: AppTheme.espressoBrown.withValues(alpha: 0.04),
          ),
        ),

        // Content Layer
        child,
      ],
    );
  }
}
