import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

/// Professional image placeholder component for billing and checkout cards.
/// Adheres strictly to Rule #9: No emojis, no random images, no fake icons.
/// Displays a clean, neutral, warm cafe surface ready to receive real product images.
class ProductImagePlaceholder extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double borderRadius;

  const ProductImagePlaceholder({
    super.key,
    this.imageUrl,
    this.size = 64.0,
    this.borderRadius = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildNeutralSurface(),
        ),
      );
    }

    return _buildNeutralSurface();
  }

  Widget _buildNeutralSurface() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF4EFEA), // Neutral warm cafe surface
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.0),
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.45, size * 0.45),
          painter: _SubtleInsigniaPainter(color: AppTheme.accentCaramel.withValues(alpha: 0.35)),
        ),
      ),
    );
  }
}

/// A subtle, minimalist, architectural line-art insignia representing Coffee Katta
class _SubtleInsigniaPainter extends CustomPainter {
  final Color color;

  const _SubtleInsigniaPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Cup Body Outline
    final cupPath = Path()
      ..moveTo(w * 0.2, h * 0.4)
      ..lineTo(w * 0.8, h * 0.4)
      ..lineTo(w * 0.72, h * 0.85)
      ..quadraticBezierTo(w * 0.7, h * 0.95, w * 0.5, h * 0.95)
      ..quadraticBezierTo(w * 0.3, h * 0.95, w * 0.28, h * 0.85)
      ..close();
    canvas.drawPath(cupPath, paint);

    // Cup Handle
    final handlePath = Path()
      ..moveTo(w * 0.78, h * 0.48)
      ..quadraticBezierTo(w * 0.98, h * 0.54, w * 0.74, h * 0.74);
    canvas.drawPath(handlePath, paint);

    // Subtle Steam Wave 1
    final steam1 = Path()
      ..moveTo(w * 0.42, h * 0.3)
      ..quadraticBezierTo(w * 0.36, h * 0.18, w * 0.42, h * 0.08);
    canvas.drawPath(steam1, paint);

    // Subtle Steam Wave 2
    final steam2 = Path()
      ..moveTo(w * 0.58, h * 0.3)
      ..quadraticBezierTo(w * 0.64, h * 0.18, w * 0.58, h * 0.08);
    canvas.drawPath(steam2, paint);
  }

  @override
  bool shouldRepaint(covariant _SubtleInsigniaPainter oldDelegate) => oldDelegate.color != color;
}
