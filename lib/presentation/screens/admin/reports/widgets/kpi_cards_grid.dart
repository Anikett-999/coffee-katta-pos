import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../domain/models/daily_analytics.dart';

class KpiCardsGrid extends StatelessWidget {
  final DailyAnalytics analytics;

  const KpiCardsGrid({
    super.key,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= 1000;
    final bool isTablet = width >= 600;

    int crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 2);
    double childAspectRatio = isDesktop ? 2.1 : (isTablet ? 2.2 : 1.38);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: childAspectRatio,
      children: [
        _buildKpiCard(
          label: 'GROSS F&B SALES',
          value: '₹${analytics.grossSales.toStringAsFixed(0)}',
          subtext: analytics.totalDiscount > 0
              ? 'Includes ₹${analytics.totalDiscount.toStringAsFixed(0)} in discounts'
              : 'Before discounts & extra fees',
          icon: Icons.storefront_rounded,
          accentColor: AppTheme.espressoBrown,
          isDesktop: isDesktop,
        ),
        _buildKpiCard(
          label: 'NET REVENUE COLLECTED',
          value: '₹${analytics.netRevenue.toStringAsFixed(0)}',
          subtext: 'Net cash inflow from orders',
          icon: Icons.account_balance_wallet_rounded,
          accentColor: AppTheme.successGreenPrice,
          badgeText: 'SETTLED',
          isDesktop: isDesktop,
        ),
        _buildKpiCard(
          label: 'ORDERS & AVG TICKET',
          value: '${analytics.totalBills}',
          valueUnit: 'Bills',
          subtext: 'AOV: ₹${analytics.aov.toStringAsFixed(0)} / order',
          icon: Icons.receipt_long_rounded,
          accentColor: const Color(0xFF1E3A8A),
          isDesktop: isDesktop,
        ),
        _buildKpiCard(
          label: 'DISCOUNTS & CHARGES',
          value: '₹${analytics.totalDiscount.toStringAsFixed(0)}',
          valueUnit: 'Off',
          subtext: analytics.extraCharges > 0
              ? 'Extra Fees: +₹${analytics.extraCharges.toStringAsFixed(0)}'
              : 'Zero extra packaging fees',
          icon: Icons.local_offer_rounded,
          accentColor: analytics.totalDiscount > 0 ? const Color(0xFFDC2626) : AppTheme.accentCaramel,
          isDesktop: isDesktop,
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    String? valueUnit,
    required String subtext,
    required IconData icon,
    required Color accentColor,
    String? badgeText,
    required bool isDesktop,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 11, vertical: isDesktop ? 14 : 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 14, color: accentColor),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.epilogue(
                          fontSize: isDesktop ? 10 : 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark.withValues(alpha: 0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.epilogue(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: GoogleFonts.epilogue(
                    fontSize: isDesktop ? 22 : 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                if (valueUnit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    valueUnit,
                    style: GoogleFonts.epilogue(
                      fontSize: isDesktop ? 12 : 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            subtext,
            style: GoogleFonts.epilogue(
              fontSize: isDesktop ? 10.5 : 9.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textDark.withValues(alpha: 0.55),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
