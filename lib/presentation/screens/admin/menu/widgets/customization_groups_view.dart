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
                Icon(Icons.tune_outlined, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text(
                  'No option groups created yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create custom preparation pills or seed official Coffee Katta presets.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.read(menuControllerProvider).seedDefaultModifiers(),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Seed Katta Default Option Groups'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryCoffee,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filteredGroups.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final group = filteredGroups[index];
            return Card(
              elevation: 0,
              color: AppTheme.cardWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderWarm, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCaramel.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.tune, color: AppTheme.accentCaramel, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              if (group.defaultOption.isNotEmpty)
                                Text(
                                  'Default: ${group.defaultOption}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: 0.75,
                          child: Switch(
                            value: group.isAvailable,
                            activeThumbColor: AppTheme.primaryCoffee,
                            onChanged: (val) {
                              ref.read(menuControllerProvider).toggleCustomizationGroupAvailability(group.id, val);
                            },
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                          onSelected: (val) {
                            if (val == 'edit') {
                              CustomizationGroupDialog.show(context, ref, group: group);
                            } else if (val == 'delete') {
                              _confirmDelete(context, ref, group);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Visual Option Pills Preview
                    const Text(
                      'OPTION PILLS:',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppTheme.primaryCoffee,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: group.options.map((opt) {
                        final isDefault = opt == group.defaultOption;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDefault ? AppTheme.accentCaramel : AppTheme.backgroundWarm,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDefault ? AppTheme.accentCaramel : AppTheme.borderWarm,
                            ),
                          ),
                          child: Text(
                            opt + (isDefault ? ' (Default)' : ''),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
                              color: isDefault ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // Target Categories
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: group.categoryIds.isEmpty
                          ? [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundWarm,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.borderWarm),
                                ),
                                child: const Text('All Categories', style: TextStyle(fontSize: 10, color: AppTheme.textDark)),
                              )
                            ]
                          : group.categoryIds.map((catId) {
                              final catName = categoryNameMap[catId] ?? catId;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundWarm,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.borderWarm),
                                ),
                                child: Text(catName, style: const TextStyle(fontSize: 10, color: AppTheme.textDark)),
                              );
                            }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CustomizationGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Option Group', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        content: Text('Are you sure you want to delete "${group.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(menuControllerProvider).deleteCustomizationGroup(group.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            group == null ? 'Add Option Group' : 'Edit Option Group',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Group Title (e.g. SUGAR LEVEL, ICE LEVEL)',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Option Pills List & Add Input
                  const Text(
                    'OPTION CHOICES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.primaryCoffee),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: options.map((opt) {
                      final isDef = opt == defaultOption;
                      return Chip(
                        label: Text(opt + (isDef ? ' ★' : '')),
                        backgroundColor: isDef ? AppTheme.accentCaramel.withValues(alpha: 0.2) : AppTheme.backgroundWarm,
                        deleteIcon: const Icon(Icons.close, size: 16),
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
                          style: const TextStyle(color: AppTheme.textDark, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Add new choice (e.g. Extra Chilled)',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        icon: const Icon(Icons.add_circle, color: AppTheme.primaryCoffee),
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
                    DropdownButtonFormField<String>(
                      initialValue: options.contains(defaultOption) ? defaultOption : options.first,
                      decoration: const InputDecoration(
                        labelText: 'Default Selected Choice',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: options.map((opt) {
                        return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(color: AppTheme.textDark)));
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
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.primaryCoffee),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedCategories.isEmpty
                        ? 'Currently applies to ALL categories. Tap below to limit:'
                        : 'Applies to ${selectedCategories.length} selected categories:',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allCategories.map((cat) {
                      final isSelected = selectedCategories.contains(cat.categoryId);
                      return FilterChip(
                        label: Text(cat.name, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppTheme.textDark)),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryCoffee,
                        backgroundColor: AppTheme.backgroundWarm,
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
                    title: const Text('Active', style: TextStyle(fontSize: 14, color: AppTheme.textDark)),
                    value: isAvailable,
                    activeThumbColor: AppTheme.primaryCoffee,
                    onChanged: (val) => setState(() => isAvailable = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCoffee,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              child: const Text('Save Option Group'),
            ),
          ],
        ),
      ),
    );
  }
}
