import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../domain/models/customization_group.dart';
import '../../../../../domain/models/category.dart';
import '../../../../providers/menu_provider.dart';

class CustomizationGroupsView extends ConsumerWidget {
  final String searchQuery;

  const CustomizationGroupsView({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(customizationGroupsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return groupsAsync.when(
      data: (groups) {
        final categories = categoriesAsync.value ?? [];
        final Map<String, String> categoryNameMap = {
          for (final c in categories) c.categoryId: c.name,
        };

        final filteredGroups = groups.where((g) {
          final query = searchQuery.toLowerCase();
          return g.name.toLowerCase().contains(query);
        }).toList();

        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F4EF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE8E1D8)),
                  ),
                  child: const Icon(Icons.tune_rounded, size: 36, color: Color(0xFF8C7B70)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No option groups created yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF29231F)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create custom preparation pills or seed official Coffee Katta presets.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B5E55)),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.read(menuControllerProvider).seedDefaultModifiers(),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Seed Katta Default Option Groups'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF382012),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        if (filteredGroups.isEmpty) {
          return Center(
            child: Text(
              'No option groups match "$searchQuery"',
              style: const TextStyle(color: Color(0xFF6B5E55), fontSize: 14, fontWeight: FontWeight.w600),
            ),
          );
        }

        final activeCount = groups.where((g) => g.isAvailable).length;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                // Top Summary Strip
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F4EF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE8E1D8)),
                        ),
                        child: Text(
                          'TOTAL GROUPS: ${groups.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF5A3825),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF7F1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCDE8DA)),
                        ),
                        child: Text(
                          '$activeCount ACTIVE',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF287A55),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Groups List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredGroups.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF382012).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.tune_rounded, color: Color(0xFF382012), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          letterSpacing: 0.4,
                                          color: group.isAvailable ? const Color(0xFF29231F) : const Color(0xFF8C7B70),
                                        ),
                                      ),
                                      if (group.defaultOption.isNotEmpty)
                                        Text(
                                          'Default: ${group.defaultOption}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E55), fontWeight: FontWeight.w500),
                                        ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: group.isAvailable,
                                  activeThumbColor: const Color(0xFF287A55),
                                  activeTrackColor: const Color(0xFFCDE8DA),
                                  inactiveThumbColor: Colors.grey,
                                  inactiveTrackColor: const Color(0xFFE8E1D8),
                                  onChanged: (val) {
                                    ref.read(menuControllerProvider).toggleCustomizationGroupAvailability(group.id, val);
                                  },
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF8C7B70)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFFE8E1D8)),
                                  ),
                                  onSelected: (val) {
                                    if (val == 'edit') {
                                      CustomizationGroupDialog.show(context, ref, group: group);
                                    } else if (val == 'delete') {
                                      _confirmDelete(context, ref, group);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18, color: Color(0xFF5A3825)),
                                          SizedBox(width: 8),
                                          Text('Edit Group', style: TextStyle(fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFC0392B)),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Color(0xFFC0392B), fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Option Pills Preview
                            const Text(
                              'CHOICES:',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF5A3825), letterSpacing: 0.6),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: group.options.map((opt) {
                                final isDefault = opt == group.defaultOption;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDefault ? const Color(0xFF382012) : const Color(0xFFF7F4EF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDefault ? const Color(0xFF382012) : const Color(0xFFE8E1D8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isDefault) ...[
                                        const Icon(Icons.star_rounded, size: 13, color: AppTheme.warmAmber),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        opt,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: isDefault ? FontWeight.w800 : FontWeight.w600,
                                          color: isDefault ? Colors.white : const Color(0xFF29231F),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            // Applicable Categories
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: group.categoryIds.isEmpty
                                  ? [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7F4EF),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFE8E1D8)),
                                        ),
                                        child: const Text(
                                          'All Categories',
                                          style: TextStyle(fontSize: 10.5, color: Color(0xFF5A3825), fontWeight: FontWeight.w700),
                                        ),
                                      )
                                    ]
                                  : group.categoryIds.map((catId) {
                                      final catName = categoryNameMap[catId] ?? catId;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7F4EF),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFE8E1D8)),
                                        ),
                                        child: Text(
                                          catName,
                                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF5A3825), fontWeight: FontWeight.w600),
                                        ),
                                      );
                                    }).toList(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF382012))),
      error: (e, s) => Center(child: Text('Error loading option groups: $e')),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CustomizationGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFC0392B), size: 24),
            SizedBox(width: 8),
            Text('Delete Option Group?', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF29231F))),
          ],
        ),
        content: Text('Are you sure you want to delete "${group.name}"?', style: const TextStyle(color: Color(0xFF6B5E55))),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B5E55), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC0392B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ref.read(menuControllerProvider).deleteCustomizationGroup(group.id);
              Navigator.pop(context);
            },
            child: const Text('Delete Group', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class CustomizationGroupDialog {
  static void show(BuildContext context, WidgetRef ref, {CustomizationGroup? group}) {
    final nameController = TextEditingController(text: group?.name ?? '');
    final newOptionController = TextEditingController();
    final categoriesAsync = ref.read(categoriesStreamProvider);
    final List<Category> allCategories = categoriesAsync.value ?? [];
    final Set<String> selectedCategories = Set.from(group?.categoryIds ?? []);
    final List<String> options = List.from(group?.options ?? ['Normal']);
    String defaultOption = group?.defaultOption ?? (options.isNotEmpty ? options.first : '');
    bool isAvailable = group?.isAvailable ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF382012).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, color: Color(0xFF382012), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                group == null ? 'New Option Group' : 'Edit Option Group',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF29231F), fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GROUP TITLE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF5A3825), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Color(0xFF29231F), fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. SUGAR LEVEL, ICE LEVEL, PREPARATION',
                      hintStyle: const TextStyle(color: Color(0xFF8C7B70), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF7F4EF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Option Pills List & Add Input
                  const Text(
                    'OPTION CHOICES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF5A3825)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: options.map((opt) {
                      final isDef = opt == defaultOption;
                      return Chip(
                        label: Text(
                          opt + (isDef ? ' ★' : ''),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isDef ? FontWeight.w800 : FontWeight.w600,
                            color: isDef ? Colors.white : const Color(0xFF29231F),
                          ),
                        ),
                        backgroundColor: isDef ? const Color(0xFF382012) : const Color(0xFFF7F4EF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: isDef ? const Color(0xFF382012) : const Color(0xFFE8E1D8)),
                        ),
                        deleteIcon: Icon(Icons.close_rounded, size: 16, color: isDef ? Colors.white70 : const Color(0xFF8C7B70)),
                        onDeleted: options.length > 1
                            ? () {
                                setState(() {
                                  options.remove(opt);
                                  if (defaultOption == opt) {
                                    defaultOption = options.isNotEmpty ? options.first : '';
                                  }
                                });
                              }
                            : null,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newOptionController,
                          style: const TextStyle(color: Color(0xFF29231F), fontSize: 13, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Add choice (e.g. Extra Chilled)',
                            hintStyle: const TextStyle(color: Color(0xFF8C7B70), fontSize: 12.5),
                            filled: true,
                            fillColor: const Color(0xFFF7F4EF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onSubmitted: (val) {
                            final trimmed = val.trim();
                            if (trimmed.isNotEmpty && !options.contains(trimmed)) {
                              setState(() {
                                options.add(trimmed);
                                newOptionController.clear();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF287A55), size: 28),
                        onPressed: () {
                          final trimmed = newOptionController.text.trim();
                          if (trimmed.isNotEmpty && !options.contains(trimmed)) {
                            setState(() {
                              options.add(trimmed);
                              newOptionController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Default Option Dropdown
                  if (options.isNotEmpty) ...[
                    const Text(
                      'DEFAULT PRE-SELECTED CHOICE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF5A3825), letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: options.contains(defaultOption) ? defaultOption : options.first,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF7F4EF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: options.map((opt) {
                        return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(color: Color(0xFF29231F), fontWeight: FontWeight.w600)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => defaultOption = val);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Applicable Categories
                  const Text(
                    'APPLICABLE CATEGORIES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF5A3825)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedCategories.isEmpty
                        ? 'Applies to ALL categories by default. Tap to limit:'
                        : 'Limited to ${selectedCategories.length} category:',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E55)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allCategories.map((cat) {
                      final isSelected = selectedCategories.contains(cat.categoryId);
                      return FilterChip(
                        label: Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : const Color(0xFF29231F),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF382012),
                        backgroundColor: const Color(0xFFF7F4EF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: isSelected ? const Color(0xFF382012) : const Color(0xFFE8E1D8)),
                        ),
                        checkmarkColor: Colors.white,
                        onSelected: (checked) {
                          setState(() {
                            if (checked) {
                              selectedCategories.add(cat.categoryId);
                            } else {
                              selectedCategories.remove(cat.categoryId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active & Available', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF29231F))),
                    value: isAvailable,
                    activeThumbColor: const Color(0xFF287A55),
                    activeTrackColor: const Color(0xFFCDE8DA),
                    onChanged: (val) => setState(() => isAvailable = val),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B5E55), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF287A55),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty || options.isEmpty) return;

                final newGroup = CustomizationGroup(
                  id: group?.id ?? const Uuid().v4(),
                  name: name,
                  options: options,
                  defaultOption: defaultOption.isNotEmpty ? defaultOption : options.first,
                  categoryIds: selectedCategories.toList(),
                  isAvailable: isAvailable,
                );

                ref.read(menuControllerProvider).saveCustomizationGroup(newGroup);
                Navigator.pop(context);
              },
              child: const Text('Save Option Group', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
