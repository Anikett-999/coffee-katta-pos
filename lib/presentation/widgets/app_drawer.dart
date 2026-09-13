import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../core/app_theme.dart';
import '../screens/shared/home_screen.dart';
import '../screens/shared/profile_screen.dart';
import '../screens/shared/settings_screen.dart';
import '../screens/shared/kot_screen.dart';
import './global/confirmation_dialog.dart';
import '../providers/branch_provider.dart';
import '../providers/active_branch_provider.dart';
import '../screens/admin/users/user_management_screen.dart';
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
            color: const Color(0xFF382012),
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
                  const SizedBox(height: 6),
                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                    ),
                    child: Text(
                      (userModel?.role ?? activeRole ?? 'STAFF').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
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
                // Home / Floor link
                ListTile(
                  leading: const Icon(Icons.table_bar_rounded, color: Color(0xFF5A3825)),
                  title: Text(isAdmin ? 'Floor Plan & Tables' : 'Table Status', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                ),

                // Live KOTs (Staff & Cashier operational tool)
                ListTile(
                  leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF5A3825)),
                  title: const Text('Live KOTs', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const KOTScreen()),
                    );
                  },
                ),

                // Admin Management Suite
                if (isAdmin) ...[
                  const Divider(height: 1, color: Color(0xFFE8E1D8)),
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 12, bottom: 4),
                    child: Text(
                      'MANAGEMENT',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF5A3825), letterSpacing: 1.2),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_outline_rounded, color: Color(0xFF5A3825)),
                    title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF5A3825)),
                    title: const Text('Menu Management', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MenuManagementScreen()));
                    },
                  ),
                ],

                const Divider(height: 1, color: Color(0xFFE8E1D8)),
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 12, bottom: 4),
                  child: Text(
                    'PREFERENCES',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF5A3825), letterSpacing: 1.2),
                  ),
                ),

                // My Profile
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF5A3825)),
                  title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                ),

                // Settings (Hardware, Printers, Appearance & Branch config)
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: Color(0xFF5A3825)),
                  title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
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

          const Divider(height: 1, color: Color(0xFFE8E1D8)),

          // Logout with Confirmation (Pinned to bottom)
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFC0392B)),
            title: const Text('Logout', style: TextStyle(color: Color(0xFFC0392B), fontWeight: FontWeight.bold)),
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
