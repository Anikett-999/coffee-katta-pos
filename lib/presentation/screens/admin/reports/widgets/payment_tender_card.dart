import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../domain/models/daily_analytics.dart';

class PaymentTenderCard extends StatefulWidget {
  final DailyAnalytics analytics;

  const PaymentTenderCard({
    super.key,
    required this.analytics,
  });

  @override
  State<PaymentTenderCard> createState() => _PaymentTenderCardState();
}

class _PaymentTenderCardState extends State<PaymentTenderCard> {
  int _touchedIndex = -1;

  Color _getModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'cash':
        return AppTheme.successGreenPrice;
      case 'upi':
        return const Color(0xFF1E3A8A); // Deep royal blue
      case 'card':
        return AppTheme.accentCaramel;
      default:
        return const Color(0xFF7C3AED); // Purple
    }
  }

  IconData _getModeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'cash':
        return Icons.payments_rounded;
      case 'upi':
        return Icons.qr_code_2_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalPayments = widget.analytics.paymentStats.values.fold(0.0, (p, c) => p + c);
    final List<MapEntry<String, double>> activeModes = widget.analytics.paymentStats.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
                    const Icon(Icons.pie_chart_rounded, size: 18, color: AppTheme.espressoBrown),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PAYMENT TENDER SPLIT',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.successGreenPrice.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '100% RECONCILED',
                  style: GoogleFonts.epilogue(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.successGreenPrice,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (totalPayments == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36.0),
              child: Center(
                child: Text(
                  'No payment collections recorded yet',
                  style: GoogleFonts.epilogue(
                    fontSize: 12,
                    color: AppTheme.textDark.withValues(alpha: 0.45),
                  ),
                ),
              ),
            )
          else ...[
            // Donut Chart
            SizedBox(
              height: 120,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sectionsSpace: 3,
                  centerSpaceRadius: 36,
                  sections: activeModes.asMap().entries.map((entry) {
                    final isTouched = entry.key == _touchedIndex;
                    final mode = entry.value.key;
                    final amount = entry.value.value;
                    final color = _getModeColor(mode);

                    return PieChartSectionData(
                      color: color,
                      value: amount,
                      radius: isTouched ? 20 : 15,
                      showTitle: false,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Itemized Tender Table
            ...activeModes.map((entry) {
              final mode = entry.key;
              final amount = entry.value;
              final pct = totalPayments > 0 ? (amount / totalPayments) * 100 : 0.0;
              final color = _getModeColor(mode);
              final icon = _getModeIcon(mode);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, size: 13, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mode.toUpperCase(),
                            style: GoogleFonts.epilogue(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Text(
                            '${pct.toStringAsFixed(1)}% of total intake',
                            style: GoogleFonts.epilogue(
                              fontSize: 9.5,
                              color: AppTheme.textDark.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${amount.toStringAsFixed(0)}',
                      style: GoogleFonts.epilogue(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const Divider(height: 16, thickness: 0.8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL SETTLEMENT',
                  style: GoogleFonts.epilogue(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark.withValues(alpha: 0.6),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '₹${totalPayments.toStringAsFixed(0)}',
                  style: GoogleFonts.epilogue(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.espressoBrown,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
