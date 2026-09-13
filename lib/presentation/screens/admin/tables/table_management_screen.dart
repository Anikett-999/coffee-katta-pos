import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/app_theme.dart';
import '../../../../domain/models/table_model.dart';
import '../../../providers/table_provider.dart';
import '../../../widgets/global/base_widgets.dart';
import '../../../widgets/global/confirmation_dialog.dart';
import '../../../widgets/global/editorial_background.dart';
import '../../../widgets/global/coffee_katta_brand_badge.dart';

class TableManagementScreen extends ConsumerStatefulWidget {
  final bool useShell;
  const TableManagementScreen({super.key, this.useShell = false});

  @override
  ConsumerState<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends ConsumerState<TableManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(tablesStreamProvider);

    Widget content = Column(
      children: [
        // Search Bar & Add Button row for Shell mode
        if (widget.useShell)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(child: _buildSearchBar()),
                const SizedBox(width: 12),
                _buildAddTableButton(isShell: true),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildSearchBar(),
          ),
        
        Expanded(
          child: tablesAsync.when(
            data: (tables) {
              final filteredTables = tables.where((t) => 
                t.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

              if (filteredTables.isEmpty) {
                return EmptyStateWidget(
                  title: _searchQuery.isEmpty ? 'No Tables Ready' : 'No Tables Found',
                  message: _searchQuery.isEmpty 
                      ? 'Get started by adding your first table.' 
                      : 'No tables match your search query.',
                  icon: Icons.table_bar_outlined,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredTables.length,
                itemBuilder: (context, index) {
                  final table = filteredTables[index];
                  return _TableListItem(table: table);
                },
              );
            },
            loading: () => const LoadingIndicator(message: 'Loading tables...'),
            error: (err, _) => ErrorStateWidget(error: err.toString()),
          ),
        ),
      ],
    );

    if (widget.useShell) {
      return content;
    }

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
                          Icon(Icons.table_restaurant_rounded, color: AppTheme.warmAmber, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'TABLE MANAGEMENT',
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
                  _buildAddTableButton(isShell: false),
                ],
              ),
            ),
          ),
        ),
      ),
      body: EditorialBackground(child: content),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.maroon.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search tables...',
          hintStyle: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.5), fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppTheme.maroon),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear, color: AppTheme.maroon), 
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                }) 
            : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.maroon.withOpacity(0.1), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.maroon.withOpacity(0.15), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.maroon, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildAddTableButton({required bool isShell}) {
    return Padding(
      padding: isShell ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [AppTheme.espressoBrown, Color(0xFF2E1A09)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.espressoBrown.withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showAddTableSheet(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
                  if (!isShell) ...[
                    const SizedBox(width: 6),
                    const Text('ADD TABLE', 
                      style: TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.w900, 
                        fontSize: 12,
                        letterSpacing: 0.8
                      )),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTableSheet(BuildContext context) {
    final tables = ref.read(tablesStreamProvider).value ?? [];
    final suggestedName = _getNextTableName(tables);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TableFormSheet(suggestedName: suggestedName),
    );
  }

  String _getNextTableName(List<TableModel> tables) {
    if (tables.isEmpty) return 'Table 1';
    
    // Try to find the naming pattern from the most recent tables
    final lastTable = tables.last;
    final name = lastTable.name;
    
    // Regex to find trailing numbers
    final match = RegExp(r'^(.*?)(\d+)$').firstMatch(name);
    
    if (match != null) {
      final prefix = match.group(1) ?? '';
      final numberStr = match.group(2) ?? '0';
      final nextNumber = int.parse(numberStr) + 1;
      return '$prefix$nextNumber';
    }
    
    // Fallback: If no trailing number, try to append " 1" or increment if "Table" exists
    final tableCount = tables.length;
    return 'Table ${tableCount + 1}';
  }
}

class _TableListItem extends ConsumerWidget {
  final TableModel table;
  const _TableListItem({required this.table});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.maroon.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: _buildLeadingIcon(),
        title: Text(
          table.name, 
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.maroon)
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_alt_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text('${table.capacity} Per.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(width: 8),
              Flexible(child: _buildStatusIndicator()),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.maroon),
          onSelected: (value) {
            if (value == 'edit') {
              _showEditTableSheet(context, table);
            } else if (value == 'delete') {
              _confirmDelete(context, ref, table);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                title: Text('Edit', style: TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red, size: 20),
                title: Text('Delete', style: TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _getStatusColor(table.status).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.table_restaurant_rounded, color: _getStatusColor(table.status), size: 28),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor(table.status).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        table.status.toUpperCase(),
        style: TextStyle(
          fontSize: 10, 
          fontWeight: FontWeight.bold, 
          color: _getStatusColor(table.status),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available': return AppTheme.statusAvailable;
      case 'occupied': return AppTheme.statusOccupied;
      case 'billing': return AppTheme.statusBilling;
      default: return Colors.grey;
    }
  }

  void _showEditTableSheet(BuildContext context, TableModel table) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TableFormSheet(table: table),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, TableModel table) {
    if (table.status != 'available') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete table "${table.name}" because it is currently ${table.status}.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ConfirmationDialog.show(
      context: context,
      title: 'Delete Table',
      message: 'Are you sure you want to delete "${table.name}"? This action cannot be undone.',
      confirmLabel: 'Delete',
      onConfirm: () async {
        try {
          await ref.read(tableServiceProvider).deleteTable(table.tableId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Table deleted successfully'), backgroundColor: AppTheme.successGreen),
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
    );
  }
}

class _TableFormSheet extends ConsumerStatefulWidget {
  final TableModel? table;
  final String? suggestedName;
  const _TableFormSheet({this.table, this.suggestedName});

  @override
  ConsumerState<_TableFormSheet> createState() => _TableFormSheetState();
}

class _TableFormSheetState extends ConsumerState<_TableFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _capacityController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.table?.name ?? widget.suggestedName ?? '');
    _capacityController = TextEditingController(text: widget.table?.capacity.toString() ?? '4');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    
    // 1. Regex Validation
    final nameRegex = RegExp(r'^[a-zA-Z0-9 ]+$');
    if (!nameRegex.hasMatch(name)) {
      _showValidationError(
        'Invalid Table Name',
        'Table names can only contain letters, numbers, and spaces. Special characters are not allowed.'
      );
      return;
    }

    // 2. Standard Form Validation
    if (!_formKey.currentState!.validate()) return;

    final capacity = int.tryParse(_capacityController.text.trim()) ?? 0;

    // 3. Duplicate Check
    final allTables = ref.read(tablesStreamProvider).value ?? [];
    final isDuplicate = allTables.any((t) => 
      t.tableId != widget.table?.tableId && 
      t.name.toLowerCase() == name.toLowerCase()
    );

    if (isDuplicate) {
      _showValidationError(
        'Duplicate Name',
        'A table with the name "$name" already exists. Please choose a unique name.'
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(tableServiceProvider);
      if (widget.table == null) {
        await service.createTable(name, capacity);
      } else {
        await service.updateTable(widget.table!.tableId, name, capacity);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Table ${widget.table == null ? 'created' : 'updated'} successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
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

  void _showValidationError(String title, String message) {
    ConfirmationDialog.show(
      context: context,
      title: title,
      message: message,
      confirmLabel: 'OK',
      onConfirm: () {}, // No action needed for validation error
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 24, left: 24, right: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.table == null ? 'Add New Table' : 'Edit Table Details', 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.maroon)
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Table Name',
                  labelStyle: const TextStyle(color: AppTheme.primaryCoffee, fontWeight: FontWeight.bold),
                  hintText: 'e.g. Table 10',
                  hintStyle: const TextStyle(color: Color(0xFF8C7B70), fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppTheme.primaryCoffee, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.primaryCoffee),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Table name is required' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _capacityController,
                style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Seating Capacity',
                  labelStyle: const TextStyle(color: AppTheme.primaryCoffee, fontWeight: FontWeight.bold),
                  hintText: 'Number of persons',
                  hintStyle: const TextStyle(color: Color(0xFF8C7B70), fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppTheme.primaryCoffee, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.people_outline, color: AppTheme.primaryCoffee),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Capacity is required';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return 'Enter a valid number greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                  backgroundColor: AppTheme.maroon,
                ),
                child: _isLoading 
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : Text(
                      widget.table == null ? 'CONTINUE & CREATE' : 'SAVE CHANGES', 
                      style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)
                    ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
