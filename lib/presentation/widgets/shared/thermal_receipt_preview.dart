import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../domain/models/printer_config.dart';

/// A visual thermal paper ticket preview simulator showing realistic
/// receipt and KOT formatting for 58mm and 80mm widths.
class ThermalReceiptPreview extends StatefulWidget {
  final PrinterPaperSize paperSize;
  final String branchName;
  final String branchAddress;

  const ThermalReceiptPreview({
    super.key,
    required this.paperSize,
    this.branchName = 'Coffee Katta',
    this.branchAddress = 'Near Rajiv Gandhi Chowk, Latur',
  });

  @override
  State<ThermalReceiptPreview> createState() => _ThermalReceiptPreviewState();
}

class _ThermalReceiptPreviewState extends State<ThermalReceiptPreview> {
  bool _showBill = true; // true = Bill, false = KOT

  @override
  Widget build(BuildContext context) {
    final is80mm = widget.paperSize == PrinterPaperSize.mm80;
    // 58mm is ~260px wide in preview, 80mm is ~330px wide
    final previewWidth = is80mm ? 330.0 : 260.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header & Mode Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.preview_rounded, size: 18, color: AppTheme.primaryCoffee),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE TICKET SIMULATOR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: AppTheme.primaryCoffee,
                    ),
                  ),
                ],
              ),
              // Segmented Switcher: Bill vs KOT
              Container(
                height: 28,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                child: Row(
                  children: [
                    _buildSwitchTab('Bill', _showBill, () => setState(() => _showBill = true)),
                    _buildSwitchTab('KOT', !_showBill, () => setState(() => _showBill = false)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Paper Width Pill Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                child: Text(
                  is80mm ? '80mm Roll • 64 Chars Width' : '58mm Roll • 32 Chars Width',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Realistic Paper Canvas
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 540),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: previewWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF9), // Authentic thermal receipt paper tone
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE0D8CB), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Jagged Tear Top
                      CustomPaint(
                        size: Size(previewWidth, 6),
                        painter: _ReceiptTearPainter(isTop: true),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: _showBill
                            ? _buildBillContent(is80mm)
                            : _buildKOTContent(is80mm),
                      ),
                      // Jagged Tear Bottom
                      CustomPaint(
                        size: Size(previewWidth, 6),
                        painter: _ReceiptTearPainter(isTop: false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTab(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryCoffee : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildBillContent(bool is80mm) {
    final divider = Text(
      is80mm ? '================================================' : '================================',
      style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Colors.black87),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
    final dashed = Text(
      is80mm ? '------------------------------------------------' : '--------------------------------',
      style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Colors.black54),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        divider,
        const SizedBox(height: 4),
        Text(
          widget.branchName.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const Text(
          'LATUR MAIN BRANCH',
          style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        Text(
          widget.branchAddress,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        const Text(
          'Phone: +91 98765 43210',
          style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        dashed,
        _monoRow('Bill: CK-2026-0042', '12/09/26'),
        _monoRow('Table: T3 (Dine-in)', '05:30 PM'),
        _monoRow('Cashier: Pooja S.', 'Shift: #1'),
        dashed,
        _monoItemRow('ITEMS', 'QTY', 'AMOUNT', isBold: true),
        dashed,
        _monoItemRow('[BEV] Cold Coffee (L)', '2', '240.00'),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('  + Less Sugar, Extra Choco', style: TextStyle(fontFamily: 'monospace', fontSize: 8.5, color: Colors.black54)),
        ),
        _monoItemRow('[FOOD] Classic Veg Pizza', '1', '180.00'),
        _monoItemRow('[SNACK] Masala Fries', '1', '90.00'),
        dashed,
        _monoTotalRow('Subtotal:', 'Rs. 510.00'),
        _monoTotalRow('Discount (10%):', '-Rs. 51.00'),
        _monoTotalRow('Round Off:', '-Rs. 0.00'),
        divider,
        _monoTotalRow('GRAND TOTAL:', 'Rs. 459.00', isLarge: true),
        divider,
        _monoRow('PAID VIA (SPLIT):', ''),
        _monoRow('  CASH:', 'Rs. 259.00'),
        _monoRow('  UPI / GPay:', 'Rs. 200.00'),
        divider,
        const SizedBox(height: 6),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Icon(Icons.qr_code_2_rounded, size: 48, color: Colors.black),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'SCAN TO REVIEW US ON GOOGLE',
          style: TextStyle(fontFamily: 'monospace', fontSize: 8, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        const Text(
          'Thank You! Visit Again :)',
          style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        divider,
      ],
    );
  }

  Widget _buildKOTContent(bool is80mm) {
    final divider = Text(
      is80mm ? '================================================' : '================================',
      style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Colors.black87),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
    final dashed = Text(
      is80mm ? '------------------------------------------------' : '--------------------------------',
      style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Colors.black54),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        divider,
        const Text(
          'KOT #1042',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        _monoRow('TABLE: T3', '05:31 PM • by:ramesh', isBold: true),
        dashed,
        _monoItemRow('ITEMS', 'CAT', 'QTY', isBold: true),
        dashed,
        _monoItemRow('Cold Coffee (Large)', 'BEV', '2', isBold: true),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('  note: less sugar, extra choco', style: TextStyle(fontFamily: 'monospace', fontSize: 8.5, color: Colors.black87)),
        ),
        dashed,
        _monoItemRow('Classic Veg Pizza', 'PIZZA', '1', isBold: true),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('  note: crispy base, spicy', style: TextStyle(fontFamily: 'monospace', fontSize: 8.5, color: Colors.black87)),
        ),
        dashed,
        _monoItemRow('Masala Fries', 'SNACKS', '1', isBold: true),
        dashed,
        divider,
        const SizedBox(height: 4),
        const Text(
          '-- KITCHEN SLIP --',
          style: TextStyle(fontFamily: 'monospace', fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _monoRow(String left, String right, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: TextStyle(fontFamily: 'monospace', fontSize: 9, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(right, style: TextStyle(fontFamily: 'monospace', fontSize: 9, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _monoItemRow(String name, String center, String right, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Text(
              name,
              style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, fontWeight: isBold ? FontWeight.bold : FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              center,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, fontWeight: isBold ? FontWeight.w900 : FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monoTotalRow(String label, String value, {bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: isLarge ? 12 : 9.5,
              fontWeight: isLarge ? FontWeight.w900 : FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: isLarge ? 13 : 9.5,
              fontWeight: isLarge ? FontWeight.w900 : FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptTearPainter extends CustomPainter {
  final bool isTop;
  const _ReceiptTearPainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8E1D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final path = Path();
    const toothWidth = 8.0;
    final toothHeight = size.height;
    final count = (size.width / toothWidth).ceil();

    path.moveTo(0, isTop ? toothHeight : 0);
    for (int i = 0; i < count; i++) {
      final x1 = i * toothWidth + (toothWidth / 2);
      final y1 = isTop ? 0.0 : toothHeight;
      final x2 = (i + 1) * toothWidth;
      final y2 = isTop ? toothHeight : 0.0;
      path.lineTo(x1, y1);
      path.lineTo(x2, y2);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
