import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../domain/models/bill_model.dart';
import '../domain/models/branch_model.dart';
import '../domain/models/daily_analytics.dart';

class PdfService {
  static Future<Uint8List> generateBillPdf(BillModel bill, BranchModel branch) async {
    final pdf = pw.Document();
    final courier = pw.Font.courier();
    final courierBold = pw.Font.courierBold();

    final dateStr = DateFormat('dd/MM/yyyy').format(bill.createdAt);
    final timeStr = DateFormat('hh:mm a').format(bill.createdAt);
    final cleanUserName = bill.userName.trim().isNotEmpty
        ? bill.userName.trim()
        : (bill.lastPrintedBy?.trim().isNotEmpty == true ? bill.lastPrintedBy!.trim() : 'Staff');
    final shortUser = cleanUserName.length > 14 ? cleanUserName.substring(0, 14) : cleanUserName;

    final logoBytes = await _loadBrandingLogo();
    final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final effectiveQrUrl = branch.reviewQrUrl.trim().isNotEmpty
        ? branch.reviewQrUrl.trim()
        : 'https://g.page/r/coffeekatta/review';
    final effectiveInstagram = branch.instagramId.trim().isNotEmpty
        ? branch.instagramId.trim().replaceAll('@', '')
        : 'coffeekatta.official';

    final totalQty = bill.items.fold<int>(0, (sum, item) => sum + item.qty);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          72 * PdfPageFormat.mm,
          double.infinity,
          marginLeft: 2.5 * PdfPageFormat.mm,
          marginRight: 2.5 * PdfPageFormat.mm,
          marginTop: 2.5 * PdfPageFormat.mm,
          marginBottom: 4.0 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          final baseStyle = pw.TextStyle(font: courier, fontSize: 6.8);
          final boldStyle = pw.TextStyle(font: courierBold, fontSize: 6.8);
          final smBaseStyle = pw.TextStyle(font: courier, fontSize: 6);
          final discountLabel = bill.discountType == 'flat'
              ? 'Flat Discount'
              : 'Discount (${bill.discountPercent.toStringAsFixed(0)}%)';

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. BRANDING HEADER (Double-Line Enclosed)
              pw.Center(
                child: pw.Column(
                  children: [
                    _buildDoubleLine(verticalPadding: 1),
                    pw.SizedBox(height: 2),
                    if (logoImage != null) ...[
                      pw.Container(
                        width: 30 * PdfPageFormat.mm,
                        height: 12 * PdfPageFormat.mm,
                        margin: const pw.EdgeInsets.only(bottom: 3),
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                    ],
                    pw.Text(
                      branch.branchName.isNotEmpty ? branch.branchName.toUpperCase() : 'COFFEE KATTA',
                      style: pw.TextStyle(font: courierBold, fontSize: 10.5),
                    ),
                    if (branch.location.isNotEmpty)
                      pw.Text(
                        branch.location.toUpperCase(),
                        style: pw.TextStyle(font: courierBold, fontSize: 7.5),
                      ),
                    if (branch.address.isNotEmpty)
                      pw.Text(
                        branch.address,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: courier, fontSize: 6.2),
                      ),
                    if (branch.phone.isNotEmpty)
                      pw.Text(
                        'Phone: ${branch.phone}',
                        style: pw.TextStyle(font: courier, fontSize: 6.2),
                      ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'RETAIL INVOICE',
                      style: pw.TextStyle(font: courierBold, fontSize: 8.5, letterSpacing: 0.6),
                    ),
                    if (bill.isVoided) ...[
                      pw.SizedBox(height: 2),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.red800, width: 1),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              '*** CANCELLED / VOIDED INVOICE ***',
                              style: pw.TextStyle(font: courierBold, fontSize: 8.0, color: PdfColors.red800),
                            ),
                            if (bill.voidReason != null && bill.voidReason!.isNotEmpty)
                              pw.Text(
                                'REASON: ${bill.voidReason!.toUpperCase()}',
                                style: pw.TextStyle(font: courier, fontSize: 6.0, color: PdfColors.red800),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (bill.printCount > 1 && !bill.isVoided) ...[
                      pw.SizedBox(height: 1),
                      pw.Text(
                        '*** DUPLICATE COPY / REPRINT (#${bill.printCount}) ***',
                        style: pw.TextStyle(font: courierBold, fontSize: 6.5),
                      ),
                    ],
                    _buildDoubleLine(verticalPadding: 1),
                  ],
                ),
              ),

              // 2. METADATA SECTION
              _buildReceiptRow('INVOICE NO : ${bill.billId}', dateStr, font: courier, fontSize: 6.8),
              _buildReceiptRow('TABLE/TOKEN: ${bill.tableName.toUpperCase()}', timeStr, font: courier, fontSize: 6.8),
              _buildReceiptRow('BILLED BY  : $shortUser', 'TYPE: DINE-IN', font: courier, fontSize: 6.8),
              _buildDashedLine(verticalPadding: 1.5),

              // 3. ITEMS TABLE HEADER
              pw.Row(
                children: [
                  pw.Expanded(flex: 44, child: pw.Text('ITEM DESCRIPTION', style: boldStyle)),
                  pw.Expanded(flex: 10, child: pw.Text('QTY', style: boldStyle, textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 14, child: pw.Text('RATE', style: boldStyle, textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 16, child: pw.Text('AMOUNT', style: boldStyle, textAlign: pw.TextAlign.right)),
                ],
              ),
              _buildDashedLine(verticalPadding: 1.5),

              // 4. ITEM ROWS
              ...bill.items.map((item) {
                final itemName = item.category.isNotEmpty
                    ? "[${item.category.toUpperCase()}] ${item.name}"
                    : item.name;
                final lineTotal = item.price * item.qty;

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 44,
                            child: pw.Text(
                              itemName,
                              style: baseStyle,
                            ),
                          ),
                          pw.Expanded(
                            flex: 10,
                            child: pw.Text(
                              '${item.qty}',
                              style: baseStyle,
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Expanded(
                            flex: 14,
                            child: pw.Text(
                              item.price.toStringAsFixed(2),
                              style: baseStyle,
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Expanded(
                            flex: 16,
                            child: pw.Text(
                              lineTotal.toStringAsFixed(2),
                              style: boldStyle,
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      if (item.note.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 4, top: 0.5),
                          child: pw.Text(
                            '  * ${item.note}',
                            style: pw.TextStyle(font: courier, fontSize: 5.8, color: PdfColors.grey700),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              _buildDashedLine(verticalPadding: 1.5),

              // 5. SUMMARY & TOTALS
              _buildReceiptRow('TOTAL ITEMS : ${bill.items.length}', 'TOTAL QTY: $totalQty', font: courier, fontSize: 6.8),
              pw.SizedBox(height: 1),
              _buildReceiptRow('SUBTOTAL', 'Rs. ${bill.subtotal.toStringAsFixed(2)}', font: courier, fontSize: 6.8),

              if (bill.discountAmount > 0)
                _buildReceiptRow(
                  discountLabel.toUpperCase(),
                  '-Rs. ${bill.discountAmount.toStringAsFixed(2)}',
                  font: courier,
                  fontSize: 6.8,
                ),

              if (bill.extraCharges > 0)
                _buildReceiptRow(
                  'EXTRA / PACKAGING',
                  '+Rs. ${bill.extraCharges.toStringAsFixed(2)}',
                  font: courier,
                  fontSize: 6.8,
                ),

              _buildDoubleLine(verticalPadding: 1.5),
              _buildReceiptRow(
                'GRAND TOTAL',
                'Rs. ${bill.total.toStringAsFixed(2)}',
                font: courierBold,
                fontSize: 10,
              ),
              _buildDoubleLine(verticalPadding: 1.5),

              // 6. PAYMENT BREAKDOWN
              if (bill.payments.length > 1) ...[
                pw.Text('SETTLEMENT DETAILS (SPLIT TENDER):', style: boldStyle),
                pw.SizedBox(height: 1),
                ...bill.payments.map((p) => _buildReceiptRow(
                      '  ${p.mode.toUpperCase()}',
                      'Rs. ${p.amount.toStringAsFixed(2)}',
                      font: courier,
                      fontSize: 6.8,
                    )),
                _buildReceiptRow(
                  'TOTAL TENDERED',
                  'Rs. ${bill.payments.fold<double>(0.0, (sum, p) => sum + p.amount).toStringAsFixed(2)}',
                  font: courierBold,
                  fontSize: 6.8,
                ),
              ] else if (bill.payments.isNotEmpty) ...[
                _buildReceiptRow(
                  'PAID VIA : ${bill.payments.first.mode.toUpperCase()}',
                  'Rs. ${bill.payments.first.amount.toStringAsFixed(2)} [PAID]',
                  font: courierBold,
                  fontSize: 6.8,
                ),
              ],
              _buildDashedLine(verticalPadding: 2),

              // 7. CUSTOMER FEEDBACK & REVIEW QR CODE (QR Scanner on Left, Review & Instagram text on Right)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Left Corner: High-Contrast Scannable Review QR Code with Quiet Zone
                    pw.Container(
                      padding: const pw.EdgeInsets.all(3.5),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: effectiveQrUrl,
                        width: 52,
                        height: 52,
                      ),
                    ),
                    pw.SizedBox(width: 7),
                    // Right Side: Review Callout & Instagram Branding
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            'RATE YOUR EXPERIENCE',
                            style: pw.TextStyle(font: courierBold, fontSize: 7.2),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Scan QR to review on Google',
                            style: smBaseStyle,
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Instagram: @$effectiveInstagram',
                            style: pw.TextStyle(font: courierBold, fontSize: 6.6),
                          ),
                          pw.SizedBox(height: 1.5),
                          pw.Text(
                            'Tag us in your stories & posts!',
                            style: pw.TextStyle(font: courier, fontSize: 5.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildDashedLine(verticalPadding: 2),

              // 8. POLITE HOSPITALITY CLOSING
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Brewed with Passion | Served with Pride', style: smBaseStyle),
                    pw.SizedBox(height: 2),
                    pw.Text('*** THANK YOU FOR VISITING! ***', style: boldStyle),
                    pw.SizedBox(height: 1.5),
                    pw.Text('HAVE A WONDERFUL DAY & VISIT AGAIN', style: smBaseStyle),
                    pw.SizedBox(height: 2),
                    _buildDoubleLine(verticalPadding: 1),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List?> _loadBrandingLogo() async {
    try {
      final data = await rootBundle.load('assets/branding/splash_logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      try {
        final file = File('assets/branding/splash_logo.png');
        if (file.existsSync()) {
          return file.readAsBytesSync();
        }
      } catch (_) {}
      return null;
    }
  }

  static Future<Uint8List> generateExecutiveA4Pdf({
    required DailyAnalytics analytics,
    required String dateRangeStr,
    required BranchModel branch,
  }) async {
    final pdf = pw.Document();
    final safeDateRange = dateRangeStr
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('•', '-');
    final timestampStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final logoBytes = await _loadBrandingLogo();
    final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final grossSales = analytics.totalSales + analytics.totalDiscount - analytics.extraCharges;
    final netRevenue = analytics.totalSales;
    final aov = analytics.totalBills > 0 ? netRevenue / analytics.totalBills : 0.0;
    final totalPayments = analytics.paymentStats.values.fold(0.0, (p, c) => p + c);

    // Coffee Katta Brand Color Palette
    const primaryColor = PdfColor.fromInt(0xFF382012);   // Deep Espresso
    const accentAmber = PdfColor.fromInt(0xFFB77945);    // Warm Caramel / Amber
    const lightBg = PdfColor.fromInt(0xFFF9F7F4);        // Soft Cream
    const cardBorder = PdfColor.fromInt(0xFFE8E1D8);     // Subtle Warm Border
    const darkText = PdfColor.fromInt(0xFF29231F);       // Dark Coffee Text
    const mutedText = PdfColor.fromInt(0xFF6B5E55);      // Muted Mocha Text
    const zebraBg = PdfColor.fromInt(0xFFFAF8F5);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        header: (pw.Context context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.only(bottom: 5),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: cardBorder, width: 0.6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('COFFEE KATTA  |  EXECUTIVE AUDIT DOSSIER', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.Text('Period: $safeDateRange', style: const pw.TextStyle(fontSize: 7.5, color: mutedText)),
                  pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: mutedText)),
                ],
              ),
            );
          }

          // Full Header on Page 1
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left Column: Logo + Store Info
                  pw.Expanded(
                    flex: 65,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            height: 38,
                            margin: const pw.EdgeInsets.only(right: 10),
                            child: pw.ClipRRect(
                              horizontalRadius: 5,
                              verticalRadius: 5,
                              child: pw.Image(logoImage, height: 38, fit: pw.BoxFit.contain),
                            ),
                          ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'CONFIDENTIAL FINANCIAL DOSSIER  |  COFFEE KATTA POS',
                                style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: accentAmber, letterSpacing: 0.6),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                branch.branchName.isNotEmpty ? branch.branchName.toUpperCase() : 'COFFEE KATTA',
                                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor, letterSpacing: 0.3),
                              ),
                              pw.SizedBox(height: 1.5),
                              pw.Text('Specialty Cafe & Kitchen Management', style: const pw.TextStyle(fontSize: 7.5, color: mutedText)),
                              pw.SizedBox(height: 1.5),
                              pw.Text(
                                '${branch.location}  |  ${branch.address}',
                                style: const pw.TextStyle(fontSize: 6.8, color: PdfColor.fromInt(0xFF8C7B70)),
                                maxLines: 1,
                              ),
                              if (branch.phone.isNotEmpty)
                                pw.Text('Contact: ${branch.phone}  |  Branch ID: ${branch.branchId}', style: const pw.TextStyle(fontSize: 6.8, color: PdfColor.fromInt(0xFF8C7B70))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(width: 14),

                  // Right Column: Professional Metadata with VERY SMALL text (user requirement)
                  pw.Expanded(
                    flex: 35,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        // Small professional report tag
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor.fromInt(0xFFF7F4EF),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            border: pw.Border.all(color: const PdfColor.fromInt(0xFFDCCFBF), width: 0.6),
                          ),
                          child: pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Container(
                                width: 4,
                                height: 4,
                                margin: const pw.EdgeInsets.only(right: 4),
                                decoration: const pw.BoxDecoration(color: accentAmber, shape: pw.BoxShape.circle),
                              ),
                              pw.Text(
                                'EXECUTIVE BUSINESS REPORT',
                                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: primaryColor, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text('Period: ', style: const pw.TextStyle(fontSize: 7.5, color: mutedText)),
                            pw.Text(safeDateRange, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkText)),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text('Generated: $timestampStr', style: const pw.TextStyle(fontSize: 6.8, color: PdfColor.fromInt(0xFF8C7B70))),
                        pw.SizedBox(height: 2),
                        pw.Text('Audit Status: RECONCILED 100%', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: accentAmber)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Container(height: 1.2, color: primaryColor),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: cardBorder),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Coffee Katta POS  |  Confidential Management Audit Dossier', style: const pw.TextStyle(fontSize: 6.5, color: mutedText)),
                  pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: mutedText)),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // 1. HERO KPI METRICS (4 Balanced Cards)
            pw.Row(
              children: [
                _buildA4MetricCard('NET REVENUE', 'Rs. ${netRevenue.toStringAsFixed(2)}', 'Collected Inflow', primaryColor, accentAmber, isHighlight: true),
                pw.SizedBox(width: 7),
                _buildA4MetricCard('SETTLED ORDERS', '${analytics.totalBills}', '100% Reconciled', primaryColor, darkText),
                pw.SizedBox(width: 7),
                _buildA4MetricCard('AVERAGE TICKET', 'Rs. ${aov.toStringAsFixed(2)}', 'AOV per Order', primaryColor, darkText),
                pw.SizedBox(width: 7),
                _buildA4MetricCard('DISCOUNTS GIVEN', 'Rs. ${analytics.totalDiscount.toStringAsFixed(2)}', 'Customer Promos', primaryColor, accentAmber),
              ],
            ),
            pw.SizedBox(height: 12),

            // 2. TWO-COLUMN SPLIT: Financial Performance & Payment Method Breakdown
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left Column: Financial Performance Audit
                pw.Expanded(
                  flex: 52,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: cardBorder, width: 0.7),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildA4CardHeader('FINANCIAL PERFORMANCE STATEMENT', primaryColor, accentAmber),
                        _buildA4CompactRow('Gross F&B Menu Sales', 'Rs. ${grossSales.toStringAsFixed(2)}'),
                        _buildA4CompactRow('Total Customer Discounts', analytics.totalDiscount > 0 ? '- Rs. ${analytics.totalDiscount.toStringAsFixed(2)}' : 'Rs. 0.00', isNegative: analytics.totalDiscount > 0),
                        _buildA4CompactRow('Net Food & Beverage Sales', 'Rs. ${(grossSales - analytics.totalDiscount).toStringAsFixed(2)}'),
                        _buildA4CompactRow('Extra / Packaging Charges', 'Rs. ${analytics.extraCharges.toStringAsFixed(2)}'),
                        _buildA4CompactRow(
                          'TOTAL NET SETTLED REVENUE',
                          'Rs. ${netRevenue.toStringAsFixed(2)}',
                          isTotal: true,
                          bgColor: lightBg,
                          textColor: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),

                // Right Column: Payment Method Reconciliation
                pw.Expanded(
                  flex: 48,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: cardBorder, width: 0.7),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildA4CardHeader('PAYMENT METHOD RECONCILIATION', primaryColor, accentAmber),
                        ...analytics.paymentStats.entries.map((e) {
                          final pct = totalPayments > 0 ? (e.value / totalPayments) * 100 : 0.0;
                          return _buildA4PaymentRow(e.key, e.value, pct);
                        }),
                        // Operational reconciliation row for symmetry
                        _buildA4CompactRow('Total Settled Inflow', 'Rs. ${totalPayments.toStringAsFixed(2)} (100%)', isSubtle: true),
                        _buildA4CompactRow('Drawer Audit Status', '100% Balanced & Verified', isSubtle: true, textColor: accentAmber),
                        _buildA4CompactRow(
                          'TOTAL SETTLED PAYMENTS',
                          'Rs. ${totalPayments.toStringAsFixed(2)}',
                          isTotal: true,
                          bgColor: lightBg,
                          textColor: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // 3. CATEGORY PERFORMANCE BREAKDOWN TABLE
            pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: cardBorder, width: 0.7),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildA4CardHeader('CATEGORY PERFORMANCE BREAKDOWN', primaryColor, accentAmber),
                  pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3.5),
                      1: const pw.FlexColumnWidth(2.0),
                      2: const pw.FlexColumnWidth(1.2),
                      3: const pw.FlexColumnWidth(2.5),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF7F4EF)),
                        children: [
                          _tableA4HeaderCell('Category Name'),
                          _tableA4HeaderCell('Revenue (INR)', alignRight: true),
                          _tableA4HeaderCell('Share (%)', alignRight: true),
                          _tableA4HeaderCell('Revenue Contribution', alignCenter: true),
                        ],
                      ),
                      ...(analytics.categoryStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).asMap().entries.map((entry) {
                        final idx = entry.key;
                        final e = entry.value;
                        final pct = grossSales > 0 ? (e.value / grossSales) * 100 : 0.0;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: idx % 2 == 1 ? zebraBg : PdfColors.white,
                            border: const pw.Border(top: pw.BorderSide(color: cardBorder, width: 0.5)),
                          ),
                          children: [
                            _tableA4DataCell(e.key, bold: true),
                            _tableA4DataCell('Rs. ${e.value.toStringAsFixed(2)}', alignRight: true),
                            _tableA4DataCell('${pct.toStringAsFixed(1)}%', alignRight: true),
                            _tableA4ProgressBar(pct),
                          ],
                        );
                      }),
                      // Summary Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: lightBg,
                          border: pw.Border(top: pw.BorderSide(color: cardBorder, width: 0.7)),
                        ),
                        children: [
                          _tableA4DataCell('Total Category Sales', bold: true, color: primaryColor),
                          _tableA4DataCell('Rs. ${grossSales.toStringAsFixed(2)}', bold: true, alignRight: true, color: primaryColor),
                          _tableA4DataCell('100.0%', bold: true, alignRight: true, color: primaryColor),
                          _tableA4DataCell('All Categories Reconciled', bold: true, alignCenter: true, color: mutedText, fontSize: 6.5),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // 4. TOP SELLING MENU ITEMS (Ranked by volume & revenue)
            pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: cardBorder, width: 0.7),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildA4CardHeader('TOP SELLING MENU ITEMS (RANKED BY VOLUME & REVENUE)', primaryColor, accentAmber),
                  pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(0.8),
                      1: const pw.FlexColumnWidth(4.2),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(2.0),
                      4: const pw.FlexColumnWidth(1.8),
                      5: const pw.FlexColumnWidth(1.5),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF7F4EF)),
                        children: [
                          _tableA4HeaderCell('Rank', alignCenter: true),
                          _tableA4HeaderCell('Item Description'),
                          _tableA4HeaderCell('Qty Sold', alignRight: true),
                          _tableA4HeaderCell('Revenue (INR)', alignRight: true),
                          _tableA4HeaderCell('Avg Price', alignRight: true),
                          _tableA4HeaderCell('Share (%)', alignRight: true),
                        ],
                      ),
                      ...(analytics.itemStats.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue))).take(8).toList().asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final pct = grossSales > 0 ? (item.revenue / grossSales) * 100 : 0.0;
                        final avgPrice = item.qty > 0 ? item.revenue / item.qty : 0.0;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: idx % 2 == 1 ? zebraBg : PdfColors.white,
                            border: const pw.Border(top: pw.BorderSide(color: cardBorder, width: 0.5)),
                          ),
                          children: [
                            _tableA4RankBadge(idx + 1),
                            _tableA4DataCell(item.name, bold: true),
                            _tableA4DataCell('${item.qty}', alignRight: true),
                            _tableA4DataCell('Rs. ${item.revenue.toStringAsFixed(2)}', alignRight: true),
                            _tableA4DataCell('Rs. ${avgPrice.toStringAsFixed(2)}', alignRight: true),
                            _tableA4DataCell('${pct.toStringAsFixed(1)}%', alignRight: true),
                          ],
                        );
                      }),
                      // Summary Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: lightBg,
                          border: pw.Border(top: pw.BorderSide(color: cardBorder, width: 0.7)),
                        ),
                        children: [
                          _tableA4DataCell('', alignCenter: true),
                          _tableA4DataCell('Top Items Subtotal', bold: true, color: primaryColor),
                          _tableA4DataCell(
                            '${analytics.itemStats.values.fold(0, (p, c) => p + c.qty)}',
                            bold: true,
                            alignRight: true,
                            color: primaryColor,
                          ),
                          _tableA4DataCell(
                            'Rs. ${analytics.itemStats.values.fold(0.0, (p, c) => p + c.revenue).toStringAsFixed(2)}',
                            bold: true,
                            alignRight: true,
                            color: primaryColor,
                          ),
                          _tableA4DataCell('-', alignRight: true, color: mutedText),
                          _tableA4DataCell(
                            '${((analytics.itemStats.values.fold(0.0, (p, c) => p + c.revenue) / (grossSales > 0 ? grossSales : 1)) * 100).toStringAsFixed(1)}%',
                            bold: true,
                            alignRight: true,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // 5. OFFICIAL AUDIT & DUAL SIGNATURE BLOCK
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: cardBorder, width: 0.7),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Cashier / Reconciler Sign Box
                  pw.Expanded(
                    flex: 38,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PREPARED & RECONCILED BY', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.SizedBox(height: 4),
                        pw.Text('Cashier / Shift Supervisor', style: const pw.TextStyle(fontSize: 6.8, color: mutedText)),
                        pw.SizedBox(height: 14),
                        pw.Container(height: 0.6, color: const PdfColor.fromInt(0xFF8C7B70)),
                        pw.SizedBox(height: 2),
                        pw.Text('Authorized Signature & Date', style: const pw.TextStyle(fontSize: 6, color: PdfColor.fromInt(0xFF8C7B70))),
                      ],
                    ),
                  ),

                  // Center Seal
                  pw.Expanded(
                    flex: 24,
                    child: pw.Center(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: accentAmber, width: 0.8),
                        ),
                        child: pw.Column(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text('OFFICIAL AUDIT', style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: mutedText, letterSpacing: 0.5)),
                            pw.SizedBox(height: 1),
                            pw.Text('RECONCILED 100%', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                            pw.SizedBox(height: 1),
                            pw.Text('COFFEE KATTA POS', style: pw.TextStyle(fontSize: 5, color: accentAmber, letterSpacing: 0.3)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Manager / Auditor Sign Box
                  pw.Expanded(
                    flex: 38,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('VERIFIED & AUDITED BY', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.SizedBox(height: 4),
                        pw.Text('Store Manager / Owner', style: const pw.TextStyle(fontSize: 6.8, color: mutedText)),
                        pw.SizedBox(height: 14),
                        pw.Container(height: 0.6, color: const PdfColor.fromInt(0xFF8C7B70)),
                        pw.SizedBox(height: 2),
                        pw.Text('Official Seal & Signature', style: const pw.TextStyle(fontSize: 6, color: PdfColor.fromInt(0xFF8C7B70))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildA4CardHeader(String title, PdfColor primaryColor, PdfColor accentAmber) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF7F4EF),
          ),
          child: pw.Row(
            children: [
              pw.Container(width: 3, height: 9, color: accentAmber, margin: const pw.EdgeInsets.only(right: 5)),
              pw.Text(
                title,
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor, letterSpacing: 0.3),
              ),
            ],
          ),
        ),
        pw.Container(height: 0.6, color: const PdfColor.fromInt(0xFFE8E1D8)),
      ],
    );
  }

  static pw.Widget _buildA4MetricCard(
    String label,
    String value,
    String subtext,
    PdfColor primary,
    PdfColor textColor, {
    bool isHighlight = false,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
        decoration: pw.BoxDecoration(
          color: isHighlight ? const PdfColor.fromInt(0xFFFAF7F2) : PdfColors.white,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(
            color: isHighlight ? const PdfColor.fromInt(0xFFB77945) : const PdfColor.fromInt(0xFFE8E1D8),
            width: isHighlight ? 1 : 0.7,
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(label, style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF6B5E55))),
                pw.Container(
                  width: 4,
                  height: 4,
                  decoration: pw.BoxDecoration(
                    color: isHighlight ? const PdfColor.fromInt(0xFFB77945) : const PdfColor.fromInt(0xFFD6C8B8),
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textColor)),
            pw.SizedBox(height: 1.5),
            pw.Text(subtext, style: const pw.TextStyle(fontSize: 6.5, color: PdfColor.fromInt(0xFF8C7B70))),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildA4CompactRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isNegative = false,
    bool isSubtle = false,
    PdfColor? bgColor,
    PdfColor? textColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.8),
      decoration: pw.BoxDecoration(
        color: bgColor ?? PdfColors.white,
        border: const pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFE8E1D8), width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isTotal ? 8 : 7.5,
              fontWeight: isTotal ? pw.FontWeight.bold : null,
              color: isSubtle ? const PdfColor.fromInt(0xFF8C7B70) : (textColor ?? const PdfColor.fromInt(0xFF29231F)),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isTotal ? 8 : 7.5,
              fontWeight: isTotal ? pw.FontWeight.bold : null,
              color: isNegative
                  ? const PdfColor.fromInt(0xFFB77945)
                  : (textColor ?? const PdfColor.fromInt(0xFF29231F)),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildA4PaymentRow(String method, double amount, double pct) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.8),
      decoration: const pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFE8E1D8), width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(method.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF29231F))),
              pw.SizedBox(width: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFEFECE6),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Text('${pct.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF6B5E55))),
              ),
            ],
          ),
          pw.Text('Rs. ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 7.5, color: const PdfColor.fromInt(0xFF29231F))),
        ],
      ),
    );
  }

  static pw.Widget _tableA4HeaderCell(String text, {bool alignRight = false, bool alignCenter = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : (alignCenter ? pw.TextAlign.center : pw.TextAlign.left),
        style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF382012)),
      ),
    );
  }

  static pw.Widget _tableA4DataCell(
    String text, {
    bool bold = false,
    bool alignRight = false,
    bool alignCenter = false,
    PdfColor? color,
    double fontSize = 7.2,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : (alignCenter ? pw.TextAlign.center : pw.TextAlign.left),
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : null,
          color: color ?? const PdfColor.fromInt(0xFF29231F),
        ),
      ),
    );
  }

  static pw.Widget _tableA4RankBadge(int rank) {
    final PdfColor bgColor;
    final PdfColor textColor;

    if (rank == 1) {
      bgColor = const PdfColor.fromInt(0xFFB77945); // Amber
      textColor = PdfColors.white;
    } else if (rank == 2) {
      bgColor = const PdfColor.fromInt(0xFF4A3525); // Espresso
      textColor = PdfColors.white;
    } else if (rank == 3) {
      bgColor = const PdfColor.fromInt(0xFF7A6B60); // Muted Mocha
      textColor = PdfColors.white;
    } else {
      bgColor = const PdfColor.fromInt(0xFFEFECE6);
      textColor = const PdfColor.fromInt(0xFF6B5E55);
    }

    return pw.Center(
      child: pw.Container(
        width: 13,
        height: 13,
        margin: const pw.EdgeInsets.symmetric(vertical: 2),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Center(
          child: pw.Text(
            '$rank',
            style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: textColor),
          ),
        ),
      ),
    );
  }

  static pw.Widget _tableA4ProgressBar(double pct) {
    final ratio = (pct / 100.0).clamp(0.0, 1.0);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      child: pw.Container(
        height: 4.5,
        decoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFEFECE6),
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(2.5)),
        ),
        child: pw.Stack(
          children: [
            pw.Container(
              width: ratio * 90,
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFB77945),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(2.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildReceiptRow(String label, String value, {pw.Font? font, double fontSize = 7, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(label, 
              softWrap: false,
              style: pw.TextStyle(font: font, fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : null))),
          pw.Text(value, 
            softWrap: false,
            style: pw.TextStyle(font: font, fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : null)),
        ],
      ),
    );
  }

  static Future<Uint8List> generateDailyAnalyticsPdf({
    required DailyAnalytics analytics,
    required String dateRangeStr,
    required BranchModel branch,
    double? openingFloat,
    double? physicalCashCounted,
    double? cashVariance,
    String? closedByUserName,
  }) async {
    final pdf = pw.Document();
    final courier = pw.Font.courier();
    final courierBold = pw.Font.courierBold();
    final timestampStr = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());
    final logoBytes = await _loadBrandingLogo();
    final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final grossSales = analytics.totalSales + analytics.totalDiscount - analytics.extraCharges;
    final netRevenue = analytics.totalSales;

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          72 * PdfPageFormat.mm,
          double.infinity,
          marginLeft: 2 * PdfPageFormat.mm,
          marginRight: 2 * PdfPageFormat.mm,
          marginTop: 2 * PdfPageFormat.mm,
          marginBottom: 2 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          final baseStyle = pw.TextStyle(font: courier, fontSize: 7);
          final boldStyle = pw.TextStyle(font: courierBold, fontSize: 7);

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
            // Branding Header
            pw.Center(
              child: pw.Column(
                children: [
                  _buildDoubleLine(),
                  pw.SizedBox(height: 3),
                  if (logoImage != null) ...[
                    pw.Container(
                      width: 32 * PdfPageFormat.mm,
                      height: 12 * PdfPageFormat.mm,
                      margin: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  ],
                  pw.Text(_cleanAscii(branch.branchName.isNotEmpty ? branch.branchName.toUpperCase() : 'COFFEE KATTA'), 
                    style: pw.TextStyle(font: courierBold, fontSize: 10)),
                  pw.Text(_cleanAscii(branch.location.toUpperCase()), 
                    style: pw.TextStyle(font: courierBold, fontSize: 8)),
                  pw.Text(_cleanAscii(branch.address), 
                    textAlign: pw.TextAlign.center, style: pw.TextStyle(font: courier, fontSize: 6)),
                  if (branch.phone.isNotEmpty)
                    pw.Text('Phone: ${_cleanAscii(branch.phone)}', style: pw.TextStyle(font: courier, fontSize: 6)),
                  pw.SizedBox(height: 2),
                  pw.Text('DAILY Z-REPORT / ANALYTICS', 
                    style: pw.TextStyle(font: courierBold, fontSize: 8)),
                  pw.Text(_cleanAscii(dateRangeStr), style: baseStyle),
                  _buildDoubleLine(),
                ],
              ),
            ),
            pw.SizedBox(height: 5),

            // Financial Performance
            pw.Text('FINANCIAL SUMMARY', style: boldStyle),
            _buildDashedLine(),
            _buildReceiptRow('GROSS SALES', 'Rs. ${grossSales.toStringAsFixed(2)}', font: courierBold, fontSize: 8),
            _buildReceiptRow('TOTAL BILLS', '${analytics.totalBills}', font: courier),
            _buildReceiptRow('AVG TICKET', 'Rs. ${(analytics.totalBills > 0 ? netRevenue / analytics.totalBills : 0).toStringAsFixed(2)}', font: courier),
            _buildReceiptRow('DISCOUNTS', '-Rs. ${analytics.totalDiscount.toStringAsFixed(2)}', font: courier),
            if (analytics.extraCharges > 0)
              _buildReceiptRow('EXTRA CHARGES', '+Rs. ${analytics.extraCharges.toStringAsFixed(2)}', font: courier),
            _buildDashedLine(),
            _buildReceiptRow('NET REVENUE', 'Rs. ${netRevenue.toStringAsFixed(2)}', font: courierBold, fontSize: 9),
            _buildDoubleLine(),
            pw.SizedBox(height: 8),

            // Payment Breakdown
            pw.Text('PAYMENT BREAKDOWN', style: boldStyle),
            _buildDashedLine(),
            ...analytics.paymentStats.entries.where((e) => e.value > 0).map((e) {
               final totalPayment = analytics.paymentStats.values.fold(0.0, (p, c) => p + c);
               final percent = totalPayment > 0 ? (e.value / totalPayment) * 100 : 0.0;
               return _buildReceiptRow(e.key.toUpperCase(), '${e.value.toStringAsFixed(0)} (${percent.toStringAsFixed(0)}%)', font: courier);
            }),
            _buildDashedLine(),
            pw.SizedBox(height: 8),

            // Cash Drawer Reconciliation (Always printed on Z-Report for audit & accountability)
            pw.Text('CASH DRAWER RECONCILIATION', style: boldStyle),
            _buildDashedLine(),
            _buildReceiptRow('OPENING CASH FLOAT', 'Rs. ${(openingFloat ?? 0.0).toStringAsFixed(2)}', font: courier),
            _buildReceiptRow('EXPECTED CASH SALES', 'Rs. ${(analytics.paymentStats['cash'] ?? 0.0).toStringAsFixed(2)}', font: courier),
            _buildReceiptRow('TOTAL EXPECTED DRAWER', 'Rs. ${((openingFloat ?? 0.0) + (analytics.paymentStats['cash'] ?? 0.0)).toStringAsFixed(2)}', font: courierBold),
            _buildReceiptRow(
              'PHYSICAL CASH COUNTED',
              physicalCashCounted != null
                  ? 'Rs. ${physicalCashCounted.toStringAsFixed(2)}'
                  : 'NOT ENTERED',
              font: courierBold,
            ),
            _buildDashedLine(),
            _buildReceiptRow(
              'CASH VARIANCE',
              physicalCashCounted != null
                  ? (((cashVariance ?? (physicalCashCounted - ((openingFloat ?? 0.0) + (analytics.paymentStats['cash'] ?? 0.0)))).abs() < 0.01)
                      ? 'Rs. 0.00 (BALANCED)'
                      : ((cashVariance ?? (physicalCashCounted - ((openingFloat ?? 0.0) + (analytics.paymentStats['cash'] ?? 0.0)))) > 0
                          ? '+Rs. ${(cashVariance ?? (physicalCashCounted - ((openingFloat ?? 0.0) + (analytics.paymentStats['cash'] ?? 0.0)))).toStringAsFixed(2)} (OVER)'
                          : '-Rs. ${((cashVariance ?? (physicalCashCounted - ((openingFloat ?? 0.0) + (analytics.paymentStats['cash'] ?? 0.0)))).abs()).toStringAsFixed(2)} (SHORT)'))
                  : 'PENDING COUNT',
              font: courierBold,
              fontSize: 7.5,
            ),
            if (closedByUserName != null && closedByUserName.trim().isNotEmpty)
              _buildReceiptRow('RECONCILED BY', _cleanAscii(closedByUserName.trim().toUpperCase()), font: courier),
            _buildDashedLine(),
            pw.SizedBox(height: 8),

            // Delivery Stats
            if (analytics.deliveryMethodsStats.isNotEmpty) ...[
              pw.Text('DELIVERY PERFORMANCE', style: boldStyle),
              _buildDashedLine(),
              ...analytics.deliveryMethodsStats.entries.where((e) => e.value > 0).map((e) => 
                _buildReceiptRow(e.key.toUpperCase(), '${e.value} ORDERS', font: courier)
              ),
              _buildDashedLine(),
              pw.SizedBox(height: 10),
            ],

            // Staff Productivity
            if (analytics.userStats.isNotEmpty) ...[
              pw.Text('STAFF PRODUCTIVITY', style: boldStyle),
              _buildDashedLine(),
              ...(analytics.userStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(10).map((e) => 
                _buildReceiptRow(e.key.toUpperCase(), 'Rs. ${e.value.toStringAsFixed(0)}', font: courier)
              ),
              _buildDashedLine(),
              pw.SizedBox(height: 10),
            ],

            // Category Stats
            pw.Text('TOP CATEGORIES', style: boldStyle),
            _buildDashedLine(),
            ...(analytics.categoryStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(15).map((e) => 
               _buildReceiptRow(e.key.toUpperCase(), 'Rs. ${e.value.toStringAsFixed(0)}', font: courier)
            ),
            _buildDashedLine(),
            pw.SizedBox(height: 10),

            // Item Analysis - Most Sold
            if (analytics.itemStats.isNotEmpty) ...[
              pw.Text('MOST SOLD ITEMS', style: boldStyle),
              _buildDashedLine(),
              _buildItemHeader(boldStyle),
              _buildDashedLine(),
              ...(analytics.itemStats.values.toList()
                ..sort((a, b) {
                  int cmp = b.qty.compareTo(a.qty);
                  if (cmp == 0) return b.revenue.compareTo(a.revenue);
                  return cmp;
                })).take(10).map((item) => _buildItemRow(item, courier)),
              _buildDashedLine(),
              pw.SizedBox(height: 10),

              // Item Analysis - Least Performed
              pw.Text('LEAST PERFORMED ITEMS', style: boldStyle),
              _buildDashedLine(),
              _buildItemHeader(boldStyle),
              _buildDashedLine(),
              ...(analytics.itemStats.values.toList()
                ..sort((a, b) {
                  int cmp = a.qty.compareTo(b.qty);
                  if (cmp == 0) return a.revenue.compareTo(b.revenue);
                  return cmp;
                })).take(10).map((item) => _buildItemRow(item, courier)),
              _buildDashedLine(),
              pw.SizedBox(height: 10),
            ],

            _buildDoubleLine(),
            pw.Center(
               child: pw.Text('Generation Date: $timestampStr', style: pw.TextStyle(font: courier, fontSize: 7)),
            ),
            pw.Center(
               child: pw.Text('*** END OF REPORT ***', style: boldStyle),
            ),
          ],
        );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildDashedLine({double verticalPadding = 2}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: verticalPadding),
      child: pw.Divider(
        thickness: 0.8,
        color: PdfColors.black,
        borderStyle: pw.BorderStyle.dashed,
        height: 1,
      ),
    );
  }

  static pw.Widget _buildDoubleLine({double verticalPadding = 2}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: verticalPadding),
      child: pw.Column(
        children: [
          pw.Divider(thickness: 0.6, color: PdfColors.black, height: 1),
          pw.SizedBox(height: 1.5),
          pw.Divider(thickness: 0.6, color: PdfColors.black, height: 1),
        ],
      ),
    );
  }

  static pw.Widget _buildItemHeader(pw.TextStyle style) {
    return pw.Row(
      children: [
        pw.Expanded(flex: 3, child: pw.Text('ITEM NAME', style: style)),
        pw.Expanded(flex: 1, child: pw.Text('QTY', style: style, textAlign: pw.TextAlign.center)),
        pw.Expanded(flex: 2, child: pw.Text('AMOUNT', style: style, textAlign: pw.TextAlign.right)),
      ],
    );
  }

  static pw.Widget _buildItemRow(ItemStat item, pw.Font font) {
    final style = pw.TextStyle(font: font, fontSize: 6.5);
    // Truncate name if it's too long for the column
    final displayName = item.name.length > 20 ? '${item.name.substring(0, 17)}...' : item.name;
    
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.2),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 3, child: pw.Text(displayName.toUpperCase(), style: style, softWrap: false)),
          pw.Expanded(flex: 1, child: pw.Text(item.qty.toString(), style: style, textAlign: pw.TextAlign.center)),
          pw.Expanded(flex: 2, child: pw.Text('Rs.${item.revenue.toStringAsFixed(0)}', style: style, textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  static String _cleanAscii(String input) {
    return input
        .replaceAll('₹', 'Rs.')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), '');
  }

  static Future<File?> savePdfToFile(Uint8List bytes, String fileName) async {
    if (kIsWeb) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }
}

