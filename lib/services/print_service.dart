import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image/image.dart' as img;
import '../domain/models/bill_model.dart';
import '../domain/models/kot_model.dart';
import '../domain/models/branch_model.dart';
import '../domain/models/printer_config.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'windows_raw_printer.dart';

class PrintService {
  // Generate KOT ESC/POS commands
  Future<List<int>> generateKOTBytes(KOTModel kot, PrinterPaperSize paperSize) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(
      paperSize == PrinterPaperSize.mm80 ? PaperSize.mm80 : PaperSize.mm58, 
      profile
    );
    List<int> bytes = [];

    // 0. INITIALIZE PRINTER & RESET MARGIN
    bytes += [0x1B, 0x40]; // Initialize
    bytes += [0x1D, 0x4C, 0x00, 0x00]; // GS L 0 0 (Set left margin to 0)

    final int maxChars = paperSize == PrinterPaperSize.mm80 ? 48 : 32;
    final String sep = '-' * maxChars;
    final String dsep = '=' * maxChars;

    String fitCell(String text, int width, {bool alignRight = false, bool alignCenter = false}) {
      final safeText = text.replaceAll('₹', 'Rs.').replaceAll('—', '-').replaceAll('–', '-');
      final normalized = safeText.length > width ? safeText.substring(0, width) : safeText;
      if (alignCenter) {
        final totalPad = (width - normalized.length).clamp(0, width);
        final leftPad = totalPad ~/ 2;
        final rightPad = totalPad - leftPad;
        return (' ' * leftPad) + normalized + (' ' * rightPad);
      }
      return alignRight ? normalized.padLeft(width) : normalized.padRight(width);
    }

    String formatDualLine(String left, String right) {
      final safeLeft = left.replaceAll('₹', 'Rs.').replaceAll('—', '-').replaceAll('–', '-');
      final safeRight = right.replaceAll('₹', 'Rs.').replaceAll('—', '-').replaceAll('–', '-');
      final maxLeft = (maxChars - safeRight.length - 1).clamp(0, maxChars);
      final clippedLeft = safeLeft.length > maxLeft ? safeLeft.substring(0, maxLeft) : safeLeft;
      final spaces = (maxChars - clippedLeft.length - safeRight.length).clamp(1, maxChars);
      return clippedLeft + (' ' * spaces) + safeRight;
    }

    List<String> wrapText(String text, int width) {
      if (text.isEmpty) return [''];
      final words = text.replaceAll('₹', 'Rs.').split(RegExp(r'\s+'));
      final lines = <String>[];
      var current = '';

      for (final word in words) {
        if (word.length > width) {
          if (current.isNotEmpty) {
            lines.add(current);
            current = '';
          }
          lines.add(word.substring(0, width));
          continue;
        }
        final candidate = current.isEmpty ? word : '$current $word';
        if (candidate.length <= width) {
          current = candidate;
        } else {
          lines.add(current);
          current = word;
        }
      }
      if (current.isNotEmpty) lines.add(current);
      return lines;
    }

    final int itemWidth = (maxChars * 0.55).floor();
    final int catWidth = (maxChars * 0.25).floor();
    final int qtyWidth = maxChars - itemWidth - catWidth;

    // 1. Header: Large Bold KOT Number
    final String timeStr = DateFormat('hh:mm a').format(kot.createdAt);
    final String dateStr = DateFormat('dd/MM/yy').format(kot.createdAt);

    bytes += generator.text(dsep);
    bytes += generator.text('KOT #${kot.kotNumber}', 
      styles: const PosStyles(
        bold: true, 
        align: PosAlign.center, 
        height: PosTextSize.size2, 
        width: PosTextSize.size2
      ));
    bytes += generator.text('KITCHEN ORDER TICKET', 
      styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text(dsep);

    // 2. Metadata: Table & Server / Date & Time
    final cleanUserName = kot.userName.trim().isNotEmpty ? kot.userName.trim() : 'Staff';
    bytes += generator.text(formatDualLine('TABLE: ${kot.tableName.toUpperCase()}', timeStr), styles: const PosStyles(bold: true));
    bytes += generator.text(formatDualLine('SERVER: $cleanUserName', dateStr));
    bytes += generator.text(sep);

    // 3. 3-Column Item Header
    final headerRow = fitCell('ITEMS', itemWidth) +
        fitCell('CAT', catWidth, alignCenter: true) +
        fitCell('QTY', qtyWidth, alignRight: true);
    bytes += generator.text(headerRow, styles: const PosStyles(bold: true));
    bytes += generator.text(sep);

    // 4. Items List with text wrapping
    for (var item in kot.items) {
      final itemLines = wrapText(item.name, itemWidth);
      final firstRow = fitCell(itemLines.first, itemWidth) +
          fitCell(item.category.isNotEmpty ? item.category : '-', catWidth, alignCenter: true) +
          fitCell('${item.qty}', qtyWidth, alignRight: true);
      bytes += generator.text(firstRow, styles: const PosStyles(bold: true));

      for (final extraLine in itemLines.skip(1)) {
        bytes += generator.text(fitCell(extraLine, itemWidth));
      }

      if (item.note.trim().isNotEmpty) {
        bytes += generator.text('  * Note: ${item.note.trim()}');
      }
      bytes += generator.text(sep);
    }
    
    bytes += generator.text(dsep);
    bytes += generator.feed(4);
    bytes += generator.cut();

    return bytes;
  }

  // Generate Bill ESC/POS commands
  Future<List<int>> generateBillBytes(BillModel bill, BranchModel branch, PrinterPaperSize paperSize) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(
      paperSize == PrinterPaperSize.mm80 ? PaperSize.mm80 : PaperSize.mm58, 
      profile
    );
    List<int> bytes = [];

    bytes += [0x1B, 0x40]; 
    bytes += [0x1D, 0x4C, 0x00, 0x00]; 

    // Configuration for 80mm vs 58mm
    // Standard 80mm Font A supports 48 chars (Font B 64 chars)
    final int maxChars = paperSize == PrinterPaperSize.mm80 ? 48 : 32;
    final String sep = '-' * maxChars;
    final String dsep = '=' * maxChars;

    // Fixed-width row formatter keeps the three columns stable on thermal printers.
    String fitCell(String text, int width, {bool alignRight = false, bool alignCenter = false}) {
      final normalized = text.length > width ? text.substring(0, width) : text;
      if (alignCenter) {
        final totalPad = width - normalized.length;
        final leftPad = totalPad ~/ 2;
        final rightPad = totalPad - leftPad;
        return (' ' * leftPad) + normalized + (' ' * rightPad);
      }
      return alignRight ? normalized.padLeft(width) : normalized.padRight(width);
    }

    List<String> wrapText(String text, int width) {
      if (text.isEmpty) return [''];

      final words = text.split(RegExp(r'\s+'));
      final lines = <String>[];
      var current = '';

      for (final word in words) {
        if (word.length > width) {
          if (current.isNotEmpty) {
            lines.add(current);
            current = '';
          }
          for (var i = 0; i < word.length; i += width) {
            final end = (i + width < word.length) ? i + width : word.length;
            lines.add(word.substring(i, end));
          }
          continue;
        }

        final candidate = current.isEmpty ? word : '$current $word';
        if (candidate.length <= width) {
          current = candidate;
        } else {
          lines.add(current);
          current = word;
        }
      }

      if (current.isNotEmpty) {
        lines.add(current);
      }

      return lines;
    }

    List<String> formatBillRow(String name, String qty, String amt) {
      // Relative width calculations: Item (60%), Qty (10%), Amount (30%)
      final int itemWidth = (maxChars * 0.6).floor();
      final int qtyWidth = (maxChars * 0.1).floor();
      final int amountWidth = maxChars - itemWidth - qtyWidth;
      final itemLines = wrapText(name, itemWidth);
      final formatted = <String>[
        fitCell(itemLines.first, itemWidth) +
            fitCell(qty, qtyWidth, alignCenter: true) +
            fitCell(amt, amountWidth, alignRight: true),
      ];

      for (final continuation in itemLines.skip(1)) {
        formatted.add(
          fitCell(continuation, itemWidth) +
              fitCell('', qtyWidth, alignCenter: true) +
              fitCell('', amountWidth, alignRight: true),
        );
      }

      return formatted;
    }

    String formatDualLine(String left, String right) {
      final maxLeft = (maxChars - right.length - 1).clamp(0, maxChars);
      final clippedLeft = left.length > maxLeft ? left.substring(0, maxLeft) : left;
      final spaces = maxChars - clippedLeft.length - right.length;
      return clippedLeft + (' ' * spaces) + right;
    }

    // 1. Branding Header
    bytes += generator.text(dsep);
    bytes += generator.text(branch.branchName.isNotEmpty ? branch.branchName.toUpperCase() : 'COFFEE KATTA', 
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += generator.text(branch.location.toUpperCase(), styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text(branch.address, styles: const PosStyles(align: PosAlign.center));
    if (branch.phone.isNotEmpty) {
      bytes += generator.text('Phone: ${branch.phone}', styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.text('RETAIL INVOICE', styles: const PosStyles(align: PosAlign.center, bold: true));
    if (bill.isVoided) {
      bytes += generator.text('*** CANCELLED / VOIDED INVOICE ***', styles: const PosStyles(align: PosAlign.center, bold: true));
      if (bill.voidReason != null && bill.voidReason!.isNotEmpty) {
        bytes += generator.text('REASON: ${bill.voidReason!.toUpperCase()}', styles: const PosStyles(align: PosAlign.center));
      }
    } else if (bill.printCount > 1) {
      bytes += generator.text('*** DUPLICATE COPY (#${bill.printCount}) ***', styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.feed(1);

    // 2. Metadata (Professional Layout)
    final dateStr = DateFormat('dd/MM/yy').format(bill.createdAt);
    final timeStr = DateFormat('hh:mm a').format(bill.createdAt);
    final printableUserName = bill.userName.trim().isNotEmpty
        ? bill.userName.trim()
        : (bill.lastPrintedBy?.trim().isNotEmpty == true ? bill.lastPrintedBy!.trim() : 'Staff');
    final shortUser =
        printableUserName.length > 14 ? printableUserName.substring(0, 14) : printableUserName;

    bytes += generator.text(formatDualLine('Bill: ${bill.billId}', dateStr));
    bytes += generator.text(formatDualLine('Table: ${bill.tableName.toUpperCase()}', timeStr));
    bytes += generator.text('By: $shortUser', styles: const PosStyles(bold: true));
    
    bytes += generator.text(sep);
    bytes += generator.text(
      formatBillRow('ITEMS', 'QTY', 'AMOUNT').first,
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text(sep);

    // 3. Items List
    for (var item in bill.items) {
      String itemName = item.name;
      for (final rowLine in formatBillRow(itemName, '${item.qty}', 'Rs ${ (item.price * item.qty).toStringAsFixed(0)}')) {
        bytes += generator.text(rowLine);
      }
      bytes += generator.text(sep);
    }

    // 4. Totals Logic
    String formatTotalLine(String label, String value) {
      return label.padRight(maxChars - value.length) + value;
    }

    bytes += generator.text(formatTotalLine('Subtotal', 'Rs. ${bill.subtotal.toStringAsFixed(2)}'));

    if (bill.discountAmount > 0) {
      final discountLabel = bill.discountType == 'flat'
          ? 'Discount (Flat)'
          : 'Discount (${bill.discountPercent.toStringAsFixed(0)}%)';
      bytes += generator.text(formatTotalLine(discountLabel, '-Rs. ${bill.discountAmount.toStringAsFixed(2)}'));
    }

    if (bill.extraCharges > 0) {
      bytes += generator.text(formatTotalLine('Extra Charges', '+Rs. ${bill.extraCharges.toStringAsFixed(2)}'));
    }

    bytes += generator.text(sep);
    
    // Total Amount (Medium emphasis, Right aligned)
    final String totalStr = 'Rs. ${bill.total.toStringAsFixed(2)}';
    bytes += generator.text('GRAND TOTAL'.padRight(maxChars - totalStr.length) + totalStr, 
        styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size1));
    
    // Payment Mode Breakdown (Split or Single)
    if (bill.payments.length > 1) {
      bytes += generator.text(sep);
      bytes += generator.text('PAID VIA (SPLIT):', styles: const PosStyles(bold: true));
      for (final p in bill.payments) {
        bytes += generator.text(formatDualLine('  ${p.mode.toUpperCase()}', 'Rs. ${p.amount.toStringAsFixed(2)}'));
      }
    } else if (bill.payments.isNotEmpty) {
      bytes += generator.text(formatDualLine('PAID VIA', bill.payments.first.mode.toUpperCase()));
    }

    bytes += generator.text(dsep);
    
    // 5. Footer (Side-by-Side QR & Branding)
    if (branch.reviewQrUrl.isNotEmpty || branch.instagramId.isNotEmpty) {
      bytes += generator.feed(1);
      try {
        final int imageWidth = paperSize == PrinterPaperSize.mm80 ? 512 : 384; // Leave margins
        final footerImg = await _generateFooterGraphic(branch, imageWidth);
        if (footerImg != null) {
          bytes += generator.image(footerImg);
        } else {
           bytes += generator.text('Visit Again!', styles: const PosStyles(align: PosAlign.center));
        }
      } catch (e) {
        bytes += generator.text('Visit Again!', styles: const PosStyles(align: PosAlign.center));
      }
    } else {
      bytes += generator.text('Visit Again!', styles: const PosStyles(align: PosAlign.center));
    }
    
    bytes += generator.text('THANK YOU', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text(dsep);
    bytes += generator.feed(4);
    bytes += generator.cut();
    
    return bytes;
  }

  /// Generates a comprehensive hardware diagnostic test ticket for Coffee Katta.
  Future<List<int>> generateDiagnosticTestBytes(
    PrinterConfig config, {
    String branchName = 'Coffee Katta — Latur Main',
    String userRole = 'Admin / Counter',
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(
      config.paperSize == PrinterPaperSize.mm80 ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );
    List<int> bytes = [];

    bytes += [0x1B, 0x40]; // Initialize
    bytes += [0x1D, 0x4C, 0x00, 0x00]; // Reset margin

    final int maxChars = config.paperSize == PrinterPaperSize.mm80 ? 48 : 32;
    final String sep = '-' * maxChars;
    final String dsep = '=' * maxChars;

    // Header
    bytes += generator.text(dsep);
    bytes += generator.text(
      'COFFEE KATTA',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      'PRINTER DIAGNOSTIC TEST',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(dsep);

    // Diagnostics Metadata
    final safeBranch = branchName.replaceAll('—', '-').replaceAll('–', '-').replaceAll('•', '-');
    final safeRole = userRole.replaceAll('—', '-').replaceAll('–', '-').replaceAll('•', '-').toUpperCase();
    final timeStr = DateFormat('dd/MM/yyyy - hh:mm a').format(DateTime.now());
    bytes += generator.text('Date & Time: $timeStr');
    bytes += generator.text('Branch:      $safeBranch');
    bytes += generator.text('Terminal:    $safeRole');
    bytes += generator.text(sep);

    // Hardware Configuration
    bytes += generator.text('HARDWARE CONFIGURATION:', styles: const PosStyles(bold: true));
    bytes += generator.text('Protocol:    ${config.connectionType.name.toUpperCase()}');
    bytes += generator.text('Target Addr: ${config.address ?? "Not set"}');
    if (config.connectionType == PrinterConnectionType.network) {
      bytes += generator.text('Network Port: ${config.port}');
    }
    bytes += generator.text('Paper Width: ${config.paperSize.name.toUpperCase()} ($maxChars cols)');
    bytes += generator.text('Auto KOT:    ${config.autoPrintKOT ? "ENABLED" : "DISABLED"}');
    bytes += generator.text('Auto Bill:   ${config.autoPrintBill ? "ENABLED" : "DISABLED"}');
    bytes += generator.text(sep);

    // Alignment & Column Test
    bytes += generator.text('ALIGNMENT TEST:', styles: const PosStyles(bold: true));
    bytes += generator.text('Left Aligned', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Center Aligned', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Right Aligned', styles: const PosStyles(align: PosAlign.right));
    bytes += generator.text(sep);

    // Text Style Tests
    bytes += generator.text('FONT FORMATTING TEST:', styles: const PosStyles(bold: true));
    bytes += generator.text('Normal Text: Coffee Katta POS');
    bytes += generator.text('Bold Text:   Coffee Katta POS', styles: const PosStyles(bold: true));
    bytes += generator.text(
      'Double Size',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(sep);

    // Footer & Auto-cut
    bytes += generator.text(
      'HARDWARE STATUS: ONLINE & READY',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(dsep);
    bytes += generator.feed(4);
    bytes += generator.cut();

    return bytes;
  }

  /// Generates the ESC/POS cash drawer kick pulse (RJ11/RJ12 Pin 2)
  List<int> getCashDrawerKickBytes() {
    return [0x1B, 0x70, 0x00, 0x19, 0xFA];
  }

  /// Sends a pulse to pop open the connected cash drawer
  Future<bool> openCashDrawer(PrinterConfig config) async {
    return await printReceipt(getCashDrawerKickBytes(), config);
  }

  // Master Print Function
  Future<bool> printReceipt(List<int> bytes, PrinterConfig config) async {
    // 1. Android RawBT Intent Launch
    if (config.connectionType == PrinterConnectionType.rawbt && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await sendToRawBT(bytes);
        return true;
      } catch (e) {
        return false;
      }
    }

    // 2. Direct raw TCP socket optimization for Network printers (LAN / WiFi)
    if (!kIsWeb &&
        config.connectionType == PrinterConnectionType.network &&
        config.address != null &&
        config.address!.trim().isNotEmpty) {
      try {
        final socket = await Socket.connect(
          config.address!.trim(),
          config.port,
          timeout: const Duration(seconds: 4),
        );
        socket.add(bytes);
        await socket.flush();
        await socket.close();
        return true;
      } catch (_) {
        // Fall through to PrinterManager if raw socket fails
      }
    }

    // 3. WINDOWS DESKTOP CRASH-PROOF SPOOLER:
    // On Windows, the third-party flutter_pos_printer_platform C++ plugin contains
    // fatal SEH memory bugs (dangling pointer to temporary wstring, std::bad_variant_access)
    // that abruptly terminate the entire Flutter Windows process (0xC0000005).
    // Bypassing it on Windows and routing directly to our Win32 RAW Spooler
    // guarantees 100% crash immunity, zero application shutdown, and reliable printing.
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || Platform.isWindows)) {
      String windowsTargetName = '';
      if (config.address != null &&
          config.address!.trim().isNotEmpty &&
          config.address != 'null:null') {
        windowsTargetName = config.address!.trim();
      } else if (config.name.trim().isNotEmpty && config.name.trim() != 'Default Printer') {
        windowsTargetName = config.name.trim();
      }

      // Fast Native Spooler (sub-millisecond, zero lag, direct Win32 winspool.drv with PnP hardware verification)
      return await WindowsRawPrinter.printBytes(bytes, printerName: windowsTargetName);
    }

    // 4. Mobile / Other Platforms: flutter_pos_printer_platform
    late PrinterType type;
    late BasePrinterInput model;

    switch (config.connectionType) {
      case PrinterConnectionType.usb:
      case PrinterConnectionType.rawbt:
        type = PrinterType.usb;
        // Android: Parse vendorId and productId
        String? vId;
        String? pId;
        if (config.address != null && config.address!.contains(':')) {
          final parts = config.address!.split(':');
          if (parts.length == 2 && parts[0] != 'null' && parts[1] != 'null') {
            vId = parts[0];
            pId = parts[1];
          }
        }
        model = UsbPrinterInput(
          name: config.name,
          vendorId: vId,
          productId: pId,
        );
        break;
      case PrinterConnectionType.network:
        type = PrinterType.network;
        model = TcpPrinterInput(
          ipAddress: config.address ?? '',
          port: config.port,
        );
        break;
      case PrinterConnectionType.bluetooth:
        type = PrinterType.bluetooth;
        model = BluetoothPrinterInput(
          name: config.name,
          address: config.address ?? '',
          isBle: config.isBle,
        );
        break;
    }

    try {
      // Connect to printer hardware
      final connected = await PrinterManager.instance.connect(
        type: type,
        model: model,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        return false;
      });

      if (!connected) return false;

      // Allow Bluetooth buffer handshake to settle
      if (type == PrinterType.bluetooth) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      final sent = await PrinterManager.instance.send(type: type, bytes: bytes);
      if (!sent) return false;
      
      // Short processing delay before disconnecting
      await Future.delayed(const Duration(milliseconds: 500));
      await PrinterManager.instance.disconnect(type: type);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Print via RawBT (Android)
  Future<void> sendToRawBT(List<int> bytes) async {
    try {
      final String base64Data = base64.encode(bytes);
      final String url = 'rawbt:base64,$base64Data';
      
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('Could not launch RawBT app. Is it installed?');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Generates a side-by-side footer graphic with a framed QR code and a warm message.
  Future<img.Image?> _generateFooterGraphic(BranchModel branch, int totalWidth) async {
    const double height = 196.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, totalWidth.toDouble(), height));
    
    // Background (White)
    final paint = ui.Paint()..color = Colors.white;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, totalWidth.toDouble(), height), paint);

    // 1. Left Side: Framed QR Code
    const double qrLabelHeight = 24.0;
    const double qrBoxSize = 144.0;
    final double qrX = 0.0;
    final double qrY = (height - (qrLabelHeight + qrBoxSize)) / 2;
    final double qrFrameHeight = qrLabelHeight + qrBoxSize;

    final effectiveQr = branch.reviewQrUrl.trim().isNotEmpty
        ? branch.reviewQrUrl.trim()
        : 'https://maps.app.goo.gl/fYjhMFxgoKpHxr1z5';

    if (effectiveQr.isNotEmpty) {
      // Solid white background for clear contrast
      final fillPaint = ui.Paint()..color = const Color(0xFFFFFFFF);
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(qrX, qrY, qrBoxSize, qrFrameHeight),
          const Radius.circular(8),
        ),
        fillPaint,
      );

      // Draw neat outer frame
      final framePaint = ui.Paint()
        ..color = Colors.black
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(qrX, qrY, qrBoxSize, qrFrameHeight),
          const Radius.circular(8),
        ),
        framePaint,
      );

      // Label above QR
      final textPainter = TextPainter(
        textDirection: ui.TextDirection.ltr,
        text: const TextSpan(
          text: 'REVIEW US',
          style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      )..layout();
      textPainter.paint(canvas, ui.Offset(qrX + (qrBoxSize - textPainter.width) / 2, qrY + 3));

      // Draw QR Code with Error Correction Level M for high scanning tolerance
      final qrValidationResult = QrValidator.validate(
        data: effectiveQr,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: true,
        );

        // Center QR inside box with solid quiet zone
        const double qrInnerPadding = 10.0;
        final double innerQrSize = qrBoxSize - (qrInnerPadding * 2);
        canvas.save();
        canvas.translate(qrX + qrInnerPadding, qrY + qrLabelHeight + 2);
        painter.paint(
          canvas,
          ui.Size(innerQrSize, innerQrSize),
        );
        canvas.restore();
      }
    }

    // 2. Right Side: Warm Message + Instagram
    final double textLeft = qrBoxSize + 16.0;
    final double textWidth = totalWidth - textLeft;

    const String warmMessage =
        "Loved your visit?\n"
        "Scan the QR to rate us and stay connected\n"
        "for great coffee and conversations at Coffee Katta.";
    
    // Message text
    final messagePainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: ui.TextAlign.left,
      text: const TextSpan(
        text: warmMessage,
        style: TextStyle(
          color: Colors.black,
          fontSize: 17,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
      ),
    )..layout(maxWidth: textWidth);
    messagePainter.paint(canvas, ui.Offset(textLeft, qrY + 8));

    // Instagram Handle
    if (branch.instagramId.trim().isNotEmpty) {
      final cleanIg = branch.instagramId.trim().replaceAll('@', '');
      final igPainter = TextPainter(
        textDirection: ui.TextDirection.ltr,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Instagram: @$cleanIg',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      )..layout(maxWidth: textWidth);
      final double igTop = qrY + messagePainter.height + 14;
      igPainter.paint(canvas, ui.Offset(textLeft, igTop));
    }

    // Convert to Image
    final picture = recorder.endRecording();
    final imgUi = await picture.toImage(totalWidth, height.toInt());
    final byteData = await imgUi.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData == null) return null;
    
    // Decode into 'image' package format for esc_pos_utils
    final decoded = img.decodePng(byteData.buffer.asUint8List());
    return decoded;
  }

  /// Prints a PDF document to a thermal printer by rasterizing it into images and adding a cut command.
  Future<bool> printPdfAsImage(Uint8List pdfBytes, PrinterConfig config) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(
      config.paperSize == PrinterPaperSize.mm80 ? PaperSize.mm80 : PaperSize.mm58,
      profile
    );
    List<int> bytes = [];
    
    // Initialize
    bytes += [0x1B, 0x40]; 
    bytes += [0x1D, 0x4C, 0x00, 0x00];

    // Configuration for 80mm vs 58mm
    final int imageWidth = config.paperSize == PrinterPaperSize.mm80 ? 512 : 384;

    try {
      // Use printing package to rasterize PDF
      await for (var page in Printing.raster(pdfBytes, dpi: 200)) {
        final pngBytes = await page.toPng();
        final decodedImage = img.decodePng(pngBytes);
        if (decodedImage != null) {
          // Resize image to fit paper width if necessary
          final resizedImage = decodedImage.width != imageWidth 
              ? img.copyResize(decodedImage, width: imageWidth)
              : decodedImage;
          bytes += generator.image(resizedImage);
        }
      }
      
      bytes += generator.feed(2);
      bytes += generator.cut();
      
      return await printReceipt(bytes, config);
    } catch (e) {
      return false;
    }
  }
}
