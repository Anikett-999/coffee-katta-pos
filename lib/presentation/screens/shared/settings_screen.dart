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
import '../../widgets/global/editorial_background.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('APP SETTINGS', 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppTheme.maroon,
        centerTitle: true,
      ),
      body: EditorialBackground(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              title: const Text('SWITCH BRANCH?'),
                              content: const Text('You will be returned to the selection screen.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.maroon, foregroundColor: Colors.white),
                                  onPressed: () => Navigator.pop(context, true), 
                                  child: const Text('SWITCH'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref.read(activeBranchProvider.notifier).clearBranch();
                          }
                        },
                      ),
                      if (user.isAdmin)
                        _buildActionTile(
                          context, 
                          icon: Icons.edit_note_rounded, 
                          title: 'Edit Branch Details', 
                          subtitle: 'Update address, IG, and review links', 
                          onTap: () => _showEditBranchDialog(context, ref, branch),
                          isLast: true,
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ]),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppTheme.maroon))),
            error: (e, s) => Center(child: Text('Failed to load branch data: $e', style: const TextStyle(color: Colors.red))),
          ),
          
          _buildSectionHeader('HARDWARE & PRINTING'),
          _buildAestheticCard([
            _buildActionTile(
              context,
              icon: Icons.print_rounded,
              title: 'Printer Settings',
              subtitle: 'Configure thermal printers & KOTs',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PrinterSettingsScreen()),
              ),
              isLast: true,
            ),
          ]),

          _buildSectionHeader('SUPPORT & HELP'),
          _buildAestheticCard([
            _buildActionTile(
              context,
              icon: Icons.help_center_rounded,
              title: 'Contact Support',
              subtitle: 'support@ldma.in',
              onTap: _launchEmail,
            ),
            _buildActionTile(
              context,
              icon: Icons.info_rounded,
              title: 'App Version',
              subtitle: '2.0.0 (Build 2024.10.01)',
              onTap: () {},
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('STABLE', style: TextStyle(color: AppTheme.successGreen, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              isLast: true,
            ),
          ]),
          const SizedBox(height: 60),
          Center(
            child: Opacity(
              opacity: 0.5,
              child: Column(
                children: [
                  Image.asset('assets/branding/splash_logo.png', height: 40),
                  const SizedBox(height: 8),
                  const Text('Coffee Katta POS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const Text('Powered by LDMA Technologies', style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    ),
  );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 32, 4, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.maroon,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 2.0,
        ),
      ),
    );
  }

  Widget _buildAestheticCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.maroon.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.maroon, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                activeColor: AppTheme.maroon,
                activeTrackColor: AppTheme.maroon.withOpacity(0.3),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, indent: 72, color: Colors.grey.shade100),
      ],
    );
  }

  Widget _buildSimpleTile(IconData icon, String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Icon(icon, size: 22, color: AppTheme.maroon.withOpacity(0.7)),
          title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15)),
        ),
        if (!isLast) Divider(height: 1, indent: 72, color: Colors.grey.shade100),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.maroon.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.maroon, size: 20),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          onTap: onTap,
        ),
        if (!isLast) Divider(height: 1, indent: 72, color: Colors.grey.shade100),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('EDIT BRANCH INFO', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.maroon)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Branch Name', 
                  helperText: 'Branch name cannot be changed',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: InputDecoration(labelText: 'Short Location', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: InputDecoration(labelText: 'Full Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Phone', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instagramController,
                decoration: InputDecoration(
                  labelText: 'Instagram ID (@handle)', 
                  prefixText: '@',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reviewQrController,
                decoration: InputDecoration(
                  labelText: 'Google Review Link', 
                  helperText: 'Paste the direct Google Maps review URL',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.maroon, foregroundColor: Colors.white),
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
                // Invalidate the provider to refresh the UI
                ref.invalidate(branchProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Branch updated successfully'), backgroundColor: AppTheme.successGreen),
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
            child: const Text('SAVE CHANGES'),
          ),
        ],
      ),
    );
  }
}
