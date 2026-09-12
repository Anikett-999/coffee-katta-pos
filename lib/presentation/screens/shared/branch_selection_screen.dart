import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/active_branch_provider.dart';
import '../../providers/branch_provider.dart';
import '../../../domain/models/user_model.dart';
import '../../../domain/models/branch_model.dart';

import '../../widgets/global/editorial_background.dart';

class BranchSelectionScreen extends ConsumerWidget {
  const BranchSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userModelAsync = ref.watch(userModelProvider);
    final allBranchesAsync = ref.watch(allBranchesProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 720;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EF),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ════════════════════════════════════════════════════════
            // 1. BRANDED TOP HEADER (#382012 Deep Espresso)
            // ════════════════════════════════════════════════════════
            Container(
              height: 62,
              color: const Color(0xFF382012),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  // Coffee Katta Branding
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_cafe_rounded, color: Color(0xFFF7F4EF), size: 22),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coffee Katta',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                          if (!isCompact)
                            const Text(
                              'GOOD FOOD • GREAT VIBES',
                              style: TextStyle(
                                color: Color(0xFFD4A373),
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  if (!isCompact) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      width: 1,
                      height: 26,
                      color: Colors.white24,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront_rounded, size: 13, color: Colors.white70),
                          SizedBox(width: 6),
                          Text(
                            'BRANCH CONSOLE ACCESS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Screen Mode Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : 10,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB77945),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'BRANCH SELECT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Logout Action
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
                    tooltip: 'Logout',
                    onPressed: () => ref.read(authServiceProvider).logout(),
                  ),
                ],
              ),
            ),

            // ════════════════════════════════════════════════════════
            // 2. MAIN SELECTION CONTENT
            // ════════════════════════════════════════════════════════
            Expanded(
              child: EditorialBackground(
                child: userModelAsync.when(
                  data: (user) {
                    if (user == null) return _buildNoAccess(ref);

                    // Defense Guard: Waiters and single-branch cashiers are strictly locked to assigned branch
                    if (user.isWaiter || (user.isCashier && user.branchIds.length <= 1)) {
                      if (user.branchIds.isNotEmpty) {
                        final assigned = user.branchIds.first;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          ref.read(activeBranchProvider.notifier).setBranch(assigned);
                        });
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF5A3825)));
                      } else {
                        return _buildNoAccess(ref, message: 'No branch assigned to your account.\nPlease contact your administrator.');
                      }
                    }

                    // Show first-time welcome dialog
                    if (user.lastLogin == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _showFirstLoginDialog(context);
                      });
                    }

                    // Admins see ALL branches from DB
                    if (user.isAdmin) {
                      return allBranchesAsync.when(
                        data: (allBranches) {
                          if (allBranches.isEmpty) return _buildNoAccess(ref);
                          return _buildBranchList(context, ref, user, allBranches, isCompact);
                        },
                        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF5A3825))),
                        error: (e, _) => Center(child: Text('Error loading branches: $e')),
                      );
                    }

                    // Non-admins: show only their assigned branches
                    return allBranchesAsync.when(
                      data: (allBranches) {
                        final assignedBranches = allBranches
                            .where((b) => user.branchIds.contains(b.branchId))
                            .toList();
                        if (assignedBranches.isEmpty) return _buildNoAccess(ref);
                        return _buildBranchList(context, ref, user, assignedBranches, isCompact);
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF5A3825))),
                      error: (e, _) => Center(child: Text('Error loading branches: $e')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF5A3825))),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchList(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    List<BranchModel> branches,
    bool isCompact,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),
              Text(
                'Welcome, ${user.name}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF382012),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select your active operating branch to launch POS console',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B5E55),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: branches.length,
                  itemBuilder: (context, index) {
                    return _BranchCard(branch: branches[index], userRole: user.role);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFirstLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Welcome to Coffee Katta',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF382012), fontSize: 18),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your account has been successfully configured and activated.',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF29231F)),
            ),
            SizedBox(height: 12),
            Text(
              'Important Security Notice:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5A3825), fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'For your security, please use the "Forgot Password" option to set your personalized confidential password.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF6B5E55), height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF287A55),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('UNDERSTOOD', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAccess(WidgetRef ref, {String? message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 40, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 20),
            Text(
              message ?? 'No access assigned.\nPlease contact your administrator.',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.4,
                color: Color(0xFF29231F),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(authServiceProvider).logout(),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF382012),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchCard extends ConsumerWidget {
  final BranchModel branch;
  final String userRole;
  const _BranchCard({required this.branch, required this.userRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await ref.read(activeBranchProvider.notifier).setBranch(branch.branchId);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF382012).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.storefront_rounded, color: Color(0xFF382012), size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.branchName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                            color: Color(0xFF29231F),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Branch ID: ${branch.branchId} • ${branch.location}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B5E55),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: _getRoleColor(userRole).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _getRoleColor(userRole).withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            userRole.toUpperCase(),
                            style: TextStyle(
                              color: _getRoleColor(userRole),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF8C7B70)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const Color(0xFF5A3825); // Deep Brown
      case 'cashier':
        return const Color(0xFFB77945); // Caramel
      case 'waiter':
        return const Color(0xFF287A55); // Forest Green
      default:
        return const Color(0xFF6B5E55);
    }
  }
}
