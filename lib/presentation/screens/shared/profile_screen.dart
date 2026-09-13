import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/active_branch_provider.dart';
import '../../providers/branch_provider.dart';
import '../../widgets/global/base_widgets.dart';
import '../../../core/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../domain/models/user_model.dart';
import '../../../domain/models/branch_model.dart';
import 'settings_screen.dart';
import '../../widgets/global/editorial_background.dart';
import '../../widgets/global/coffee_katta_brand_badge.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final userModelAsync = ref.watch(userModelProvider);
    final activeBranchId = ref.watch(activeBranchIdProvider);
    final branchAsync = ref.watch(branchProvider);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF382012),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: CoffeeKattaBrandBadge(),
                  ),
                  if (MediaQuery.of(context).size.width >= 600) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_rounded, color: AppTheme.warmAmber, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'MY PROFILE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
                    tooltip: 'Settings',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: EditorialBackground(
        child: userModelAsync.when(
          data: (user) {
            if (user == null) {
              return const EmptyStateWidget(
                title: 'Profile Missing', 
                message: 'We couldn\'t find your profile details.',
                icon: Icons.person_off_rounded,
              );
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Header Profile Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Hero(
                              tag: 'profile-avatar',
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.maroon.withOpacity(0.2), width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: AppTheme.maroon.withOpacity(0.05),
                                  child: const Icon(Icons.person_rounded, size: 60, color: AppTheme.maroon),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppTheme.successGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BUSINESS BRANCH',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.maroon,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildBranchSection(context, ref, user, branchAsync, activeBranchId),

                        const SizedBox(height: 32),
                        const Text(
                          'ACCOUNT INFORMATION',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.maroon,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard([
                          _buildInfoRow(context, Icons.badge_outlined, 'Employee ID', user.userId.substring(0, 8).toUpperCase()),
                          _buildInfoRow(context, Icons.calendar_today_outlined, 'Account Status', user.isActive ? 'Active Member' : 'Suspended'),
                        ]),
                        
                        const SizedBox(height: 32),
                        const Text(
                          'SESSION MANAGEMENT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.maroon,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildActionCard([
                          _buildActionRow(
                            context, 
                            Icons.logout_rounded, 
                            'Sign Out', 
                            'End your current active session',
                            () async {
                              final confirm = await _showLogoutDialog(context);
                              if (confirm == true) {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                                await ref.read(authServiceProvider).logout();
                              }
                            },
                            color: AppTheme.maroon,
                            isLast: true,
                          ),
                        ], isDanger: false),

                        const SizedBox(height: 32),
                        const Text(
                          'DANGER ZONE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.red,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildActionCard([
                          _buildActionRow(
                            context, 
                            Icons.lock_reset_rounded, 
                            'Reset Password', 
                            'Securely change your account password',
                            () => _showPasswordResetDialog(context, authService, user.email),
                            color: Colors.blue.shade700,
                          ),
                          _buildActionRow(
                            context, 
                            Icons.delete_outline_rounded, 
                            'Cleanup Request', 
                            'Request permanent data removal',
                            () => _showDeleteAccountDialog(context, ref, authService),
                            color: Colors.red.shade700,
                            isLast: true,
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const LoadingIndicator(message: 'Loading your profile...'),
          error: (err, _) => ErrorStateWidget(error: err.toString()),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildBranchSection(BuildContext context, WidgetRef ref, UserModel user, AsyncValue<BranchModel> branchAsync, String? activeBranchId) {
    // Admin can always switch branches. Non-admin can switch if assigned to more than 1 branch.
    final canSwitch = user.isAdmin || user.branchIds.length > 1;

    return _buildInfoCard([
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.maroon.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.storefront_outlined, color: AppTheme.maroon),
        ),
        title: branchAsync.when(
          data: (branch) => Text(branch.branchName, style: const TextStyle(fontWeight: FontWeight.bold)),
          loading: () => const Text('Loading...', style: TextStyle(fontWeight: FontWeight.bold)),
          error: (_, __) => Text(activeBranchId ?? 'Select Branch', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        subtitle: Text(
          user.role.toUpperCase(),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
        ),
        trailing: canSwitch
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.maroon.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz, color: AppTheme.maroon, size: 18),
                  SizedBox(width: 4),
                  Text('Switch', style: TextStyle(color: AppTheme.maroon, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : null,
        onTap: canSwitch
          ? () async {
              await ref.read(activeBranchProvider.notifier).clearBranch();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            }
          : null,
      ),
    ]);
  }


  Widget _buildActionCard(List<Widget> children, {bool isDanger = true}) {
    return Container(
      decoration: BoxDecoration(
        color: isDanger ? Colors.red.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDanger ? Colors.red.withOpacity(0.1) : Colors.grey.shade100),
        boxShadow: isDanger ? null : [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildActionRow(
    BuildContext context, 
    IconData icon, 
    String title, 
    String subtitle, 
    VoidCallback onTap, 
    {required Color color, bool isLast = false}
  ) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          onTap: onTap,
        ),
        if (!isLast) Divider(height: 1, indent: 70, color: Colors.grey.shade100),
      ],
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to end your current session?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.maroon,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('LOGOUT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPasswordResetDialog(BuildContext context, AuthService auth, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Password?'),
        content: Text('A secure link will be sent to $email.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final error = await auth.sendResetEmail(email);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'Reset link sent! Check your email.'),
                    backgroundColor: error != null ? Colors.red : AppTheme.successGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }, 
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.maroon,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('SEND LINK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref, AuthService auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Request Cleanup?', style: TextStyle(color: Colors.red)),
        content: const Text('This will request the Admin to permanently remove your data and logs from the system. This action cannot be reversed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _showDoubleConfirmationDialog(context, ref, auth);
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('CONTINUE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDoubleConfirmationDialog(BuildContext context, WidgetRef ref, AuthService auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Request'),
        content: const Text('Are you sure you want to notify the Admin to delete your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BACK')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final error = await auth.requestAccountDeletion();
              if (context.mounted) {
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                  );
                } else {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cleanup request sent to Admin successfully.'), 
                      backgroundColor: Colors.black87,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }, 
            child: const Text('SUBMIT REQUEST', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: AppTheme.maroon, size: 22),
      title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
    );
  }
}
