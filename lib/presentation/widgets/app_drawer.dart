import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../core/app_theme.dart';
import '../screens/shared/home_screen.dart';
import '../screens/shared/settings_screen.dart';
import '../screens/shared/kot_screen.dart';
import '../providers/branch_provider.dart';
import '../providers/active_branch_provider.dart';
import '../screens/admin/users/user_management_screen.dart';
import '../screens/admin/menu/menu_management_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final userModel = ref.watch(userModelProvider).value;
    final branchAsync = ref.watch(branchProvider);
    final activeRole = ref.watch(activeUserRoleProvider);

    final isAdmin = activeRole == 'admin';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final drawerBg = isDark ? const Color(0xFF221711) : Colors.white;
    final sectionHeaderColor = isDark ? const Color(0xFFD4A373) : const Color(0xFF8C5835);
    final iconColor = isDark ? const Color(0xFFD4A373) : const Color(0xFF5A3825);
    final textColor = isDark ? Colors.white : const Color(0xFF29231F);
    final dividerColor = isDark ? Colors.white12 : const Color(0xFFE8E1D8);

    return Drawer(
      backgroundColor: drawerBg,
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
                      style: GoogleFonts.epilogue(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    loading: () => Text('Loading...', style: GoogleFonts.epilogue(color: Colors.white70)),
                    error: (_, __) => Text('Coffee Katta POS', style: GoogleFonts.epilogue(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  // User Name
                  Text(
                    userModel?.name ?? user?.displayName ?? 'User',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.epilogue(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                  // Email
                  Text(
                    user?.email ?? '',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.epilogue(fontSize: 11, color: Colors.white54),
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
                      style: GoogleFonts.epilogue(
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
                // Tables link
                ListTile(
                  leading: Icon(Icons.table_restaurant_rounded, color: iconColor),
                  title: Text(
                    'Tables',
                    style: GoogleFonts.epilogue(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
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
                  leading: Icon(Icons.receipt_long_rounded, color: iconColor),
                  title: Text(
                    'Live KOTs',
                    style: GoogleFonts.epilogue(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
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
                  Divider(height: 1, color: dividerColor),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
                    child: Text(
                      'MANAGEMENT',
                      style: GoogleFonts.epilogue(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: sectionHeaderColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.people_outline_rounded, color: iconColor),
                    title: Text(
                      'User Management',
                      style: GoogleFonts.epilogue(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen()));
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.restaurant_menu_rounded, color: iconColor),
                    title: Text(
                      'Menu Management',
                      style: GoogleFonts.epilogue(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MenuManagementScreen()));
                    },
                  ),
                ],

                Divider(height: 1, color: dividerColor),
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
                  child: Text(
                    'PREFERENCES',
                    style: GoogleFonts.epilogue(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: sectionHeaderColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // Settings (Hardware, Printers, Appearance & Branch config)
                ListTile(
                  leading: Icon(Icons.settings_outlined, color: iconColor),
                  title: Text(
                    'Settings',
                    style: GoogleFonts.epilogue(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
