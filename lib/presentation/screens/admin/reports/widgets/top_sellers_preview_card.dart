import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../domain/models/daily_analytics.dart';

class TopSellersPreviewCard extends StatelessWidget {
  final DailyAnalytics analytics;
  final VoidCallback onViewAll;

  const TopSellersPreviewCard({
    super.key,
    required this.analytics,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final double grossSales = analytics.grossSales > 0 ? analytics.grossSales : analytics.totalSales;
    final sorted = analytics.itemStats.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final topItems = sorted.take(5).toList();

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 18, color: AppTheme.accentCaramel),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'STAR SELLERS PREVIEW',
                        style: GoogleFonts.epilogue(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.espressoBrown,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All (${analytics.itemStats.length})',
                        style: GoogleFonts.epilogue(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentCaramel,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.accentCaramel),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (topItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36.0),
              child: Center(
                child: Text(
                  'No item sales recorded in this period',
                  style: GoogleFonts.epilogue(
                    fontSize: 12,
                    color: AppTheme.textDark.withValues(alpha: 0.45),
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topItems.length,
              separatorBuilder: (context, index) => const Divider(height: 14, thickness: 0.6),
              itemBuilder: (context, index) {
                final item = topItems[index];
                final share = grossSales > 0 ? (item.revenue / grossSales) * 100 : 0.0;
                return Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index == 0
                            ? AppTheme.accentCaramel.withValues(alpha: 0.15)
                            : AppTheme.backgroundWarm,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: GoogleFonts.epilogue(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: index == 0 ? AppTheme.espressoBrown : AppTheme.textDark.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name.toUpperCase(),
                            style: GoogleFonts.epilogue(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${item.qty} sold • ${share.toStringAsFixed(1)}% revenue share',
                            style: GoogleFonts.epilogue(
                              fontSize: 9.5,
                              color: AppTheme.textDark.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${item.revenue.toStringAsFixed(0)}',
                      style: GoogleFonts.epilogue(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.espressoBrown,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
