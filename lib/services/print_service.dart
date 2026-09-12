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

    // Configuration for 80mm vs 58mm
    // Modern 80mm printers usually support up to 64 chars (Font B)
    final int maxChars = paperSize == PrinterPaperSize.mm80 ? 64 : 32;
    
    // Helper for manual rows (C1: Items, C2: Category, C3: Qty)
    String formatKOTRow(String c1, String c2, String c3) {
      // Relative width calculations: Item (60%), Category (25%), Qty (15%)
      int w1 = (maxChars * 0.6).floor(); 
      int w2 = (maxChars * 0.25).floor(); 
      int w3 = maxChars - w1 - w2 - 4; // Subtracting 4 for gaps
      
      String s1 = c1.padRight(w1).substring(0, w1);
      String s2 = c2.padRight(w2).substring(0, w2);
      String s3 = c3.padLeft(w3).substring(0, w3);
      
      return "$s1  $s2  $s3"; 
    }

    final String sep = '-' * maxChars;
    final String dsep = '=' * maxChars;

    // 1. Header: Large Bold KOT Number
    final String timeStr = DateFormat('hh:mm a').format(kot.createdAt);
    bytes += generator.text(dsep); // Top divider
    bytes += generator.text('KOT #${kot.kotNumber}', 
      styles: const PosStyles(
        bold: true, 
        align: PosAlign.center, 
        height: PosTextSize.size2, 
        width: PosTextSize.size2
      ));
    
    bytes += generator.feed(1);

    // Header Info: Consolidated into ONE line (Table | Time | By)
    final String cleanUserName = kot.userName.isEmpty ? 'Staff' : kot.userName;
    final String printerBy = "by:${cleanUserName.length > 5 ? cleanUserName.substring(0, 5) : cleanUserName}".toLowerCase();
    
    String timeAndBy = "$timeStr           $printerBy"; 
    String tableInfo = ': ${kot.tableName.toString().toUpperCase()}           ';
    
    String headerLine = tableInfo.padRight(maxChars - timeAndBy.length) + timeAndBy;
    bytes += generator.text(headerLine, styles: const PosStyles(bold: true));

    bytes += generator.text(sep);

    // 3-Column Item Header
    bytes += generator.text(formatKOTRow('ITEMS', 'CAT', 'QTY'), styles: const PosStyles(bold: true));
    bytes += generator.text(sep);

    for (var item in kot.items) {
      bytes += generator.text(formatKOTRow(item.name, item.category, '${item.qty}'));
      
      if (item.note.isNotEmpty) {
        bytes += generator.text('  note: ${item.note.toLowerCase()}');
      }
      bytes += generator.text(sep); // Separator between each KOT item
    }
    
    bytes += generator.text(dsep); // Closing divider
    bytes += generator.feed(2);
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
    // Modern 80mm printers usually support up to 64 chars (Font B) or 48 (Font A)
    // Using 64 to ensure full-width utilization on standard 80mm rolls.
    final int maxChars = paperSize == PrinterPaperSize.mm80 ? 64 : 32;
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

    // 3. Items List (with Category prefix)
    for (var item in bill.items) {
      String itemName = item.category.isNotEmpty ? "[${item.category.toUpperCase()}] ${item.name}" : item.name;
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
    bytes += generator.feed(2);
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

    final int maxChars = config.paperSize == PrinterPaperSize.mm80 ? 64 : 32;
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
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  // Master Print Function
  Future<bool> printReceipt(List<int> bytes, PrinterConfig config) async {
    if (config.connectionType == PrinterConnectionType.rawbt && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await sendToRawBT(bytes);
        return true; // Sent to external app successfully
      } catch (e) {
        return false;
      }
    }

    // Direct raw TCP socket optimization for Network printers
    // Pure Dart socket communicates directly with WiFi/Ethernet thermal printers across Windows & Android
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

    // Direct Printing via flutter_pos_printer_platform
    late PrinterType type;
    late BasePrinterInput model;

    switch (config.connectionType) {
      case PrinterConnectionType.usb:
        type = PrinterType.usb;
        model = UsbPrinterInput(
          name: config.address ?? 'USB Printer',
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
      case PrinterConnectionType.rawbt:
        return false;
    }

    try {
      // Use a timeout for connection
      final connected = await PrinterManager.instance.connect(
        type: type,
        model: model,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        return false;
      });

      if (!connected) {
        return false;
      }

      // Give Bluetooth printers a moment to initialize after connection
      if (type == PrinterType.bluetooth) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      final sent = await PrinterManager.instance.send(type: type, bytes: bytes);
      
      if (!sent) {
        return false;
      }
      
      // Short delay for some printers to finish processing before disconnect
      await Future.delayed(const Duration(milliseconds: 500));
      
      await PrinterManager.instance.disconnect(type: type);
      return true;
    } catch (e) {
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
    const double qrBorderPadding = 8.0;
    final double qrX = 0.0;
    final double qrY = (height - (qrLabelHeight + qrBoxSize)) / 2;
    final double qrFrameHeight = qrLabelHeight + qrBoxSize;

    if (branch.reviewQrUrl.isNotEmpty) {
      // Draw bold frame
      final framePaint = ui.Paint()
        ..color = Colors.black
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.4;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(qrX, qrY, qrBoxSize, qrFrameHeight),
          const Radius.circular(10),
        ),
        framePaint
      );

      // Label above QR
      final textPainter = TextPainter(
        textDirection: ui.TextDirection.ltr,
        text: const TextSpan(
          text: 'REVIEW US',
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900),
        ),
      )..layout();
      textPainter.paint(canvas, ui.Offset(qrX + (qrBoxSize - textPainter.width) / 2, qrY + 2));

      // Draw QR Code
      final qrValidationResult = QrValidator.validate(
        data: branch.reviewQrUrl,
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
        
        // Draw centered inside the box with tight padding so the block sits flush-left.
        canvas.save();
        canvas.translate(qrX + qrBorderPadding, qrY + qrLabelHeight + qrBorderPadding);
        painter.paint(
          canvas,
          const ui.Size(qrBoxSize - qrBorderPadding * 2, qrBoxSize - qrBorderPadding * 2),
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
    if (branch.instagramId.isNotEmpty) {
      final igPainter = TextPainter(
        textDirection: ui.TextDirection.ltr,
        text: TextSpan(
          children: [
            TextSpan(
              text: '@${branch.instagramId}',
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
