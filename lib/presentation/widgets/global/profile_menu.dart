import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../screens/shared/profile_screen.dart';
import '../../../core/app_theme.dart';

class ProfileMenu extends ConsumerWidget {
  final bool isDarkHeader;
  const ProfileMenu({super.key, this.isDarkHeader = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderColor = isDarkHeader ? Colors.white24 : AppTheme.maroon.withOpacity(0.2);
    final bgColor = isDarkHeader ? Colors.white.withValues(alpha: 0.12) : AppTheme.maroon.withOpacity(0.05);
    final iconColor = isDarkHeader ? Colors.white : AppTheme.maroon;

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
        },
        child: Hero(
          tag: 'profile-avatar',
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: bgColor,
              child: Icon(Icons.account_circle_rounded, color: iconColor, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
