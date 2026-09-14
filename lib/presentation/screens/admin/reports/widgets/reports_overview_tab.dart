import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../domain/models/daily_analytics.dart';
import 'kpi_cards_grid.dart';
import 'sales_trend_card.dart';
import 'payment_tender_card.dart';
import 'top_sellers_preview_card.dart';
import 'category_and_staff_card.dart';

class ReportsOverviewTab extends StatelessWidget {
  final DailyAnalytics analytics;
  final bool isRange;
  final ValueChanged<int> onSwitchTab;

  const ReportsOverviewTab({
    super.key,
    required this.analytics,
    required this.isRange,
    required this.onSwitchTab,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Executive Branding Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderWarm, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/branding/splash_logo.png',
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.coffee_rounded, color: AppTheme.espressoBrown, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OFFICIAL BUSINESS PERFORMANCE REPORT',
                      style: GoogleFonts.epilogue(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.espressoBrown,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aggregated analytics from POS registers, kitchen KOTs & tables',
                      style: GoogleFonts.epilogue(
                        fontSize: 10.5,
                        color: AppTheme.textDark.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 1. Top Executive KPIs
        KpiCardsGrid(analytics: analytics),
        const SizedBox(height: 16),

        // 2. Sales Trend & Peak Traffic Curve
        SalesTrendCard(analytics: analytics, isRange: isRange),
        const SizedBox(height: 16),

        // 3. Top Sellers & Payment Tender Breakdown
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TopSellersPreviewCard(
                  analytics: analytics,
                  onViewAll: () => onSwitchTab(1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: PaymentTenderCard(analytics: analytics),
              ),
            ],
          )
        else ...[
          TopSellersPreviewCard(
            analytics: analytics,
            onViewAll: () => onSwitchTab(1),
          ),
          const SizedBox(height: 16),
          PaymentTenderCard(analytics: analytics),
        ],

        const SizedBox(height: 16),

        // 4. Category Contribution & Staff Productivity
        CategoryAndStaffCard(analytics: analytics),

        const SizedBox(height: 32),
      ],
    );
  }
}
