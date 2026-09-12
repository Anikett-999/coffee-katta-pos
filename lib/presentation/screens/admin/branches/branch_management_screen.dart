import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/app_theme.dart';
import '../../../../domain/models/branch_model.dart';
import '../../../../services/branch_service.dart';
import '../../../providers/branch_provider.dart';
import '../../../widgets/global/base_widgets.dart';
import '../../../widgets/global/editorial_background.dart';
import '../../../widgets/global/coffee_katta_brand_badge.dart';

class BranchManagementScreen extends ConsumerWidget {
  const BranchManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(allBranchesProvider);
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
                            'BRANCH MANAGEMENT',
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

                  // Add Branch Action Button
                  ElevatedButton.icon(
                    onPressed: () => _addBranch(context, ref),
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 17),
                    label: Text(
                      isCompact ? 'ADD' : 'ADD BRANCH',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF287A55), // Forest Green CTA
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Screen Badge
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
                      'BRANCHES',
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
            // 2. BRANCH LIST CONTENT
            // ════════════════════════════════════════════════════════
            Expanded(
              child: EditorialBackground(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: branchesAsync.when(
                      data: (branches) {
                        if (branches.isEmpty) {
                          return const EmptyStateWidget(
                            title: 'No Branches Configured',
                            message: 'Database initialization might be incomplete.',
                            icon: Icons.store_mall_directory_outlined,
                          );
                        }

                        return ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 16 : 24,
                            vertical: 18,
                          ),
                          itemCount: branches.length,
                          itemBuilder: (context, index) {
                            final branch = branches[index];
                            return _BranchListItem(branch: branch);
                          },
                        );
                      },
                      loading: () => const LoadingIndicator(message: 'Loading branches...'),
                      error: (err, _) => ErrorStateWidget(error: err.toString()),
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

  void _addBranch(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final instagramController = TextEditingController();
    final reviewQrController = TextEditingController();

    // Auto-generate branch ID based on existing branches
    String newBranchId = 'branch_001';
    final branches = ref.read(allBranchesProvider).valueOrNull ?? [];
    if (branches.isNotEmpty) {
      int maxId = 0;
      for (final b in branches) {
        final idStr = b.branchId.replaceAll(RegExp(r'[^0-9]'), '');
        if (idStr.isNotEmpty) {
          final idNum = int.tryParse(idStr) ?? 0;
          if (idNum > maxId) {
            maxId = idNum;
          }
        }
      }
      newBranchId = 'branch_${(maxId + 1).toString().padLeft(3, '0')}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'ADD NEW BRANCH',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF382012), fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Color(0xFF29231F), fontWeight: FontWeight.bold, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Branch Name',
                  labelStyle: const TextStyle(color: Color(0xFF5A3825), fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                style: const TextStyle(color: Color(0xFF29231F), fontWeight: FontWeight.bold, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Short Location (e.g. Latur)',
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
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a branch name')),
                );
                return;
              }

              final newBranch = BranchModel(
                branchId: newBranchId,
                branchName: nameController.text.trim(),
                location: locationController.text.trim(),
                address: addressController.text.trim(),
                phone: phoneController.text.trim(),
                instagramId: instagramController.text.trim().replaceAll('@', ''),
                reviewQrUrl: reviewQrController.text.trim(),
                isActive: true,
              );

              try {
                await ref.read(branchServiceProvider).createBranch(newBranch);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Branch added successfully'), backgroundColor: Color(0xFF287A55)),
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
            child: const Text('ADD BRANCH', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _BranchListItem extends ConsumerWidget {
  final BranchModel branch;
  const _BranchListItem({required this.branch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        iconColor: const Color(0xFF5A3825),
        collapsedIconColor: const Color(0xFF8C7B70),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF382012).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.storefront_rounded, color: Color(0xFF382012), size: 22),
          ),
        ),
        title: Text(
          branch.branchName,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF29231F)),
        ),
        subtitle: Text(
          'ID: ${branch.branchId} • ${branch.location}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E55), fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                const Divider(height: 1, color: Color(0xFFE8E1D8)),
                const SizedBox(height: 16),
                _infoRow(Icons.location_on_outlined, 'Address', branch.address),
                const SizedBox(height: 12),
                _infoRow(Icons.phone_outlined, 'Contact', branch.phone),
                if (branch.instagramId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _infoRow(Icons.camera_alt_outlined, 'Instagram', '@${branch.instagramId}'),
                ],
                if (branch.reviewQrUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _infoRow(Icons.qr_code_2_rounded, 'Review URL', branch.reviewQrUrl),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF382012), width: 1.2),
                      foregroundColor: const Color(0xFF382012),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _editBranch(context, ref),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('EDIT DETAILS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF5A3825)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF5A3825),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF29231F),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _editBranch(BuildContext context, WidgetRef ref) {
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
                  helperText: 'Branch name cannot be changed once created',
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
                  labelText: 'Location',
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
                  labelText: 'Address',
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
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Branch updated successfully'),
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
