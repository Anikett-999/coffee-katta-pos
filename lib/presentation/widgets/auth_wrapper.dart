import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/active_branch_provider.dart';
import '../screens/shared/login_screen.dart';
import '../screens/shared/branch_selection_screen.dart';
import '../screens/shared/home_screen.dart';
import '../screens/shared/account_disabled_screen.dart';
import '../screens/shared/unassigned_branch_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userModelAsync = ref.watch(userModelProvider);
    final activeBranchId = ref.watch(activeBranchIdProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }

        return userModelAsync.when(
          data: (userModel) {
            if (userModel == null) {
              // User exists in Auth but not in Firestore yet (or deleted)
              return const LoginScreen();
            }

            if (!userModel.isActive) {
              return const AccountDisabledScreen();
            }

            // 1. Waiters & Single-Branch Staff: strictly locked to assigned branch.
            // Never show branch picker. Directly route to assigned branch workspace.
            if (userModel.isWaiter || (userModel.isCashier && userModel.branchIds.length <= 1)) {
              final assignedBranch = userModel.branchIds.isNotEmpty ? userModel.branchIds.first : null;
              if (assignedBranch == null || assignedBranch.isEmpty) {
                return const UnassignedBranchScreen();
              }

              // Auto-sync active branch if not set or mismatched
              if (activeBranchId != assignedBranch) {
                Future.microtask(() {
                  ref.read(activeBranchProvider.notifier).setBranch(assignedBranch);
                });
              }

              return const HomeScreen();
            }

            // 2. Admins & Multi-Branch Managers:
            // First time login (or no active branch chosen): show branch picker.
            // Once chosen, activeBranchId is set and saved, so they land directly on HomeScreen.
            if (activeBranchId == null || !userModel.hasAccessToBranch(activeBranchId)) {
              return const BranchSelectionScreen();
            }

            return const HomeScreen();
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (err, stack) => Scaffold(
            body: Center(child: Text('Error loading profile: $err')),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        body: Center(child: Text('Auth error: $err')),
      ),
    );
  }
}
