import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/global/editorial_background.dart';

/// Screen displayed when a staff member (waiter/cashier) is active
/// but has not yet been assigned to a physical branch by an administrator.
class UnassignedBranchScreen extends ConsumerWidget {
  const UnassignedBranchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userModel = ref.watch(userModelProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EF),
      body: EditorialBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F4EF),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 38,
                          color: AppTheme.primaryCoffee,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Branch Assigned',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Hello ${userModel?.name ?? "Staff"}, your account is active, but you have not yet been assigned to a physical Coffee Katta branch.\n\nPlease request your administrator to assign your branch in User Management.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(userModelProvider);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'CHECK AGAIN',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryCoffee,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: () => ref.read(authServiceProvider).logout(),
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textDark,
                          side: const BorderSide(color: Color(0xFFE8E1D8)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
