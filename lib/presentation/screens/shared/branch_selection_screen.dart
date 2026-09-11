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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: EditorialBackground(
        child: SafeArea(
          child: userModelAsync.when(
            data: (user) {
              if (user == null) return _buildNoAccess(ref);

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
                    return _buildBranchList(context, ref, user, allBranches);
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
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
                  return _buildBranchList(context, ref, user, assignedBranches);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading branches: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
      ),
    );
  }

  Widget _buildBranchList(BuildContext context, WidgetRef ref, UserModel user, List<BranchModel> branches) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          Text(
            'Welcome, ${user.name}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.maroon,
              letterSpacing: -1,
            ),
          ),
          const Text(
            'Please select a branch to continue',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              itemCount: branches.length,
              itemBuilder: (context, index) {
                return _BranchCard(branch: branches[index], userRole: user.role);
              },
            ),
          ),
          TextButton.icon(
            onPressed: () => ref.read(authServiceProvider).logout(),
            icon: const Icon(Icons.logout, color: AppTheme.maroon),
            label: const Text('Logout', style: TextStyle(color: AppTheme.maroon)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showFirstLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Welcome to Coffee Katta'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your account has been successfully created.'),
            SizedBox(height: 12),
            Text('Important Note:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.maroon)),
            SizedBox(height: 4),
            Text('For your security, please use the "Forgot Password" link on the login screen to set your own password.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('UNDERSTOOD'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAccess(WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 20),
          const Text('No access assigned.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('Please contact your administrator.'),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => ref.read(authServiceProvider).logout(),
            child: const Text('Logout'),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black12,
        child: InkWell(
        onTap: () async {
            // Use the notifier to save the selection persistently
            await ref.read(activeBranchProvider.notifier).setBranch(branch.branchId);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.maroon.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront, color: AppTheme.maroon, size: 30),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.branchName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        branch.branchId,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getRoleColor(userRole).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          userRole.toUpperCase(),
                          style: TextStyle(
                            color: _getRoleColor(userRole),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return Colors.purple;
      case 'cashier': return Colors.green;
      case 'waiter': return Colors.blue;
      default: return Colors.grey;
    }
  }
}
