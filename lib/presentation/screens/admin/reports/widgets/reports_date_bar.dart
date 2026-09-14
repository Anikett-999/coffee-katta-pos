import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../core/app_theme.dart';
import '../../../../providers/analytics_provider.dart';

class ReportsDateBar extends ConsumerWidget {
  final TabController tabController;
  final VoidCallback onRefresh;
  final VoidCallback onPrintZReport;
  final VoidCallback onExportA4Pdf;
  final VoidCallback onExportExcel;
  final bool isLoading;

  const ReportsDateBar({
    super.key,
    required this.tabController,
    required this.onRefresh,
    required this.onPrintZReport,
    required this.onExportA4Pdf,
    required this.onExportExcel,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(analyticsDateSelectionProvider);
    final isRange = selection['isRange'] as bool;
    final start = selection['start'] as DateTime;
    final end = selection['end'] as DateTime?;
    final dateFormat = DateFormat('dd MMM yyyy');

    final String dateStr = isRange
        ? "${dateFormat.format(start)} - ${dateFormat.format(end ?? start)}"
        : dateFormat.format(start);

    final bool isWide = MediaQuery.of(context).size.width >= 900;
    final bool isMedium = MediaQuery.of(context).size.width >= 600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderWarm.withValues(alpha: 0.8), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: Presets, Date indicator & Export actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Presets
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip(
                          context,
                          label: 'Today',
                          isSelected: !isRange && DateUtils.isSameDay(start, DateTime.now()),
                          onTap: () {
                            ref.read(analyticsDateSelectionProvider.notifier).setSingleDate(DateTime.now());
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildPresetChip(
                          context,
                          label: 'Yesterday',
                          isSelected: !isRange && DateUtils.isSameDay(start, DateTime.now().subtract(const Duration(days: 1))),
                          onTap: () {
                            ref.read(analyticsDateSelectionProvider.notifier).setSingleDate(DateTime.now().subtract(const Duration(days: 1)));
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildPresetChip(
                          context,
                          label: 'Last 7 Days',
                          isSelected: isRange && end != null && end.difference(start).inDays >= 6 && end.difference(start).inDays <= 7,
                          onTap: () {
                            final now = DateTime.now();
                            ref.read(analyticsDateSelectionProvider.notifier).setRange(now.subtract(const Duration(days: 6)), now);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildPresetChip(
                          context,
                          label: 'This Month',
                          isSelected: isRange && start.day == 1 && (end == null || DateUtils.isSameDay(end, DateTime.now())),
                          onTap: () {
                            final now = DateTime.now();
                            ref.read(analyticsDateSelectionProvider.notifier).setRange(DateTime(now.year, now.month, 1), now);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildPresetChip(
                          context,
                          label: 'Custom Range',
                          icon: Icons.calendar_month_rounded,
                          isSelected: isRange && !(end != null && end.difference(start).inDays >= 6 && end.difference(start).inDays <= 7) && start.day != 1,
                          onTap: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2023),
                              lastDate: DateTime.now(),
                              initialDateRange: DateTimeRange(
                                start: start,
                                end: end ?? start,
                              ),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppTheme.espressoBrown,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: AppTheme.textDark,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              ref.read(analyticsDateSelectionProvider.notifier).setRange(picked.start, picked.end);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Date badge on wide screens
                if (isMedium) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundWarm,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderWarm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_note_rounded, size: 14, color: AppTheme.espressoBrown),
                        const SizedBox(width: 6),
                        Text(
                          dateStr,
                          style: GoogleFonts.epilogue(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.espressoBrown,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],

                // Action Buttons Hub
                _buildActionButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Sync & Refresh Sales',
                  onTap: isLoading ? null : onRefresh,
                  color: AppTheme.textDark,
                ),
                const SizedBox(width: 6),
                _buildActionButton(
                  icon: Icons.receipt_long_rounded,
                  tooltip: 'Print Thermal Z-Report (80mm)',
                  onTap: onPrintZReport,
                  color: AppTheme.espressoBrown,
                  isPrimary: true,
                ),
                const SizedBox(width: 6),
                _buildActionButton(
                  icon: Icons.picture_as_pdf_rounded,
                  tooltip: 'Download Executive A4 PDF',
                  onTap: onExportA4Pdf,
                  color: AppTheme.accentCaramel,
                ),
                const SizedBox(width: 6),
                _buildActionButton(
                  icon: Icons.table_view_rounded,
                  tooltip: 'Export Executive Excel Report (.xlsx)',
                  onTap: onExportExcel,
                  color: const Color(0xFF1D6F42),
                ),
              ],
            ),
          ),

          // Bottom row: Clean Tab Navigation Bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.backgroundWarm.withValues(alpha: 0.5),
              border: Border(
                top: BorderSide(color: AppTheme.borderWarm.withValues(alpha: 0.5), width: 1),
              ),
            ),
            child: TabBar(
              controller: tabController,
              isScrollable: !isWide,
              labelColor: AppTheme.espressoBrown,
              unselectedLabelColor: AppTheme.textDark.withValues(alpha: 0.5),
              indicatorColor: AppTheme.espressoBrown,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4),
              unselectedLabelStyle: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dashboard_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('OVERVIEW & KPIS'),
                    ],
                  ),
                ),
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant_menu_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('MENU ENGINEERING'),
                    ],
                  ),
                ),
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('INVOICE AUDIT LOG'),
                    ],
                  ),
                ),
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.point_of_sale_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('DAY CLOSE (Z-REPORT)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.espressoBrown : AppTheme.backgroundWarm,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.espressoBrown : AppTheme.borderWarm,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: isSelected ? Colors.white : AppTheme.espressoBrown),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.epilogue(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    required Color color,
    bool isPrimary = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isPrimary ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPrimary ? color : color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isPrimary ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
