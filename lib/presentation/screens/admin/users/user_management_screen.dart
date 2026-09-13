import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/app_theme.dart';
import '../../../../domain/models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/branch_provider.dart';
import '../../../widgets/global/base_widgets.dart';
import '../../../widgets/global/editorial_background.dart';
import '../../../widgets/global/coffee_katta_brand_badge.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _selectedRoleFilter = 'all'; // 'all', 'waiter', 'cashier', 'admin'

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

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
                  if (Navigator.canPop(context)) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                  ] else ...[
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                        tooltip: 'Menu',
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
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
                          Icon(Icons.badge_rounded, color: AppTheme.warmAmber, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'STAFF DIRECTORY',
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
                    icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 26),
                    tooltip: 'Add Staff Member',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const _AddUserBottomSheet(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: EditorialBackground(
        child: usersAsync.when(
          data: (users) {
            if (users.isEmpty) {
              return const EmptyStateWidget(
                title: 'No Users Found',
                message: 'There are no registered users in the system.',
                icon: Icons.people_outline,
              );
            }

            // Role filtering
            final filteredUsers = _selectedRoleFilter == 'all'
                ? users
                : users.where((u) => u.role.toLowerCase() == _selectedRoleFilter).toList();

            final waiterCount = users.where((u) => u.isWaiter).length;
            final cashierCount = users.where((u) => u.isCashier).length;
            final adminCount = users.where((u) => u.isAdmin).length;

            return Column(
              children: [
                // Filter Tabs Bar
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'All Users (${users.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('waiter', 'Waiters ($waiterCount)', color: const Color(0xFF287A55)),
                        const SizedBox(width: 8),
                        _buildFilterChip('cashier', 'Cashiers ($cashierCount)', color: const Color(0xFFB77945)),
                        const SizedBox(width: 8),
                        _buildFilterChip('admin', 'Admins ($adminCount)', color: AppTheme.primaryCoffee),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE8E1D8)),

                // User list
                Expanded(
                  child: filteredUsers.isEmpty
                      ? Center(
                          child: Text(
                            'No users found in $_selectedRoleFilter role.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            return _UserListItem(user: user);
                          },
                        ),
                ),
              ],
            );
          },
          loading: () => const LoadingIndicator(message: 'Loading users...'),
          error: (err, _) => ErrorStateWidget(error: err.toString()),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, {Color color = AppTheme.primaryCoffee}) {
    final isSelected = _selectedRoleFilter == filterKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.textDark,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: const Color(0xFFF7F4EF),
      side: BorderSide(color: isSelected ? color : const Color(0xFFE8E1D8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      showCheckmark: false,
      onSelected: (_) {
        setState(() => _selectedRoleFilter = filterKey);
      },
    );
  }
}

class _UserListItem extends ConsumerWidget {
  final UserModel user;
  const _UserListItem({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final allBranchesAsync = ref.watch(allBranchesProvider);

    // Resolve branch name
    String branchLabel = 'No branch assigned';
    if (user.isAdmin) {
      branchLabel = 'Global Access (All Branches)';
    } else if (user.branchIds.isNotEmpty) {
      final branchId = user.branchIds.first;
      final branches = allBranchesAsync.value;
      if (branches != null) {
        final match = branches.where((b) => b.branchId == branchId).toList();
        if (match.isNotEmpty) {
          branchLabel = match.first.branchName;
        } else {
          branchLabel = branchId;
        }
      } else {
        branchLabel = branchId;
      }
    }

    final roleColor = _getRoleColor(user.role);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: roleColor.withValues(alpha: 0.12),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: roleColor.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: roleColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      // Branch badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F4EF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE8E1D8)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              user.isAdmin ? Icons.admin_panel_settings_outlined : Icons.storefront_outlined,
                              size: 11,
                              color: AppTheme.primaryCoffee,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              branchLabel,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: user.isActive,
                activeColor: const Color(0xFF287A55),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (value) async {
                  try {
                    await authService.toggleUserActiveStatus(user.userId, user.isActive);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Account ${value ? 'enabled' : 'disabled'} for ${user.name}'),
                          backgroundColor: value ? const Color(0xFF287A55) : Colors.orange,
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
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryCoffee, size: 20),
              tooltip: 'Edit User',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => _EditUserBottomSheet(user: user),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppTheme.primaryCoffee;
      case 'cashier':
        return const Color(0xFFB77945);
      case 'waiter':
        return const Color(0xFF287A55);
      default:
        return Colors.grey;
    }
  }
}

// ─── Add User ───────────────────────────────────────────────────────────────

class _AddUserBottomSheet extends ConsumerStatefulWidget {
  const _AddUserBottomSheet();

  @override
  ConsumerState<_AddUserBottomSheet> createState() => _AddUserBottomSheetState();
}

class _AddUserBottomSheetState extends ConsumerState<_AddUserBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _selectedRole = 'waiter';
  List<String> _selectedBranchIds = [];
  bool _isLoading = false;

  final List<String> _availableRoles = ['waiter', 'cashier', 'admin'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == 'admin') {
      final allBranches = ref.read(allBranchesProvider).value ?? [];
      _selectedBranchIds = allBranches.map((b) => b.branchId).toList();
    } else if (_selectedBranchIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an assigned branch for this staff member'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.registerUser(
        _emailCtrl.text.trim(),
        _passCtrl.text,
        _nameCtrl.text.trim(),
        _selectedRole,
        _selectedBranchIds,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff user added successfully!'), backgroundColor: AppTheme.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _UserFormSheet(
      formKey: _formKey,
      title: 'Add Staff Member',
      nameCtrl: _nameCtrl,
      emailCtrl: _emailCtrl,
      passCtrl: _passCtrl,
      selectedRole: _selectedRole,
      selectedBranchIds: _selectedBranchIds,
      availableRoles: _availableRoles,
      isLoading: _isLoading,
      isNew: true,
      onRoleChanged: (v) {
        setState(() {
          _selectedRole = v;
          if (v == 'admin') {
            final allBranches = ref.read(allBranchesProvider).value ?? [];
            _selectedBranchIds = allBranches.map((b) => b.branchId).toList();
          } else if (_selectedBranchIds.length > 1) {
            _selectedBranchIds = [_selectedBranchIds.first];
          }
        });
      },
      onBranchesChanged: (branches) {
        setState(() => _selectedBranchIds = branches);
      },
      onSubmit: _submit,
    );
  }
}

// ─── Edit User ───────────────────────────────────────────────────────────────

class _EditUserBottomSheet extends ConsumerStatefulWidget {
  final UserModel user;
  const _EditUserBottomSheet({required this.user});

  @override
  ConsumerState<_EditUserBottomSheet> createState() => _EditUserBottomSheetState();
}

class _EditUserBottomSheetState extends ConsumerState<_EditUserBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late String _selectedRole;
  late List<String> _selectedBranchIds;
  bool _isLoading = false;

  final List<String> _availableRoles = ['waiter', 'cashier', 'admin'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _emailCtrl = TextEditingController(text: widget.user.email);
    _selectedRole = widget.user.role;
    _selectedBranchIds = List<String>.from(widget.user.branchIds);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == 'admin') {
      final allBranches = ref.read(allBranchesProvider).value ?? [];
      _selectedBranchIds = allBranches.map((b) => b.branchId).toList();
    } else if (_selectedBranchIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an assigned branch for this staff member'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.updateUserData(widget.user.userId, {
        'name': _nameCtrl.text.trim(),
        'role': _selectedRole,
        'branchIds': _selectedBranchIds,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff user updated successfully!'), backgroundColor: AppTheme.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _UserFormSheet(
      formKey: _formKey,
      title: 'Edit Staff Member',
      nameCtrl: _nameCtrl,
      emailCtrl: _emailCtrl,
      selectedRole: _selectedRole,
      selectedBranchIds: _selectedBranchIds,
      availableRoles: _availableRoles,
      isLoading: _isLoading,
      isNew: false,
      onRoleChanged: (v) {
        setState(() {
          _selectedRole = v;
          if (v == 'admin') {
            final allBranches = ref.read(allBranchesProvider).value ?? [];
            _selectedBranchIds = allBranches.map((b) => b.branchId).toList();
          } else if (_selectedBranchIds.length > 1) {
            _selectedBranchIds = [_selectedBranchIds.first];
          }
        });
      },
      onBranchesChanged: (branches) {
        setState(() => _selectedBranchIds = branches);
      },
      onSubmit: _submit,
    );
  }
}

// ─── Shared Form Sheet ───────────────────────────────────────────────────────

class _UserFormSheet extends ConsumerWidget {
  final GlobalKey<FormState>? formKey;
  final String title;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController? passCtrl;
  final String selectedRole;
  final List<String> selectedBranchIds;
  final List<String> availableRoles;
  final bool isLoading;
  final bool isNew;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<List<String>> onBranchesChanged;
  final VoidCallback onSubmit;

  const _UserFormSheet({
    this.formKey,
    required this.title,
    required this.nameCtrl,
    required this.emailCtrl,
    this.passCtrl,
    required this.selectedRole,
    required this.selectedBranchIds,
    required this.availableRoles,
    required this.isLoading,
    required this.isNew,
    required this.onRoleChanged,
    required this.onBranchesChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBranchesAsync = ref.watch(allBranchesProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCoffee,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: nameCtrl,
                  style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: const TextStyle(color: AppTheme.primaryCoffee, fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryCoffee, width: 1.8),
                    ),
                    prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryCoffee, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (v) => v!.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: const TextStyle(color: AppTheme.primaryCoffee, fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryCoffee, width: 1.8),
                    ),
                    prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryCoffee, size: 20),
                    filled: true,
                    fillColor: isNew ? Colors.white : const Color(0xFFF7F4EF),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: isNew,
                  validator: isNew
                      ? (v) => !v!.contains('@') ? 'Enter a valid email' : null
                      : null,
                ),
                if (isNew && passCtrl != null) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: AppTheme.primaryCoffee, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryCoffee, width: 1.8),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryCoffee, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    obscureText: true,
                    validator: (v) => v!.length < 6 ? 'Password must be at least 6 characters' : null,
                  ),
                ],
                const SizedBox(height: 12),
                // Role dropdown
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14),
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    labelText: 'Staff Role',
                    labelStyle: const TextStyle(color: AppTheme.primaryCoffee, fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryCoffee, width: 1.8),
                    ),
                    prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.primaryCoffee, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: availableRoles
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(
                              r.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textDark, fontSize: 13.5),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => onRoleChanged(v!),
                ),
                const SizedBox(height: 16),

                // Branch Assignment Section
                if (selectedRole == 'admin') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCoffee.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryCoffee.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primaryCoffee, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Global Branch Access',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.primaryCoffee,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Administrators have access to all branches and can switch between them from the menu.',
                                style: TextStyle(fontSize: 11.5, color: AppTheme.textDark),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  allBranchesAsync.when(
                    data: (branches) {
                      if (branches.isEmpty) {
                        return const Text('No branches available', style: TextStyle(color: Colors.red));
                      }

                      final currentSelected = selectedBranchIds.isNotEmpty &&
                              branches.any((b) => b.branchId == selectedBranchIds.first)
                          ? selectedBranchIds.first
                          : (branches.isNotEmpty ? branches.first.branchId : null);

                      // Ensure selected branch ID is initialized if not set
                      if (selectedBranchIds.isEmpty && currentSelected != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          onBranchesChanged([currentSelected]);
                        });
                      }

                      return DropdownButtonFormField<String>(
                        value: currentSelected,
                        style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 13.5),
                        dropdownColor: Colors.white,
                        decoration: InputDecoration(
                          labelText: selectedRole == 'waiter'
                              ? 'Assigned Work Branch *'
                              : 'Assigned Primary Branch *',
                          labelStyle: const TextStyle(color: AppTheme.primaryCoffee, fontWeight: FontWeight.bold),
                          helperText: selectedRole == 'waiter'
                              ? 'Waiters serve strictly at a single physical branch.'
                              : 'Cashiers operate primarily at their assigned branch.',
                          helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF6B5E55)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primaryCoffee, width: 1.8),
                          ),
                          prefixIcon: const Icon(Icons.storefront_outlined, color: AppTheme.primaryCoffee, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: branches
                            .map((b) => DropdownMenuItem(
                                  value: b.branchId,
                                  child: Text(
                                    '${b.branchName} (${b.branchId})',
                                    style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w600, fontSize: 13.5),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            onBranchesChanged([v]);
                          }
                        },
                        validator: (v) => (v == null || v.isEmpty) ? 'Please select a branch' : null,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading branches: $e'),
                  ),
                ],

                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryCoffee,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLoading ? null : onSubmit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isNew ? 'CREATE STAFF MEMBER' : 'SAVE CHANGES',
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

