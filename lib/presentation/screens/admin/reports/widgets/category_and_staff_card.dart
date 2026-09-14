import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../domain/models/daily_analytics.dart';

class CategoryAndStaffCard extends StatelessWidget {
  final DailyAnalytics analytics;

  const CategoryAndStaffCard({
    super.key,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final double grossSales = analytics.grossSales > 0 ? analytics.grossSales : analytics.totalSales;
    final categories = analytics.categoryStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final staff = analytics.userStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final bool isWide = MediaQuery.of(context).size.width >= 800;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderWarm, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category_rounded, size: 18, color: AppTheme.espressoBrown),
              const SizedBox(width: 8),
              Text(
                'CATEGORY & STAFF OPERATIONS',
                style: GoogleFonts.epilogue(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.espressoBrown,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildCategoriesSection(categories, grossSales)),
                const SizedBox(width: 24),
                Container(width: 1, height: 160, color: AppTheme.borderWarm),
                const SizedBox(width: 24),
                Expanded(child: _buildStaffSection(staff)),
              ],
            )
          else ...[
            _buildCategoriesSection(categories, grossSales),
            const Divider(height: 28, thickness: 0.8),
            _buildStaffSection(staff),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(List<MapEntry<String, double>> categories, double totalRevenue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORY CONTRIBUTION',
          style: GoogleFonts.epilogue(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark.withValues(alpha: 0.6),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          Text(
            'No category data available',
            style: GoogleFonts.epilogue(fontSize: 11, color: AppTheme.textDark.withValues(alpha: 0.4)),
          )
        else
          ...categories.take(6).map((cat) {
            final pct = totalRevenue > 0 ? (cat.value / totalRevenue) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cat.key,
                        style: GoogleFonts.epilogue(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        '₹${cat.value.toStringAsFixed(0)} (${(pct * 100).toStringAsFixed(1)}%)',
                        style: GoogleFonts.epilogue(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.espressoBrown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      backgroundColor: AppTheme.backgroundWarm,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCaramel),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStaffSection(List<MapEntry<String, double>> staff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STAFF BILLING PRODUCTIVITY',
          style: GoogleFonts.epilogue(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark.withValues(alpha: 0.6),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        if (staff.isEmpty)
          Text(
            'No staff performance recorded',
            style: GoogleFonts.epilogue(fontSize: 11, color: AppTheme.textDark.withValues(alpha: 0.4)),
          )
        else
          ...staff.take(5).map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.espressoBrown.withValues(alpha: 0.1),
                    child: Text(
                      s.key.isNotEmpty ? s.key[0].toUpperCase() : 'U',
                      style: GoogleFonts.epilogue(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.espressoBrown,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.key,
                      style: GoogleFonts.epilogue(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₹${s.value.toStringAsFixed(0)}',
                    style: GoogleFonts.epilogue(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
