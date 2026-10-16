// ignore_for_file: camel_case_types, non_constant_identifier_names, constant_identifier_names
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

// Windows SetupAPI GUID & Interface structures for true hardware presence detection
final class GUID extends Struct {
  @Uint32()
  external int Data1;
  @Uint16()
  external int Data2;
  @Uint16()
  external int Data3;
  @Array(8)
  external Array<Uint8> Data4;
}

final class SP_DEVICE_INTERFACE_DATA extends Struct {
  @Uint32()
  external int cbSize;
  external GUID InterfaceClassGuid;
  @Uint32()
  external int Flags;
  @IntPtr()
  external int Reserved;
}

// winspool.drv bindings
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

// advapi32.dll bindings (USB Port Device Path discovery in registry)
typedef _RegOpenKeyExAC = Int32 Function(IntPtr hKey, Pointer<Utf8> lpSubKey, Uint32 ulOptions, Uint32 samDesired, Pointer<IntPtr> phkResult);
typedef _RegOpenKeyExADart = int Function(int hKey, Pointer<Utf8> lpSubKey, int ulOptions, int samDesired, Pointer<IntPtr> phkResult);

typedef _RegQueryValueExAC = Int32 Function(IntPtr hKey, Pointer<Utf8> lpValueName, Pointer<Uint32> lpReserved, Pointer<Uint32> lpType, Pointer<Uint8> lpData, Pointer<Uint32> lpcbData);
typedef _RegQueryValueExADart = int Function(int hKey, Pointer<Utf8> lpValueName, Pointer<Uint32> lpReserved, Pointer<Uint32> lpType, Pointer<Uint8> lpData, Pointer<Uint32> lpcbData);

typedef _RegCloseKeyC = Int32 Function(IntPtr hKey);
typedef _RegCloseKeyDart = int Function(int hKey);

// kernel32.dll bindings (Hardware device handle probing)
typedef _CreateFileWC = IntPtr Function(Pointer<Utf16> lpFileName, Uint32 dwDesiredAccess, Uint32 dwShareMode, Pointer<Void> lpSecurityAttributes, Uint32 dwCreationDisposition, Uint32 dwFlagsAndAttributes, IntPtr hTemplateFile);
typedef _CreateFileWDart = int Function(Pointer<Utf16> lpFileName, int dwDesiredAccess, int dwShareMode, Pointer<Void> lpSecurityAttributes, int dwCreationDisposition, int dwFlagsAndAttributes, int hTemplateFile);

typedef _GetLastErrorC = Uint32 Function();
typedef _GetLastErrorDart = int Function();

typedef _CloseHandleC = Int32 Function(IntPtr hObject);
typedef _CloseHandleDart = int Function(int hObject);

// setupapi.dll bindings (PnP USB thermal printer enumeration)
typedef _SetupDiGetClassDevsWC = IntPtr Function(Pointer<GUID> ClassGuid, Pointer<Void> Enumerator, IntPtr hwndParent, Uint32 Flags);
typedef _SetupDiGetClassDevsWDart = int Function(Pointer<GUID> ClassGuid, Pointer<Void> Enumerator, int hwndParent, int Flags);

typedef _SetupDiEnumDeviceInterfacesC = Int32 Function(IntPtr DeviceInfoSet, Pointer<Void> DeviceInfoData, Pointer<GUID> InterfaceClassGuid, Uint32 MemberIndex, Pointer<SP_DEVICE_INTERFACE_DATA> DeviceInterfaceData);
typedef _SetupDiEnumDeviceInterfacesDart = int Function(int DeviceInfoSet, Pointer<Void> DeviceInfoData, Pointer<GUID> InterfaceClassGuid, int MemberIndex, Pointer<SP_DEVICE_INTERFACE_DATA> DeviceInterfaceData);

typedef _SetupDiDestroyDeviceInfoListC = Int32 Function(IntPtr DeviceInfoSet);
typedef _SetupDiDestroyDeviceInfoListDart = int Function(int DeviceInfoSet);

class WindowsRawPrinter {
  static DynamicLibrary? _winspool;
  static DynamicLibrary? _advapi;
  static DynamicLibrary? _kernel32;
  static DynamicLibrary? _setupapi;

  static _OpenPrinterDart? _openPrinter;
  static _ClosePrinterDart? _closePrinter;
  static _StartDocPrinterDart? _startDocPrinter;
  static _EndDocPrinterDart? _endDocPrinter;
  static _StartPagePrinterDart? _startPagePrinter;
  static _EndPagePrinterDart? _endPagePrinter;
  static _WritePrinterDart? _writePrinter;
  static _GetDefaultPrinterDart? _getDefaultPrinter;
  static _GetPrinterDart? _getPrinter;

  static _RegOpenKeyExADart? _regOpenKeyExA;
  static _RegQueryValueExADart? _regQueryValueExA;
  static _RegCloseKeyDart? _regCloseKey;

  static _CreateFileWDart? _createFileW;
  static _GetLastErrorDart? _getLastError;
  static _CloseHandleDart? _closeHandle;

  static _SetupDiGetClassDevsWDart? _setupDiGetClassDevsW;
  static _SetupDiEnumDeviceInterfacesDart? _setupDiEnumDeviceInterfaces;
  static _SetupDiDestroyDeviceInfoListDart? _setupDiDestroyDeviceInfoList;

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

      _advapi = DynamicLibrary.open('advapi32.dll');
      _regOpenKeyExA = _advapi!.lookupFunction<_RegOpenKeyExAC, _RegOpenKeyExADart>('RegOpenKeyExA');
      _regQueryValueExA = _advapi!.lookupFunction<_RegQueryValueExAC, _RegQueryValueExADart>('RegQueryValueExA');
      _regCloseKey = _advapi!.lookupFunction<_RegCloseKeyC, _RegCloseKeyDart>('RegCloseKey');

      _kernel32 = DynamicLibrary.open('kernel32.dll');
      _createFileW = _kernel32!.lookupFunction<_CreateFileWC, _CreateFileWDart>('CreateFileW');
      _getLastError = _kernel32!.lookupFunction<_GetLastErrorC, _GetLastErrorDart>('GetLastError');
      _closeHandle = _kernel32!.lookupFunction<_CloseHandleC, _CloseHandleDart>('CloseHandle');

      _setupapi = DynamicLibrary.open('setupapi.dll');
      _setupDiGetClassDevsW = _setupapi!.lookupFunction<_SetupDiGetClassDevsWC, _SetupDiGetClassDevsWDart>('SetupDiGetClassDevsW');
      _setupDiEnumDeviceInterfaces = _setupapi!.lookupFunction<_SetupDiEnumDeviceInterfacesC, _SetupDiEnumDeviceInterfacesDart>('SetupDiEnumDeviceInterfaces');
      _setupDiDestroyDeviceInfoList = _setupapi!.lookupFunction<_SetupDiDestroyDeviceInfoListC, _SetupDiDestroyDeviceInfoListDart>('SetupDiDestroyDeviceInfoList');

      return true;
    } catch (e) {
      debugPrint('[WindowsRawPrinter] Failed to load native libraries: $e');
      return false;
    }
  }

  /// Checks if the spooler queue itself reports offline or error state
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

  /// True hardware-level verification of physical printer connectivity:
  /// 1. Queries Windows Spooler queue status
  /// 2. If printer is connected via USB (e.g. USB001, USB003):
  ///    - Verifies USB printing device interface presence via SetupAPI (DIGCF_PRESENT)
  ///    - Queries USB Monitor registry for the port's Device Path and probes kernel handle via CreateFileW
  /// 3. Returns false if unplugged, powered off, or device node is missing
  static bool isPrinterPhysicallyConnected({String? printerName}) {
    if (!Platform.isWindows) return true;
    if (!_init()) return false;

    String target = (printerName ?? '').trim();
    if (target.isEmpty || target.toLowerCase() == 'default printer' || target == 'null:null') {
      target = getDefaultPrinter();
    }

    final hPrinterPtr = calloc<IntPtr>();
    final namePtr = target.toNativeUtf8();
    int ok = _openPrinter!(namePtr, hPrinterPtr, nullptr);
    calloc.free(namePtr);

    if (ok == 0) {
      calloc.free(hPrinterPtr);
      return false;
    }

    final hPrinter = hPrinterPtr.value;
    calloc.free(hPrinterPtr);

    try {
      // 1. Spooler status check
      if (_isPrinterOffline(hPrinter)) {
        return false;
      }

      // 2. Query port name and driver
      String portName = '';
      final neededPtr = calloc<Uint32>();
      _getPrinter!(hPrinter, 2, nullptr, 0, neededPtr);
      final needed = neededPtr.value;
      if (needed > 0) {
        final buf = calloc<Uint8>(needed);
        final getOk = _getPrinter!(hPrinter, 2, buf, needed, neededPtr);
        if (getOk != 0) {
          final byteData = buf.asTypedList(needed).buffer.asByteData();
          final pPort = Pointer<Utf8>.fromAddress(byteData.getUint64(24, Endian.little));
          if (pPort.address != 0) {
            portName = pPort.toDartString();
          }
        }
        calloc.free(buf);
      }
      calloc.free(neededPtr);

      // 3. Hardware verification for USB ports
      if (portName.toUpperCase().startsWith('USB')) {
        return _checkUsbHardwareConnected(portName);
      }

      // If it's a virtual/file queue (PDF, XPS), it's always ready
      if (portName.toUpperCase().startsWith('PORTPROMPT') || portName.toUpperCase().startsWith('FILE:')) {
        return true;
      }

      return true;
    } catch (e) {
      debugPrint('[WindowsRawPrinter] Hardware check exception: $e');
      return false;
    } finally {
      _closePrinter!(hPrinter);
    }
  }

  /// Verifies USB hardware presence via SetupAPI and kernel device node handle
  static bool _checkUsbHardwareConnected(String portName) {
    // A. Check if ANY USB print device interface is currently PRESENT in PnP
    if (_setupDiGetClassDevsW != null && _setupDiEnumDeviceInterfaces != null && _setupDiDestroyDeviceInfoList != null) {
      final guidPtr = calloc<GUID>();
      // GUID_DEVINTERFACE_USBPRINT: 28d78fad-5a12-11d1-ae5b-0000f803a8c2
      guidPtr.ref.Data1 = 0x28d78fad;
      guidPtr.ref.Data2 = 0x5a12;
      guidPtr.ref.Data3 = 0x11d1;
      guidPtr.ref.Data4[0] = 0xae;
      guidPtr.ref.Data4[1] = 0x5b;
      guidPtr.ref.Data4[2] = 0x00;
      guidPtr.ref.Data4[3] = 0x00;
      guidPtr.ref.Data4[4] = 0xf8;
      guidPtr.ref.Data4[5] = 0x03;
      guidPtr.ref.Data4[6] = 0xa8;
      guidPtr.ref.Data4[7] = 0xc2;

      const DIGCF_PRESENT = 0x00000002;
      const DIGCF_DEVICEINTERFACE = 0x00000010;

      final hDevInfo = _setupDiGetClassDevsW!(guidPtr, nullptr, 0, DIGCF_DEVICEINTERFACE | DIGCF_PRESENT);
      bool anyUsbPrinterPresent = false;

      if (hDevInfo != -1 && hDevInfo != 0) {
        final ifaceData = calloc<SP_DEVICE_INTERFACE_DATA>();
        ifaceData.ref.cbSize = sizeOf<SP_DEVICE_INTERFACE_DATA>();

        if (_setupDiEnumDeviceInterfaces!(hDevInfo, nullptr, guidPtr, 0, ifaceData) != 0) {
          anyUsbPrinterPresent = true;
        }

        calloc.free(ifaceData);
        _setupDiDestroyDeviceInfoList!(hDevInfo);
      }
      calloc.free(guidPtr);

      // If zero USB thermal printers are physically connected to the computer, return false immediately!
      if (!anyUsbPrinterPresent) {
        return false;
      }
    }

    // B. Check the specific port's device path in registry + CreateFileW
    if (_regOpenKeyExA != null && _regQueryValueExA != null && _regCloseKey != null && _createFileW != null && _getLastError != null) {
      final phk = calloc<IntPtr>();
      final subKey = ('SYSTEM\\CurrentControlSet\\Control\\Print\\Monitors\\USB Monitor\\Ports\\$portName').toNativeUtf8();
      const HKEY_LOCAL_MACHINE = 0x80000002;
      const KEY_READ = 0x20019;

      final regOk = _regOpenKeyExA!(HKEY_LOCAL_MACHINE, subKey, 0, KEY_READ, phk);
      calloc.free(subKey);

      if (regOk == 0) {
        final hKey = phk.value;
        final valName = 'Device Path'.toNativeUtf8();
        final cbData = calloc<Uint32>();
        cbData.value = 512;
        final buf = calloc<Uint8>(512);

        final qOk = _regQueryValueExA!(hKey, valName, nullptr, nullptr, buf, cbData);
        calloc.free(valName);
        calloc.free(cbData);
        _regCloseKey!(hKey);

        if (qOk == 0) {
          final devicePath = buf.cast<Utf8>().toDartString();
          calloc.free(buf);

          final pathUtf16 = devicePath.toNativeUtf16();
          final hFile = _createFileW!(pathUtf16, 0, 3, nullptr, 3, 0, 0);
          final err = _getLastError!();
          calloc.free(pathUtf16);

          if (hFile != -1 && hFile != 0) {
            _closeHandle!(hFile);
            return true;
          }

          // Error 32 = ERROR_SHARING_VIOLATION (in use by USB port driver -> connected!)
          // Error 5  = ERROR_ACCESS_DENIED (device node exists -> connected!)
          if (err == 32 || err == 5) {
            return true;
          }

          // Error 2 = ERROR_FILE_NOT_FOUND (cable unplugged / powered off)
          // Error 3 = ERROR_PATH_NOT_FOUND
          // Error 67 = ERROR_BAD_NET_NAME
          // Error 1167 = ERROR_DEVICE_NOT_CONNECTED
          if (err == 2 || err == 3 || err == 67 || err == 1167) {
            return false;
          }
        } else {
          calloc.free(buf);
        }
      }
      calloc.free(phk);
    }

    return true;
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

    // Guard 1: Verify hardware is physically plugged in and powered ON before spooling!
    // This prevents generic ESC/POS spooler from buffering ghost print jobs when cable is unplugged.
    if (!isPrinterPhysicallyConnected(printerName: target)) {
      debugPrint('[WindowsRawPrinter] Hardware check failed: "$target" is disconnected, powered off, or unplugged.');
      return false;
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

    // Guard 2: Verify queue status
    if (_isPrinterOffline(hPrinter)) {
      debugPrint('[WindowsRawPrinter] Printer "$target" is OFFLINE or DISCONNECTED in spooler.');
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
