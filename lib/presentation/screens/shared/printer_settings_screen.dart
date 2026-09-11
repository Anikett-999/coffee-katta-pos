import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import '../../providers/printer_provider.dart';
import '../../../domain/models/printer_config.dart';
import '../../widgets/global/confirmation_dialog.dart';
import '../../../core/app_theme.dart';
import '../../widgets/global/editorial_background.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  final List<PrinterDevice> _bluetoothDevices = [];
  final List<PrinterDevice> _usbDevices = [];

  StreamSubscription? _scanSubscription;
  bool _isScanning = false;
  String? _lastTestStatus; // 'success' | 'failed' | null
  String? _lastTestError;
  final TextEditingController _ipController = TextEditingController();
  final List<PrinterDevice> _networkDevices = []; // To store discovered WiFi printers

  @override
  void initState() {
    super.initState();
    final config = ref.read(printerConfigProvider);
    _ipController.text = config.address ?? '';
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _ipController.dispose();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _bluetoothDevices.clear();
      _usbDevices.clear();
      _networkDevices.clear();
      _isScanning = true;
    });

    final config = ref.read(printerConfigProvider);
    PrinterType type;
    switch (config.connectionType) {
      case PrinterConnectionType.bluetooth:
        type = PrinterType.bluetooth;
        break;
      case PrinterConnectionType.usb:
        type = PrinterType.usb;
        break;
      case PrinterConnectionType.network:
        type = PrinterType.network;
        break;
      default:
        setState(() => _isScanning = false);
        return;
    }

    _scanSubscription = PrinterManager.instance.discovery(type: type).listen((device) {
      if (!mounted) return;
      setState(() {
        if (type == PrinterType.bluetooth) {
          if (!_bluetoothDevices.any((d) => d.address == device.address)) {
            _bluetoothDevices.add(device);
          }
        } else if (type == PrinterType.usb) {
          if (!_usbDevices.any((d) => d.vendorId == device.vendorId)) {
            _usbDevices.add(device);
          }
        } else if (type == PrinterType.network) {
          if (!_networkDevices.any((d) => d.address == device.address)) {
            _networkDevices.add(device);
          }
        }
      });
    }, onDone: () {
      setState(() => _isScanning = false);
    }, onError: (e) {
      setState(() => _isScanning = false);
      _showError('Scan Error: $e');
    });
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    setState(() => _isScanning = false);
  }

  bool _isValidIp(String ip) {
    return RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(ip);
  }

  Future<void> _handleTestPrint() async {
    final config = ref.read(printerConfigProvider);
    
    if (config.connectionType == PrinterConnectionType.network) {
      if (!_isValidIp(_ipController.text)) {
        _showError('Please enter a valid IP address (e.g., 192.168.1.100)');
        return;
      }
    }

    if (config.address == null || config.address!.isEmpty) {
      _showError('Please select or configure a printer address first.');
      return;
    }

    
    // Show immediate feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Attempting to connect to ${config.connectionType.name}...'),
          ],
        ),
        backgroundColor: AppTheme.maroon,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final printService = ref.read(printServiceProvider);
      
      final List<int> testBytes = [
        27, 64, // Initialize
        10, 
        ...utf8.encode('================================\n'),
        ...utf8.encode('      COFFEE KATTA POS          \n'),
        ...utf8.encode('      PRINTER TEST TICKET       \n'),
        ...utf8.encode('================================\n'),
        ...utf8.encode('Status: ALIVE & CONNECTED\n'),
        ...utf8.encode('Size:   ${config.paperSize.name}\n'),
        ...utf8.encode('Type:   ${config.connectionType.name}\n'),
        ...utf8.encode('Addr:   ${config.address}\n'),
        ...utf8.encode('Time:   ${DateTime.now().toString().substring(0, 16)}\n'),
        ...utf8.encode('================================\n'),
        10, 10, 10,
        27, 105, // Full cut
      ];
      
      await printService.printReceipt(testBytes, config);
      
      if (mounted) {
        setState(() {
          _lastTestStatus = 'success';
          _lastTestError = null;
        });
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Connection Success', style: TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: Text('Succesfully connected to ${config.name}. Test receipt generated.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('GREAT', style: TextStyle(color: AppTheme.maroon, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastTestStatus = 'failed';
          _lastTestError = e.toString();
        });
        _showError('Connection Failed!\n\nDetails: $e\n\nEnsure the printer is turned ON and connected to the same network/BT/USB.');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.maroon),
            SizedBox(width: 8),
            Expanded(
              child: Text('Printer Error', style: TextStyle(color: AppTheme.maroon, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('DISMISS', style: TextStyle(color: AppTheme.maroon, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(printerConfigProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('HARDWARE SETTINGS', 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.white,
        foregroundColor: AppTheme.maroon,
      ),
      body: EditorialBackground(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildSectionHeader('Connection Protocol'),
          _buildConnectionTypesGrid(config),
          
          if (config.connectionType == PrinterConnectionType.network) ...[
            const SizedBox(height: 24),
            _buildIpInputField(),
          ],

          if (config.connectionType == PrinterConnectionType.bluetooth || 
              config.connectionType == PrinterConnectionType.usb ||
              config.connectionType == PrinterConnectionType.network) ...[
            const SizedBox(height: 24),
            _buildDeviceSection(config),
          ],

          const SizedBox(height: 32),
          _buildSectionHeader('Printing Preferences'),
          _buildPreferenceCard(config),
          
          const SizedBox(height: 32),
          _buildTestPrintButton(),
          
          Center(
            child: TextButton(
              onPressed: () {
                ConfirmationDialog.show(
                  context: context,
                  title: 'Reset Hardware?',
                  message: 'This will clear all saved printer settings. Are you sure?',
                  onConfirm: () {
                    ref.read(printerConfigProvider.notifier).updateConfig(const PrinterConfig());
                    _ipController.clear();
                  },
                );
              },
              child: Text('RESET TO DEFAULTS', 
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_lastTestStatus != 'success' && config.connectionType != PrinterConnectionType.rawbt)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Please perform a test print to verify connection before confirming.',
                          style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ElevatedButton(
                onPressed: (_lastTestStatus == 'success' || config.connectionType == PrinterConnectionType.rawbt) 
                    ? () => Navigator.pop(context)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('CONFIRM HARDWARE SETUP', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.maroon,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildConnectionTypesGrid(PrinterConfig config) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: [
          _protocolTile(PrinterConnectionType.bluetooth, 'Bluetooth', Icons.bluetooth_rounded, config),
          _protocolTile(PrinterConnectionType.usb, 'Direct USB', Icons.usb_rounded, config),
          _protocolTile(PrinterConnectionType.network, 'Network/IP', Icons.wifi_rounded, config),
          _protocolTile(PrinterConnectionType.rawbt, 'RawBT App', Icons.android_rounded, config),
        ],
      ),
    );
  }

  Widget _protocolTile(PrinterConnectionType type, String label, IconData icon, PrinterConfig config) {
    final isSelected = config.connectionType == type;
    return InkWell(
      onTap: () {
        ref.read(printerConfigProvider.notifier).updateConnectionType(type);
        setState(() => _lastTestStatus = null); // Reset status on switch
        _stopScan();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.maroon : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 28),
            const SizedBox(height: 4),
            Text(label, 
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildIpInputField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Network Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _ipController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Printer IP Address',
              hintText: 'e.g. 192.168.1.100',
              prefixIcon: const Icon(Icons.lan_outlined, color: AppTheme.maroon),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppTheme.cream.withOpacity(0.3),
            ),
            onChanged: (val) {
              if (_isValidIp(val)) {
                ref.read(printerConfigProvider.notifier).updateAddress(val);
              }
            },
          ),
          const SizedBox(height: 8),
          const Text('Note: Ensure printer is on the same WiFi network as this device.', 
            style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDeviceSection(PrinterConfig config) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Available Devices', 
                    style: TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (_lastTestStatus != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _lastTestStatus == 'success' ? AppTheme.successGreen.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: GestureDetector(
                      onTap: _lastTestStatus == 'failed' && _lastTestError != null 
                        ? () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $_lastTestError'))
                          )
                        : null,
                      child: Text(
                        _lastTestStatus == 'success' ? 'CONNECTED' : 'FAILED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _lastTestStatus == 'success' ? AppTheme.successGreen : Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: _isScanning 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.maroon))
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.maroon),
                  onPressed: _startScan,
                ),
          ),
          const Divider(height: 1),
          _buildDeviceList(config),
        ],
      ),
    );
  }

  Widget _buildDeviceList(PrinterConfig config) {
    List<PrinterDevice> devices;
    switch (config.connectionType) {
      case PrinterConnectionType.bluetooth:
        devices = _bluetoothDevices;
        break;
      case PrinterConnectionType.usb:
        devices = _usbDevices;
        break;
      case PrinterConnectionType.network:
        devices = _networkDevices;
        break;
      default:
        devices = [];
    }
    
    if (devices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.print_disabled_rounded, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _isScanning ? 'Scanning for printers...' : 'No printers found on this network.', 
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (!_isScanning) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.maroon),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: devices.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final device = devices[index];
        final name = device.name;
        
        String address;
        if (config.connectionType == PrinterConnectionType.bluetooth) {
          address = device.address ?? '';
        } else if (config.connectionType == PrinterConnectionType.usb) {
          address = '${device.vendorId}:${device.productId}';
        } else {
          address = device.address ?? ''; // IP for network
        }

        final isSelected = config.address == address;

        return ListTile(
          dense: true,
          leading: Icon(
            config.connectionType == PrinterConnectionType.network ? Icons.wifi_rounded :
            config.connectionType == PrinterConnectionType.bluetooth ? Icons.bluetooth_rounded : Icons.usb_rounded,
            color: isSelected ? AppTheme.maroon : Colors.grey,
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(address, style: const TextStyle(fontSize: 11)),
          trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.successGreen) : null,
          onTap: () {
            ref.read(printerConfigProvider.notifier).updateAddress(address);
            ref.read(printerConfigProvider.notifier).updateName(name);
            setState(() => _lastTestStatus = null); // Reset status on selection
            if (config.connectionType == PrinterConnectionType.network) {
              _ipController.text = address;
            }
          },
        );
      },
    );
  }

  Widget _buildPreferenceCard(PrinterConfig config) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.straighten_rounded, color: AppTheme.maroon, size: 20),
                const SizedBox(width: 12),
                const Expanded(child: Text('Paper Width', style: TextStyle(fontWeight: FontWeight.bold))),
                _buildPaperChip('58mm', config.paperSize == PrinterPaperSize.mm58, () => ref.read(printerConfigProvider.notifier).updatePaperSize(PrinterPaperSize.mm58)),
                const SizedBox(width: 8),
                _buildPaperChip('80mm', config.paperSize == PrinterPaperSize.mm80, () => ref.read(printerConfigProvider.notifier).updatePaperSize(PrinterPaperSize.mm80)),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildAestheticToggle(
            'Auto-print KOT', 
            'Generate KOT on order submit', 
            config.autoPrintKOT, 
            (val) => ref.read(printerConfigProvider.notifier).toggleAutoKOT(val)
          ),
          const Divider(height: 1, indent: 16),
          _buildAestheticToggle(
            'Auto-print Bills', 
            'Generate bill on checkout', 
            config.autoPrintBill, 
            (val) => ref.read(printerConfigProvider.notifier).toggleAutoBill(val)
          ),
          if (config.connectionType == PrinterConnectionType.bluetooth) ...[
            const Divider(height: 1, indent: 16),
            _buildAestheticToggle(
              'BLE Mode', 
              'Use Bluetooth Low Energy (for newer printers)', 
              config.isBle, 
              (val) => ref.read(printerConfigProvider.notifier).toggleBle(val)
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaperChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.maroon : AppTheme.cream,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAestheticToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Switch.adaptive(
        value: value,
        activeColor: AppTheme.maroon,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTestPrintButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppTheme.espressoBrown, Color(0xFF2E1A09)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: AppTheme.espressoBrown.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _handleTestPrint,
        icon: const Icon(Icons.print_rounded, color: Colors.white),
        label: const Text('GENERATE TEST RECEIPT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
