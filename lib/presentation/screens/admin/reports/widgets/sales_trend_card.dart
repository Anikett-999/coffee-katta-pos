import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../domain/models/daily_analytics.dart';

class SalesTrendCard extends StatelessWidget {
  final DailyAnalytics analytics;
  final bool isRange;

  const SalesTrendCard({
    super.key,
    required this.analytics,
    required this.isRange,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;
    final Map<int, double> hourlyData = {};
    for (int i = 0; i < 24; i++) {
      hourlyData[i] = analytics.hourlyStats[i.toString()]?.sales ?? 0.0;
    }

    final double maxRevenue = hourlyData.values.fold(0.0, (prev, val) => val > prev ? val : prev);
    final double chartMaxY = (maxRevenue * 1.25).clamp(100.0, double.infinity);

    // Peak hour calculation
    int peakHour = -1;
    double peakRevenue = 0.0;
    hourlyData.forEach((hour, sales) {
      if (sales > peakRevenue) {
        peakRevenue = sales;
        peakHour = hour;
      }
    });

    final peakLabel = peakHour >= 0
        ? '${peakHour.toString().padLeft(2, '0')}:00 (₹${peakRevenue.toStringAsFixed(0)})'
        : 'N/A';

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
          if (!isDesktop) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.show_chart_rounded, size: 18, color: AppTheme.espressoBrown),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SALES & TRAFFIC VELOCITY',
                        style: GoogleFonts.epilogue(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.espressoBrown,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isRange ? 'Aggregated hourly sales across selected period' : 'Real-time 24-hour store sales distribution',
                  style: GoogleFonts.epilogue(
                    fontSize: 11,
                    color: AppTheme.textDark.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (peakHour >= 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCaramel.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentCaramel.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.accentCaramel),
                        const SizedBox(width: 4),
                        Text(
                          'PEAK: $peakLabel',
                          style: GoogleFonts.epilogue(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.espressoBrown,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.show_chart_rounded, size: 18, color: AppTheme.espressoBrown),
                        const SizedBox(width: 8),
                        Text(
                          'SALES & TRAFFIC VELOCITY',
                          style: GoogleFonts.epilogue(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.espressoBrown,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRange ? 'Aggregated hourly sales across selected period' : 'Real-time 24-hour store sales distribution',
                      style: GoogleFonts.epilogue(
                        fontSize: 11,
                        color: AppTheme.textDark.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (peakHour >= 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCaramel.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentCaramel.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.accentCaramel),
                        const SizedBox(width: 4),
                        Text(
                          'PEAK: $peakLabel',
                          style: GoogleFonts.epilogue(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.espressoBrown,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: isDesktop ? 220 : 180,
            child: maxRevenue == 0
                ? Center(
                    child: Text(
                      'No sales transactions recorded in this period',
                      style: GoogleFonts.epilogue(
                        fontSize: 12,
                        color: AppTheme.textDark.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: chartMaxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => AppTheme.espressoBrown,
                          tooltipRoundedRadius: 8,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final h = group.x;
                            final nextH = (h + 1) % 24;
                            final timeStr = '${h.toString().padLeft(2, '0')}:00 - ${nextH.toString().padLeft(2, '0')}:00';
                            return BarTooltipItem(
                              '$timeStr\n₹${rod.toY.toStringAsFixed(0)}',
                              GoogleFonts.epilogue(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: isDesktop,
                            reservedSize: 42,
                            getTitlesWidget: (val, meta) {
                              if (val == 0) return const SizedBox.shrink();
                              if (val >= 1000) {
                                return Text(
                                  '₹${(val / 1000).toStringAsFixed(0)}k',
                                  style: GoogleFonts.epilogue(
                                    fontSize: 9.5,
                                    color: AppTheme.textDark.withValues(alpha: 0.45),
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }
                              return Text(
                                '₹${val.toInt()}',
                                style: GoogleFonts.epilogue(
                                  fontSize: 9.5,
                                  color: AppTheme.textDark.withValues(alpha: 0.45),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final int h = val.toInt();
                              // Display every 3 hours on desktop, every 4 hours on tablet/mobile
                              final int step = isDesktop ? 3 : 4;
                              if (h % step == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    '${h}h',
                                    style: GoogleFonts.epilogue(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark.withValues(alpha: 0.5),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: chartMaxY / 4,
                        getDrawingHorizontalLine: (val) => FlLine(
                          color: AppTheme.borderWarm.withValues(alpha: 0.5),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(24, (i) {
                        final val = hourlyData[i] ?? 0.0;
                        final isPeak = i == peakHour && peakRevenue > 0;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: val,
                              color: isPeak ? AppTheme.accentCaramel : AppTheme.espressoBrown,
                              width: isDesktop ? 12 : 6,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: chartMaxY,
                                color: AppTheme.backgroundWarm.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
