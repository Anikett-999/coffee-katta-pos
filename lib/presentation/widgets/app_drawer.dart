import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../core/app_theme.dart';
import '../screens/shared/home_screen.dart';
import '../screens/shared/profile_screen.dart';
import '../screens/shared/settings_screen.dart';
import '../screens/shared/printer_settings_screen.dart';
import '../screens/shared/kot_screen.dart';
import './global/confirmation_dialog.dart';
import '../providers/branch_provider.dart';
import '../providers/active_branch_provider.dart';
import '../screens/admin/users/user_management_screen.dart';
import '../screens/admin/branches/branch_management_screen.dart';
import '../screens/admin/menu/menu_management_screen.dart';


// We rely on the authServiceProvider from auth_provider.dart via the build method's ref

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final userModel = ref.watch(userModelProvider).value;
    final branchAsync = ref.watch(branchProvider);
    final activeRole = ref.watch(activeUserRoleProvider);

    final isAdmin = activeRole == 'admin';

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Drawer Header - Custom Centered Design
          Container(
            width: double.infinity,
            color: AppTheme.maroon,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/branding/app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.coffee_rounded, color: AppTheme.warmAmber, size: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Branch Name
                  branchAsync.when(
                    data: (branch) => Text(
                      branch.branchName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    loading: () => const Text('Loading...', style: TextStyle(color: Colors.white70)),
                    error: (_, __) => const Text('Coffee Katta POS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  // User Name
                  Text(
                    userModel?.name ?? user?.displayName ?? 'User',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  // Email
                  Text(
                    user?.email ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Scrollable Items List
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Home link - Context Sensitive
                ListTile(
                  leading: Icon(isAdmin ? Icons.home_rounded : Icons.table_bar, color: AppTheme.maroon),
                  title: Text(isAdmin ? 'Home' : 'Table Status', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                ),

                // Operational Tools (Hidden for Admins)
                if (!isAdmin) ...[
                  ListTile(
                    leading: const Icon(Icons.receipt_long, color: AppTheme.maroon),
                    title: const Text('Live KOTs', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const KOTScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.restaurant_menu, color: AppTheme.maroon),
                    title: const Text('Menu Availability', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MenuManagementScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.print, color: AppTheme.maroon),
                    title: const Text('Printer Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PrinterSettingsScreen()),
                      );
                    },
                  ),
                ],

                // Admin Management Tools (Admins only)
                if (isAdmin) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
                    child: Text('MANAGEMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_outline, color: AppTheme.maroon),
                    title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.store_mall_directory_outlined, color: AppTheme.maroon),
                    title: const Text('My Branches', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const BranchManagementScreen()));
                    },
                  ),
                ],

                // Shared Links
                ListTile(
                  leading: const Icon(Icons.person, color: AppTheme.maroon),
                  title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.settings, color: AppTheme.maroon),
                  title: const Text('App Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Logout with Confirmation (Pinned to bottom)
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.maroon),
            title: const Text('Logout', style: TextStyle(color: AppTheme.maroon, fontWeight: FontWeight.bold)),
            onTap: () {
              ConfirmationDialog.show(
                context: context,
                title: 'Logout',
                message: 'Are you sure you want to log out of the session?',
                confirmLabel: 'Logout',
                onConfirm: () async {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  await ref.read(authServiceProvider).logout();
                },
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
