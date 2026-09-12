import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/app_theme.dart';
import '../../../../domain/models/branch_model.dart';
import '../../../../services/branch_service.dart';
import '../../../providers/branch_provider.dart';
import '../../../widgets/global/base_widgets.dart';
import '../../../widgets/global/editorial_background.dart';

class BranchManagementScreen extends ConsumerWidget {
  const BranchManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(allBranchesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('MY BRANCHES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppTheme.maroon)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.black.withOpacity(0.1),
        scrolledUnderElevation: 4,
        iconTheme: const IconThemeData(color: AppTheme.maroon),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            onPressed: () => _addBranch(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: EditorialBackground(
        child: branchesAsync.when(
          data: (branches) {
            if (branches.isEmpty) {
              return EmptyStateWidget(
                title: 'No Branches Configured',
                message: 'Database initialization might be incomplete.',
                icon: Icons.store_mall_directory_outlined,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: branches.length,
              itemBuilder: (context, index) {
                final branch = branches[index];
                return _BranchListItem(branch: branch);
              },
            );
          },
          loading: () => LoadingIndicator(message: 'Loading branches...'),
          error: (err, _) => ErrorStateWidget(error: err.toString()),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('ADD NEW BRANCH', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.maroon)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Branch Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
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
              if (nameController.text.trim().isEmpty) return;
              
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
                    const SnackBar(content: Text('Branch added successfully'), backgroundColor: AppTheme.successGreen),
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
            child: const Text('ADD BRANCH'),
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
      margin: const EdgeInsets.only(bottom: 16),
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
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF382012).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.storefront_rounded, color: Color(0xFF382012)),
        ),
        title: Text(
          branch.branchName,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF29231F)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('EDIT BRANCH INFO', style: TextStyle(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Branch Name', 
                  helperText: 'Branch name cannot be changed once created',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: instagramController,
                decoration: const InputDecoration(
                  labelText: 'Instagram ID (@handle)', 
                  prefixText: '@',
                  border: OutlineInputBorder()
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reviewQrController,
                decoration: const InputDecoration(
                  labelText: 'Google Review Link', 
                  helperText: 'Paste the direct Google Maps review URL',
                  border: OutlineInputBorder()
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
                branchName: nameController.text,
                location: locationController.text,
                address: addressController.text,
                phone: phoneController.text,
                instagramId: instagramController.text.replaceAll('@', ''),
                reviewQrUrl: reviewQrController.text,
              );

              try {
                await ref.read(branchServiceProvider).updateBranchDetails(updatedBranch);
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
