import 'dart:io';
import 'dart:typed_data';
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
    final dateStr = DateFormat('dd/MM/yy').format(bill.createdAt);
    final timeStr = DateFormat('hh:mm a').format(bill.createdAt);
    final shortUser = bill.userName.length > 5 ? bill.userName.substring(0, 5) : bill.userName;

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 5 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(branch.branchName.isNotEmpty ? branch.branchName.toUpperCase() : 'COFFEE KATTA',
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(branch.location.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text(branch.address,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 8)),
                    if (branch.phone.isNotEmpty)
                      pw.Text('Phone: ${branch.phone}',
                          style: const pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(height: 5),
                    pw.Text('DIGITAL RECEIPT',
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                  ],
                ),
              ),

              // Metadata Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(bill.billId, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateStr, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('$timeStr by:$shortUser', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Center(child: pw.Text('TABLE: ${bill.tableName.toUpperCase()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
              pw.Divider(thickness: 0.5),

              // Items Header
              pw.Row(
                children: [
                  pw.Expanded(
                      flex: 4,
                      child: pw.Text('ITEMS',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(
                      flex: 1,
                      child: pw.Text('QTY',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center)),
                  pw.Expanded(
                      flex: 1,
                      child: pw.Text('AMOUNT',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items
              ...bill.items.map((item) {
                final itemName = item.category.isNotEmpty ? "[${item.category.toUpperCase()}] ${item.name}" : item.name;
                return pw.Column(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 0.2),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                              flex: 4,
                              child: pw.Text(itemName,
                                  softWrap: false,
                                  style: const pw.TextStyle(fontSize: 6))),
                          pw.Expanded(
                              flex: 1,
                              child: pw.Text(item.qty.toString(),
                                  softWrap: false,
                                  style: const pw.TextStyle(fontSize: 7),
                                  textAlign: pw.TextAlign.center)),
                          pw.Expanded(
                              flex: 1,
                              child: pw.Text(
                                  (item.price * item.qty).toStringAsFixed(0),
                                  softWrap: false,
                                  style: const pw.TextStyle(fontSize: 7),
                                  textAlign: pw.TextAlign.right)),
                        ],
                      ),
                    ),
                    pw.Divider(thickness: 0.2, borderStyle: pw.BorderStyle.dashed),
                  ],
                );
              }),

              pw.SizedBox(height: 5),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Rs. ${bill.subtotal.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (bill.discountAmount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(bill.discountType == 'flat'
                        ? 'Discount (Flat):'
                        : 'Discount (${bill.discountPercent.toStringAsFixed(0)}%):',
                        softWrap: false,
                        style: const pw.TextStyle(fontSize: 7)),
                    pw.Text('-Rs. ${bill.discountAmount.toStringAsFixed(2)}',
                        softWrap: false,
                        style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
              if (bill.extraCharges > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Extra Charges:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('+Rs. ${bill.extraCharges.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GRAND TOTAL:',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rs. ${bill.total.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 10),

              // NEW ENHANCED FOOTER (Side-by-Side)
              if (branch.reviewQrUrl.isNotEmpty || branch.instagramId.isNotEmpty)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Left: QR Code Section
                    if (branch.reviewQrUrl.isNotEmpty)
                      pw.Container(
                        width: 70,
                        height: 70,
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 0.5),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('REVIEW US', style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 2),
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: branch.reviewQrUrl,
                              width: 50,
                              height: 50,
                            ),
                          ],
                        ),
                      ),
                    
                    pw.SizedBox(width: 10),

                    // Right: Warm Message & Instagram
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Crafted with love, served with a smile. Every scoop tells a story of pure cream and joy!",
                            style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic),
                          ),
                          if (branch.instagramId.isNotEmpty) ...[
                             pw.SizedBox(height: 5),
                             pw.Row(
                               children: [
                                 pw.Text('FOLLOW US ', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                                 pw.Text('@${branch.instagramId}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                               ]
                             )
                          ]
                        ],
                      ),
                    ),
                  ],
                ),

              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Visit Again!', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('THANK YOU', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
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

  static Future<Uint8List> generateBusinessReportPdf({
    required DailyAnalytics analytics,
    required String dateRangeStr,
    required BranchModel branch,
  }) async {
    final pdf = pw.Document();
    final courier = pw.Font.courier();
    final courierBold = pw.Font.courierBold();
    final timestampStr = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());


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
          const sep = '--------------------------------------';
          const dsep = '======================================';
          final baseStyle = pw.TextStyle(font: courier, fontSize: 7);
          final boldStyle = pw.TextStyle(font: courierBold, fontSize: 7);

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
            // Branding Header
            pw.Center(
              child: pw.Column(
                children: [
                   pw.Text(dsep, style: baseStyle),
                  pw.Text(branch.branchName.isNotEmpty ? branch.branchName.toUpperCase() : 'COFFEE KATTA', 
                    style: pw.TextStyle(font: courierBold, fontSize: 10)),
                  pw.Text(branch.branchName.toUpperCase(), 
                    style: pw.TextStyle(font: courierBold, fontSize: 8)),
                  pw.Text(branch.address, 
                    textAlign: pw.TextAlign.center, style: pw.TextStyle(font: courier, fontSize: 6)),
                  if (branch.phone.isNotEmpty)
                    pw.Text('Phone: ${branch.phone}', style: pw.TextStyle(font: courier, fontSize: 6)),
                  pw.SizedBox(height: 2),
                  pw.Text('BUSINESS REPORT', 
                    style: pw.TextStyle(font: courierBold, fontSize: 8)),
                  pw.Text(dateRangeStr, style: baseStyle),
                  pw.Text(dsep, style: baseStyle),
                ],
              ),
            ),
            pw.SizedBox(height: 5),

            // Financial Metrics
            _buildReceiptRow('TOTAL SALES', 'Rs. ${analytics.totalSales.toStringAsFixed(2)}', font: courierBold, fontSize: 8),
            pw.Text(sep, style: baseStyle),
            _buildReceiptRow('TOTAL BILLS', '${analytics.totalBills}', font: courier),
            _buildReceiptRow('AVG TICKET', 'Rs. ${(analytics.totalBills > 0 ? analytics.totalSales / analytics.totalBills : 0).toStringAsFixed(2)}', font: courier),
            _buildReceiptRow('COUPONS/DISC', 'Rs. ${analytics.totalDiscount.toStringAsFixed(2)}', font: courier),
            _buildReceiptRow('EXTRA CHARGES', 'Rs. ${analytics.extraCharges.toStringAsFixed(2)}', font: courier),
            pw.Text(sep, style: baseStyle),
            _buildReceiptRow('NET COLLECTION', 'Rs. ${(analytics.totalSales - analytics.totalDiscount + analytics.extraCharges).toStringAsFixed(0)}', font: courierBold, fontSize: 10),
            pw.Text(dsep, style: baseStyle),
            pw.SizedBox(height: 10),

            // Payments Summary
            pw.Text('PAYMENT SUMMARY', style: boldStyle),
            pw.Text(sep, style: baseStyle),
            ...analytics.paymentStats.entries.where((e) => e.value > 0).map((e) => 
               _buildReceiptRow(e.key.toUpperCase(), 'Rs. ${e.value.toStringAsFixed(0)}', font: courier)
            ),
            pw.Text(sep, style: baseStyle),
            pw.SizedBox(height: 10),

            // Category Breakdown
            pw.Text('CATEGORY BREAKDOWN', style: boldStyle),
            pw.Text(sep, style: baseStyle),
            ...analytics.categoryStats.entries.where((e) => e.value > 0).map((e) => 
               _buildReceiptRow(e.key.toUpperCase(), 'Rs. ${e.value.toStringAsFixed(0)}', font: courier)
            ),
            pw.Text(dsep, style: baseStyle),
            pw.SizedBox(height: 10),
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
  }) async {
    final pdf = pw.Document();
    final courier = pw.Font.courier();
    final courierBold = pw.Font.courierBold();
    final timestampStr = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());


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
          const sep = '--------------------------------------';
          const dsep = '======================================';
          final baseStyle = pw.TextStyle(font: courier, fontSize: 7);
          final boldStyle = pw.TextStyle(font: courierBold, fontSize: 7);

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
            // Branding Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(dsep, style: baseStyle),
                  pw.Text(branch.branchName.isNotEmpty ? branch.branchName.toUpperCase() : 'COFFEE KATTA', 
                    style: pw.TextStyle(font: courierBold, fontSize: 10)),
                  pw.Text(branch.branchName.toUpperCase(), 
                    style: pw.TextStyle(font: courierBold, fontSize: 8)),
                  pw.Text(branch.address, 
                    textAlign: pw.TextAlign.center, style: pw.TextStyle(font: courier, fontSize: 6)),
                  if (branch.phone.isNotEmpty)
                    pw.Text('Phone: ${branch.phone}', style: pw.TextStyle(font: courier, fontSize: 6)),
                  pw.SizedBox(height: 2),
                  pw.Text('ANALYTICS REPORT', 
                    style: pw.TextStyle(font: courierBold, fontSize: 8)),
                  pw.Text(dateRangeStr, style: baseStyle),
                  pw.Text(dsep, style: baseStyle),
                ],
              ),
            ),
            pw.SizedBox(height: 5),

            // Financial Performance
            pw.Text('FINANCIAL PERFORMANCE', style: boldStyle),
            _buildReceiptRow('TOTAL SALES', 'Rs. ${analytics.totalSales.toStringAsFixed(2)}', font: courierBold, fontSize: 8),
            pw.Text(sep, style: baseStyle),
            _buildReceiptRow('TOTAL BILLS', '${analytics.totalBills}', font: courier),
            _buildReceiptRow('AVG TICKET', 'Rs. ${(analytics.totalBills > 0 ? analytics.totalSales / analytics.totalBills : 0).toStringAsFixed(2)}', font: courier),
            _buildReceiptRow('DISCOUNTS', 'Rs. ${analytics.totalDiscount.toStringAsFixed(2)}', font: courier),
            pw.Text(sep, style: baseStyle),
            _buildReceiptRow('NET COLLECTION', 'Rs. ${(analytics.totalSales - analytics.totalDiscount).toStringAsFixed(0)}', font: courierBold, fontSize: 10),
            pw.Text(dsep, style: baseStyle),
            pw.SizedBox(height: 10),

            // Payment Breakdown
            pw.Text('PAYMENT BREAKDOWN', style: boldStyle),
            pw.Text(sep, style: baseStyle),
            ...analytics.paymentStats.entries.where((e) => e.value > 0).map((e) {
               final totalPayment = analytics.paymentStats.values.fold(0.0, (p, c) => p + c);
               final percent = totalPayment > 0 ? (e.value / totalPayment) * 100 : 0.0;
               return _buildReceiptRow(e.key.toUpperCase(), '${e.value.toStringAsFixed(0)} (${percent.toStringAsFixed(0)}%)', font: courier);
            }),
            pw.Text(sep, style: baseStyle),
            pw.SizedBox(height: 10),

            // Delivery Stats
            if (analytics.deliveryMethodsStats.isNotEmpty) ...[
              pw.Text('DELIVERY PERFORMANCE', style: boldStyle),
              pw.Text(sep, style: baseStyle),
              ...analytics.deliveryMethodsStats.entries.where((e) => e.value > 0).map((e) => 
                _buildReceiptRow(e.key.toUpperCase(), '${e.value} ORDERS', font: courier)
              ),
              pw.Text(sep, style: baseStyle),
              pw.SizedBox(height: 10),
            ],

            // Staff Productivity
            if (analytics.userStats.isNotEmpty) ...[
              pw.Text('STAFF PRODUCTIVITY', style: boldStyle),
              pw.Text(sep, style: baseStyle),
              ...(analytics.userStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(10).map((e) => 
                _buildReceiptRow(e.key.toUpperCase(), 'Rs. ${e.value.toStringAsFixed(0)}', font: courier)
              ),
              pw.Text(sep, style: baseStyle),
              pw.SizedBox(height: 10),
            ],

            // Category Stats
            pw.Text('TOP CATEGORIES', style: boldStyle),
            pw.Text(sep, style: baseStyle),
            ...(analytics.categoryStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(15).map((e) => 
               _buildReceiptRow(e.key.toUpperCase(), 'Rs. ${e.value.toStringAsFixed(0)}', font: courier)
            ),
            pw.Text(sep, style: baseStyle),
            pw.SizedBox(height: 10),

            // Item Analysis - Most Sold
            if (analytics.itemStats.isNotEmpty) ...[
              pw.Text('MOST SOLD ITEMS', style: boldStyle),
              pw.Text(sep, style: baseStyle),
              _buildItemHeader(boldStyle),
              pw.Text(sep, style: baseStyle),
              ...(analytics.itemStats.values.toList()
                ..sort((a, b) {
                  int cmp = b.qty.compareTo(a.qty);
                  if (cmp == 0) return b.revenue.compareTo(a.revenue);
                  return cmp;
                })).take(10).map((item) => _buildItemRow(item, courier)),
              pw.Text(sep, style: baseStyle),
              pw.SizedBox(height: 10),

              // Item Analysis - Least Performed
              pw.Text('LEAST PERFORMED ITEMS', style: boldStyle),
              pw.Text(sep, style: baseStyle),
              _buildItemHeader(boldStyle),
              pw.Text(sep, style: baseStyle),
              ...(analytics.itemStats.values.toList()
                ..sort((a, b) {
                  int cmp = a.qty.compareTo(b.qty);
                  if (cmp == 0) return a.revenue.compareTo(b.revenue);
                  return cmp;
                })).take(10).map((item) => _buildItemRow(item, courier)),
              pw.Text(sep, style: baseStyle),
              pw.SizedBox(height: 10),
            ],

            pw.Text(dsep, style: baseStyle),
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

  static Future<File> savePdfToFile(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }
}

