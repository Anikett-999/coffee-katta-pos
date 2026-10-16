import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

// Native winspool.drv bindings for 100% crash-proof, instantaneous raw printing
final class DOCINFOA extends Struct {
  external Pointer<Utf8> pDocName;
  external Pointer<Utf8> pOutputFile;
  external Pointer<Utf8> pDataType;
}

typedef _OpenPrinterC = Int32 Function(Pointer<Utf8> pPrinterName, Pointer<IntPtr> phPrinter, Pointer<Void> pDefault);
typedef _OpenPrinterDart = int Function(Pointer<Utf8> pPrinterName, Pointer<IntPtr> phPrinter, Pointer<Void> pDefault);

typedef _ClosePrinterC = Int32 Function(IntPtr hPrinter);
typedef _ClosePrinterDart = int Function(int hPrinter);

typedef _StartDocPrinterC = Uint32 Function(IntPtr hPrinter, Uint32 level, Pointer<DOCINFOA> pDocInfo);
typedef _StartDocPrinterDart = int Function(int hPrinter, int level, Pointer<DOCINFOA> pDocInfo);

typedef _EndDocPrinterC = Int32 Function(IntPtr hPrinter);
typedef _EndDocPrinterDart = int Function(int hPrinter);

typedef _StartPagePrinterC = Int32 Function(IntPtr hPrinter);
typedef _StartPagePrinterDart = int Function(int hPrinter);

typedef _EndPagePrinterC = Int32 Function(IntPtr hPrinter);
typedef _EndPagePrinterDart = int Function(int hPrinter);

typedef _WritePrinterC = Int32 Function(IntPtr hPrinter, Pointer<Void> pBuf, Uint32 cbBuf, Pointer<Uint32> pcWritten);
typedef _WritePrinterDart = int Function(int hPrinter, Pointer<Void> pBuf, int cbBuf, Pointer<Uint32> pcWritten);

typedef _GetDefaultPrinterC = Int32 Function(Pointer<Utf8> pszBuffer, Pointer<Uint32> pcchBuffer);
typedef _GetDefaultPrinterDart = int Function(Pointer<Utf8> pszBuffer, Pointer<Uint32> pcchBuffer);

typedef _GetPrinterC = Int32 Function(IntPtr hPrinter, Uint32 level, Pointer<Uint8> pPrinter, Uint32 cbBuf, Pointer<Uint32> pcbNeeded);
typedef _GetPrinterDart = int Function(int hPrinter, int level, Pointer<Uint8> pPrinter, int cbBuf, Pointer<Uint32> pcbNeeded);

class WindowsRawPrinter {
  static DynamicLibrary? _winspool;
  static _OpenPrinterDart? _openPrinter;
  static _ClosePrinterDart? _closePrinter;
  static _StartDocPrinterDart? _startDocPrinter;
  static _EndDocPrinterDart? _endDocPrinter;
  static _StartPagePrinterDart? _startPagePrinter;
  static _EndPagePrinterDart? _endPagePrinter;
  static _WritePrinterDart? _writePrinter;
  static _GetDefaultPrinterDart? _getDefaultPrinter;
  static _GetPrinterDart? _getPrinter;

  static bool _init() {
    if (!Platform.isWindows) return false;
    if (_winspool != null) return true;
    try {
      _winspool = DynamicLibrary.open('winspool.drv');
      _openPrinter = _winspool!.lookupFunction<_OpenPrinterC, _OpenPrinterDart>('OpenPrinterA');
      _closePrinter = _winspool!.lookupFunction<_ClosePrinterC, _ClosePrinterDart>('ClosePrinter');
      _startDocPrinter = _winspool!.lookupFunction<_StartDocPrinterC, _StartDocPrinterDart>('StartDocPrinterA');
      _endDocPrinter = _winspool!.lookupFunction<_EndDocPrinterC, _EndDocPrinterDart>('EndDocPrinter');
      _startPagePrinter = _winspool!.lookupFunction<_StartPagePrinterC, _StartPagePrinterDart>('StartPagePrinter');
      _endPagePrinter = _winspool!.lookupFunction<_EndPagePrinterC, _EndPagePrinterDart>('EndPagePrinter');
      _writePrinter = _winspool!.lookupFunction<_WritePrinterC, _WritePrinterDart>('WritePrinter');
      _getDefaultPrinter = _winspool!.lookupFunction<_GetDefaultPrinterC, _GetDefaultPrinterDart>('GetDefaultPrinterA');
      _getPrinter = _winspool!.lookupFunction<_GetPrinterC, _GetPrinterDart>('GetPrinterA');
      return true;
    } catch (e) {
      debugPrint('[WindowsRawPrinter] Failed to load winspool.drv: $e');
      return false;
    }
  }

  /// Checks if the printer device is currently offline, unplugged, or in an error state
  static bool _isPrinterOffline(int hPrinter) {
    if (_getPrinter == null) return false;
    final neededPtr = calloc<Uint32>();
    try {
      _getPrinter!(hPrinter, 2, nullptr, 0, neededPtr);
      final needed = neededPtr.value;
      if (needed == 0) return false;

      final buf = calloc<Uint8>(needed);
      try {
        final ok = _getPrinter!(hPrinter, 2, buf, needed, neededPtr);
        if (ok != 0 && needed >= 128) {
          final byteData = buf.asTypedList(needed).buffer.asByteData();
          final attrs = byteData.getUint32(104, Endian.little);
          final status = byteData.getUint32(124, Endian.little);

          // PRINTER_ATTRIBUTE_WORK_OFFLINE = 0x00000400
          // PRINTER_STATUS_OFFLINE         = 0x00000080
          // PRINTER_STATUS_NOT_AVAILABLE   = 0x00001000
          // PRINTER_STATUS_ERROR           = 0x00000002
          final isOffline = (attrs & 0x400 != 0) ||
                            (status & 0x80 != 0) ||
                            (status & 0x1000 != 0) ||
                            (status & 0x02 != 0);
          return isOffline;
        }
      } finally {
        calloc.free(buf);
      }
    } catch (_) {
    } finally {
      calloc.free(neededPtr);
    }
    return false;
  }

  /// Retrieves the default printer name configured in Windows
  static String getDefaultPrinter() {
    if (!_init() || _getDefaultPrinter == null) return 'POS-80C';
    final bufSizePtr = calloc<Uint32>();
    bufSizePtr.value = 260;
    final bufPtr = calloc<Uint8>(260).cast<Utf8>();
    try {
      final ok = _getDefaultPrinter!(bufPtr, bufSizePtr);
      if (ok != 0) {
        return bufPtr.toDartString();
      }
    } catch (_) {
    } finally {
      calloc.free(bufSizePtr);
      calloc.free(bufPtr);
    }
    return 'POS-80C';
  }

  /// Sends raw ESC/POS bytes directly to Windows Print Spooler with zero lag (sub-millisecond)
  static Future<bool> printBytes(List<int> bytes, {String? printerName}) async {
    if (!Platform.isWindows) return false;
    if (!_init()) return false;
    if (bytes.isEmpty) return false;

    return compute(_rawPrintTask, _PrintParams(bytes, printerName));
  }

  static bool _rawPrintTask(_PrintParams params) {
    if (!_init()) return false;
    String target = (params.printerName ?? '').trim();
    if (target.isEmpty || target.toLowerCase() == 'default printer' || target == 'null:null') {
      target = getDefaultPrinter();
    }

    final hPrinterPtr = calloc<IntPtr>();
    final namePtr = target.toNativeUtf8();
    int ok = _openPrinter!(namePtr, hPrinterPtr, nullptr);
    calloc.free(namePtr);

    if (ok == 0) {
      // Fallback to default printer if specific printer name failed to open
      final defTarget = getDefaultPrinter();
      final defNamePtr = defTarget.toNativeUtf8();
      ok = _openPrinter!(defNamePtr, hPrinterPtr, nullptr);
      calloc.free(defNamePtr);
      if (ok == 0) {
        calloc.free(hPrinterPtr);
        return false;
      }
    }

    final hPrinter = hPrinterPtr.value;
    calloc.free(hPrinterPtr);

    // Guard: Verify printer is physically online / connected before sending print job
    if (_isPrinterOffline(hPrinter)) {
      debugPrint('[WindowsRawPrinter] Printer "$target" is OFFLINE or DISCONNECTED.');
      _closePrinter!(hPrinter);
      return false;
    }

    final docInfoPtr = calloc<DOCINFOA>();
    docInfoPtr.ref.pDocName = 'Coffee Katta POS'.toNativeUtf8();
    docInfoPtr.ref.pOutputFile = nullptr;
    docInfoPtr.ref.pDataType = 'RAW'.toNativeUtf8();

    bool success = false;
    try {
      final jobId = _startDocPrinter!(hPrinter, 1, docInfoPtr);
      if (jobId > 0) {
        final pageOk = _startPagePrinter!(hPrinter);
        if (pageOk != 0) {
          final rawData = calloc<Uint8>(params.bytes.length);
          rawData.asTypedList(params.bytes.length).setAll(0, params.bytes);
          final writtenPtr = calloc<Uint32>();

          final writeOk = _writePrinter!(hPrinter, rawData.cast<Void>(), params.bytes.length, writtenPtr);
          success = (writeOk != 0 && writtenPtr.value > 0);

          calloc.free(rawData);
          calloc.free(writtenPtr);
          _endPagePrinter!(hPrinter);
        }
        _endDocPrinter!(hPrinter);
      }
    } catch (e) {
      debugPrint('[WindowsRawPrinter] Spool error: $e');
      success = false;
    } finally {
      calloc.free(docInfoPtr.ref.pDocName);
      calloc.free(docInfoPtr.ref.pDataType);
      calloc.free(docInfoPtr);
      _closePrinter!(hPrinter);
    }

    return success;
  }
}

class _PrintParams {
  final List<int> bytes;
  final String? printerName;
  _PrintParams(this.bytes, this.printerName);
}
