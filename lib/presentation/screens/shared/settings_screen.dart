import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/branch_provider.dart';
import '../../providers/active_branch_provider.dart';
import '../../../core/app_theme.dart';
import '../../../services/branch_service.dart';
import '../../../domain/models/branch_model.dart';
import 'printer_settings_screen.dart';
import '../admin/branches/branch_management_screen.dart';
import '../../widgets/global/editorial_background.dart';
import '../../widgets/global/coffee_katta_brand_badge.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@ldma.in',
      query: 'subject=Support Request - Coffee Katta POS',
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch email client';
      }
    } catch (e) {
      // Fallback or error logging
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final branchAsync = ref.watch(branchProvider);
    final userAsync = ref.watch(userModelProvider);
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),

                  // Coffee Katta Branding with Bearded Man Mascot
                  CoffeeKattaBrandBadge(showTagline: !isCompact),

                  // System Badge on tablet / desktop
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
                          Icon(Icons.tune_rounded, size: 13, color: Colors.white70),
                          SizedBox(width: 6),
                          Text(
                            'SYSTEM PREFERENCES',
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

                  // Screen Mode Badge (Zero Overflow on narrow devices)
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
                      'SETTINGS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ════════════════════════════════════════════════════════
            // 2. SETTINGS CONTENT
            // ════════════════════════════════════════════════════════
            Expanded(
              child: EditorialBackground(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 16 : 24,
                        vertical: 16,
                      ),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildSectionHeader('APPEARANCE'),
                        _buildAestheticCard([
                          _buildToggleRow(
                            context,
                            title: 'Dark Mode',
                            subtitle: 'Sleek dark theme for night shifts',
                            value: themeMode == ThemeMode.dark,
                            icon: Icons.dark_mode_rounded,
                            onChanged: (val) => ref.read(themeProvider.notifier).toggleTheme(val),
                            isLast: true,
                          ),
                        ]),

                        _buildSectionHeader('BRANCH INFORMATION'),
                        branchAsync.when(
                          data: (branch) => _buildAestheticCard([
                            _buildSimpleTile(Icons.storefront_rounded, 'Branch Name', branch.branchName),
                            _buildSimpleTile(Icons.location_on_rounded, 'Location', branch.location),
                            _buildSimpleTile(Icons.map_rounded, 'Address', branch.address),
                            if (branch.instagramId.isNotEmpty)
                              _buildSimpleTile(Icons.camera_alt_outlined, 'Instagram', '@${branch.instagramId}'),
                            if (branch.reviewQrUrl.isNotEmpty)
                              _buildSimpleTile(Icons.qr_code_2_rounded, 'Review Link', branch.reviewQrUrl),

                            userAsync.when(
                              data: (user) {
                                if (user == null) return const SizedBox.shrink();

                                final isAuthorized = user.isAdmin || user.isCashier;
                                if (!isAuthorized) return const SizedBox.shrink();

                                return Column(
                                  children: [
                                    _buildActionTile(
                                      context,
                                      icon: Icons.swap_horiz_rounded,
                                      title: 'Switch Branch',
                                      subtitle: 'Change which branch you are managing',
                                      onTap: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            title: const Text(
                                              'SWITCH BRANCH?',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF382012),
                                                fontSize: 17,
                                              ),
                                            ),
                                            content: const Text(
                                              'You will be returned to the branch selection screen.',
                                              style: TextStyle(color: Color(0xFF6B5E55), fontSize: 13.5),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('CANCEL', style: TextStyle(color: Color(0xFF7A6B60), fontWeight: FontWeight.bold)),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF382012),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('SWITCH', style: TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await ref.read(activeBranchProvider.notifier).clearBranch();
                                        }
                                      },
                                    ),
                                    if (user.isAdmin) ...[
                                      _buildActionTile(
                                        context,
                                        icon: Icons.store_mall_directory_rounded,
                                        title: 'All Branches Management',
                                        subtitle: 'Add, edit, or configure multi-store branches',
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const BranchManagementScreen()),
                                        ),
                                      ),
                                      _buildActionTile(
                                        context,
                                        icon: Icons.edit_note_rounded,
                                        title: 'Edit Current Branch Details',
                                        subtitle: 'Update address, IG, and review links',
                                        onTap: () => _showEditBranchDialog(context, ref, branch),
                                        isLast: true,
                                      ),
                                    ],
                                  ],
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          ]),
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(color: AppTheme.primaryCoffee),
                            ),
                          ),
                          error: (e, s) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Failed to load branch data: $e', style: const TextStyle(color: Colors.red)),
                            ),
                          ),
                        ),

                        _buildSectionHeader('HARDWARE & PRINTING'),
                        _buildAestheticCard([
                          _buildActionTile(
                            context,
                            icon: Icons.print_rounded,
                            title: 'Thermal Printer Engine',
                            subtitle: 'Configure ESC/POS receipt, KOT, and hardware options',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PrinterSettingsScreen()),
                            ),
                            isLast: true,
                          ),
                        ]),

                        _buildSectionHeader('SUPPORT & HELP'),
                        _buildAestheticCard([
                          _buildActionTile(
                            context,
                            icon: Icons.help_center_rounded,
                            title: 'Contact Technical Support',
                            subtitle: 'support@ldma.in',
                            onTap: _launchEmail,
                          ),
                          _buildActionTile(
                            context,
                            icon: Icons.info_rounded,
                            title: 'App Version',
                            subtitle: '2.0.0 (Build 2026.09.12)',
                            onTap: () {},
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF287A55).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF287A55).withValues(alpha: 0.25)),
                              ),
                              child: const Text(
                                'STABLE',
                                style: TextStyle(
                                  color: Color(0xFF287A55),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            isLast: true,
                          ),
                        ]),

                        const SizedBox(height: 48),

                        // Rich Brand Footer
                        Center(
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/branding/splash_logo.png',
                                height: 44,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.local_cafe_rounded,
                                  size: 40,
                                  color: Color(0xFF5A3825),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Coffee Katta POS',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF382012),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Crafted for Authentic Cafe Operations • LDMA Tech',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B5E55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF5A3825),
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildAestheticCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Function(bool) onChanged,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF382012).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF382012), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF29231F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B5E55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                activeColor: const Color(0xFF287A55),
                activeTrackColor: const Color(0xFF287A55).withValues(alpha: 0.35),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 64, color: Color(0xFFE8E1D8)),
      ],
    );
  }

  Widget _buildSimpleTile(IconData icon, String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF382012).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF382012)),
          ),
          title: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5A3825),
              letterSpacing: 0.5,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF29231F),
                fontSize: 14.5,
              ),
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 64, color: Color(0xFFE8E1D8)),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool isLast = false,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF382012).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF382012), size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF29231F),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B5E55),
              ),
            ),
          ),
          trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF8C7B70)),
          onTap: onTap,
        ),
        if (!isLast) const Divider(height: 1, indent: 64, color: Color(0xFFE8E1D8)),
      ],
    );
  }

  void _showEditBranchDialog(BuildContext context, WidgetRef ref, BranchModel branch) {
    final nameController = TextEditingController(text: branch.branchName);
    final locationController = TextEditingController(text: branch.location);
    final addressController = TextEditingController(text: branch.address);
    final phoneController = TextEditingController(text: branch.phone);
    final instagramController = TextEditingController(text: branch.instagramId);
    final reviewQrController = TextEditingController(text: branch.reviewQrUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'EDIT BRANCH INFO',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF382012), fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                readOnly: true,
                style: const TextStyle(color: Color(0xFF29231F), fontWeight: FontWeight.bold, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Branch Name',
                  labelStyle: const TextStyle(color: Color(0xFF5A3825), fontWeight: FontWeight.bold),
                  helperText: 'Branch name cannot be changed',
                  helperStyle: const TextStyle(color: Color(0xFF6B5E55)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: const Color(0xFFF7F4EF),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                style: const TextStyle(color: Color(0xFF29231F), fontWeight: FontWeight.bold, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Short Location',
                  labelStyle: const TextStyle(color: Color(0xFF5A3825), fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                maxLines: 2,
                style: const TextStyle(color: Color(0xFF29231F), fontWeight: FontWeight.bold, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Full Address',
                  labelStyle: const TextStyle(color: Color(0xFF5A3825), fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Color(0xFF29231F), fontWeight: FontWeight.bold, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Phone',
                  labelStyle: const TextStyle(color: Color(0xFF5A3825), fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instagramController,
                style: const TextStyle(color: Color(0xFF29231F), fontWeight: FontWeight.bold, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Instagram ID (@handle)',
                  labelStyle: const TextStyle(color: Color(0xFF5A3825), fontWeight: FontWeight.bold),
                  prefixText: '@',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reviewQrController,
                style: const TextStyle(color: Color(0xFF29231F), fontWeight: FontWeight.bold, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Google Review Link',
                  labelStyle: const TextStyle(color: Color(0xFF5A3825), fontWeight: FontWeight.bold),
                  helperText: 'Paste the direct Google Maps review URL',
                  helperStyle: const TextStyle(color: Color(0xFF6B5E55)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF7A6B60), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF287A55),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final updatedBranch = branch.copyWith(
                branchName: nameController.text.trim(),
                location: locationController.text.trim(),
                address: addressController.text.trim(),
                phone: phoneController.text.trim(),
                instagramId: instagramController.text.trim().replaceAll('@', ''),
                reviewQrUrl: reviewQrController.text.trim(),
              );

              try {
                await ref.read(branchServiceProvider).updateBranchDetails(updatedBranch);
                ref.invalidate(branchProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Branch details updated successfully'),
                      backgroundColor: Color(0xFF287A55),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
