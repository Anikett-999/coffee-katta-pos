import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../screens/shared/profile_screen.dart';
import '../../../core/app_theme.dart';

class ProfileMenu extends ConsumerWidget {
  final bool isDarkHeader;
  const ProfileMenu({super.key, this.isDarkHeader = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          child: Icon(
            Icons.account_circle_rounded,
            color: iconColor,
            size: 28,
          ),
        ),
      ),
    );
  }
}
