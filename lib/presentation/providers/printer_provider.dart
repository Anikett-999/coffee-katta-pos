import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart' as printing;
import '../../domain/models/printer_config.dart';
import '../../services/print_service.dart';

final printServiceProvider = Provider<PrintService>((ref) => PrintService());

/// Discovered OS-level printers (e.g. Windows USB/Network driver printers)
final systemPrintersProvider = FutureProvider<List<printing.Printer>>((ref) async {
  try {
    return await printing.Printing.listPrinters();
  } catch (e) {
    return [];
  }
});

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize this in main.dart');
});

final printerConfigProvider = StateNotifierProvider<PrinterSettingsNotifier, PrinterConfig>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return PrinterSettingsNotifier(prefs);
});

class PrinterSettingsNotifier extends StateNotifier<PrinterConfig> {
  final SharedPreferences _prefs;
  static const String _key = 'printer_settings_config';

  PrinterSettingsNotifier(this._prefs) : super(const PrinterConfig()) {
    _loadSettings();
  }

  void _loadSettings() {
    final String? jsonStr = _prefs.getString(_key);
    if (jsonStr != null) {
      try {
        state = PrinterConfig.fromJson(json.decode(jsonStr));
      } catch (e) {
        // Fallback to default if error
      }
    }
  }

  Future<void> updateConfig(PrinterConfig newConfig) async {
    state = newConfig;
    await _prefs.setString(_key, json.encode(newConfig.toJson()));
  }

  Future<void> updateConnectionType(PrinterConnectionType type) async {
    await updateConfig(state.copyWith(connectionType: type));
  }

  Future<void> updatePaperSize(PrinterPaperSize size) async {
    await updateConfig(state.copyWith(paperSize: size));
  }

  Future<void> updateAddress(String address) async {
    await updateConfig(state.copyWith(address: address));
  }

  Future<void> updateName(String name) async {
    await updateConfig(state.copyWith(name: name));
  }

  Future<void> toggleAutoKOT(bool value) async {
    await updateConfig(state.copyWith(autoPrintKOT: value));
  }

  Future<void> toggleAutoBill(bool value) async {
    await updateConfig(state.copyWith(autoPrintBill: value));
  }

  Future<void> toggleBle(bool value) async {
    await updateConfig(state.copyWith(isBle: value));
  }
}
