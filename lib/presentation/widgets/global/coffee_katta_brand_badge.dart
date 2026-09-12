import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

/// Standard Coffee Katta Brand Header Logo Component.
/// Uses the official Beardman Mascot avatar (`assets/branding/app_icon.png`)
/// and the Coffee Katta brand typography.
class CoffeeKattaBrandBadge extends StatelessWidget {
  final double avatarSize;
  final bool showText;
  final bool showTagline;
  final Color textColor;
  final Color taglineColor;

  const CoffeeKattaBrandBadge({
    super.key,
    this.avatarSize = 36,
    this.showText = true,
    this.showTagline = true,
    this.textColor = Colors.white,
    this.taglineColor = AppTheme.warmAmber,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Official Bearded Man Mascot Avatar in Circle
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/branding/app_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person_rounded,
                color: Color(0xFF5A3825),
                size: 20,
              ),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Coffee Katta',
                style: TextStyle(
                  color: textColor,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  height: 1.15,
                ),
              ),
              if (showTagline)
                Text(
                  'GOOD FOOD • GREAT VIBES',
                  style: TextStyle(
                    color: taglineColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
