import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../domain/models/printer_config.dart';

/// A visual thermal paper ticket preview simulator showing realistic
/// receipt and KOT formatting for 58mm and 80mm widths with high-contrast
/// physical thermal paper aesthetics.
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

  // High-contrast authentic thermal printer ink colors
  static const Color _inkBlack = Color(0xFF111111);
  static const Color _inkDark = Color(0xFF241F1C);
  static const Color _inkNote = Color(0xFF3B332E);
  static const Color _paperBase = Color(0xFFFFFDF8);

  @override
  Widget build(BuildContext context) {
    final is80mm = widget.paperSize == PrinterPaperSize.mm80;
    // Responsive width bounded by screen
    final maxAllowedWidth = MediaQuery.of(context).size.width - 64;
    final targetWidth = is80mm ? 330.0 : 270.0;
    final previewWidth = targetWidth > maxAllowedWidth ? maxAllowedWidth : targetWidth;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
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
                children: const [
                  Icon(Icons.receipt_long_rounded, size: 20, color: AppTheme.primaryCoffee),
                  SizedBox(width: 8),
                  Text(
                    'LIVE TICKET SIMULATOR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: AppTheme.primaryCoffee,
                    ),
                  ),
                ],
              ),
              // Segmented Switcher: Bill vs KOT
              Container(
                height: 32,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2),
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
          const SizedBox(height: 14),

          // Paper Width Pill Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.straighten_rounded, size: 13, color: AppTheme.primaryCoffee),
                    const SizedBox(width: 6),
                    Text(
                      is80mm ? '80mm Roll • 64 Chars Width' : '58mm Roll • 32 Chars Width',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryCoffee,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Realistic Paper Canvas
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: previewWidth,
                  decoration: BoxDecoration(
                    color: _paperBase,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDDD4C5), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Jagged Tear Top
                      CustomPaint(
                        size: Size(previewWidth, 7),
                        painter: _ReceiptTearPainter(isTop: true),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: _showBill
                            ? _buildBillContent(is80mm)
                            : _buildKOTContent(is80mm),
                      ),
                      // Jagged Tear Bottom
                      CustomPaint(
                        size: Size(previewWidth, 7),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF382012) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF5A3825),
          ),
        ),
      ),
    );
  }

  Widget _buildBillContent(bool is80mm) {
    final divider = Text(
      is80mm ? '================================================' : '================================',
      style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _inkBlack, fontWeight: FontWeight.w900),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
    final dashed = Text(
      is80mm ? '------------------------------------------------' : '--------------------------------',
      style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _inkDark, fontWeight: FontWeight.bold),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        divider,
        const SizedBox(height: 6),
        Text(
          widget.branchName.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: _inkBlack,
          ),
          textAlign: TextAlign.center,
        ),
        const Text(
          'LATUR MAIN BRANCH',
          style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, fontWeight: FontWeight.w800, color: _inkDark),
          textAlign: TextAlign.center,
        ),
        Text(
          widget.branchAddress,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: _inkDark, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const Text(
          'Phone: +91 98765 43210',
          style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: _inkDark, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        dashed,
        _monoRow('Bill: CK-2026-0042', '12/09/26', isBold: true),
        _monoRow('Table: T3 (Dine-in)', '05:30 PM', isBold: true),
        _monoRow('Cashier: Pooja S.', 'Shift: #1'),
        dashed,
        _monoItemRow('ITEMS', 'QTY', 'AMOUNT', isBold: true),
        dashed,
        _monoItemRow('[BEV] Cold Coffee (L)', '2', '240.00'),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('  + Less Sugar, Extra Choco', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: _inkNote, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
        ),
        _monoItemRow('[FOOD] Classic Veg Pizza', '1', '180.00'),
        _monoItemRow('[SNACK] Masala Fries', '1', '90.00'),
        dashed,
        _monoTotalRow('Subtotal:', 'Rs. 510.00'),
        _monoTotalRow('Discount (10%):', '-Rs. 51.00'),
        _monoTotalRow('Round Off:', '-Rs. 0.00'),
        divider,
        _monoTotalRow('TOTAL:', 'Rs. 459.00', isLarge: true),
        divider,
        _monoRow('PAID VIA (SPLIT):', '', isBold: true),
        _monoRow('  CASH:', 'Rs. 259.00'),
        _monoRow('  UPI / GPay:', 'Rs. 200.00'),
        divider,
        const SizedBox(height: 8),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: _inkBlack, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Icon(Icons.qr_code_2_rounded, size: 50, color: _inkBlack),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'SCAN TO REVIEW US ON GOOGLE',
          style: TextStyle(fontFamily: 'monospace', fontSize: 8.5, fontWeight: FontWeight.w900, color: _inkBlack),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        const Text(
          'Thank You! Visit Again :)',
          style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700, color: _inkDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        divider,
      ],
    );
  }

  Widget _buildKOTContent(bool is80mm) {
    final divider = Text(
      is80mm ? '================================================' : '================================',
      style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _inkBlack, fontWeight: FontWeight.w900),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
    final dashed = Text(
      is80mm ? '------------------------------------------------' : '--------------------------------',
      style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _inkDark, fontWeight: FontWeight.bold),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        divider,
        const SizedBox(height: 4),
        const Text(
          'KOT #1042',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: _inkBlack,
          ),
        ),
        const SizedBox(height: 4),
        _monoRow('TABLE: T3', '05:31 PM • by:ramesh', isBold: true),
        dashed,
        _monoItemRow('ITEMS', 'CAT', 'QTY', isBold: true),
        dashed,
        _monoItemRow('Cold Coffee (Large)', 'BEV', '2', isBold: true),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('  note: less sugar, extra choco', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: _inkNote, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 2),
        dashed,
        _monoItemRow('Classic Veg Pizza', 'PIZZA', '1', isBold: true),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('  note: crispy base, spicy', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: _inkNote, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 2),
        dashed,
        _monoItemRow('Masala Fries', 'SNACKS', '1', isBold: true),
        dashed,
        divider,
        const SizedBox(height: 6),
        const Text(
          '-- KITCHEN SLIP --',
          style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, fontWeight: FontWeight.w900, color: _inkBlack, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _monoRow(String left, String right, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              left,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                color: _inkBlack,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            right,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
              color: _inkDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _monoItemRow(String name, String center, String right, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Text(
              name,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                color: _inkBlack,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              center,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9.5,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                color: isBold ? _inkBlack : _inkDark,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: _inkBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monoTotalRow(String label, String value, {bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: isLarge ? 11.5 : 10,
                fontWeight: isLarge ? FontWeight.w900 : FontWeight.bold,
                color: _inkBlack,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: isLarge ? 12.5 : 10,
              fontWeight: FontWeight.w900,
              color: _inkBlack,
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
      ..color = const Color(0xFFCFBEA9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

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
