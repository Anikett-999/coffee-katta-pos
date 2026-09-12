import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:printing/printing.dart' as printing;

import '../../../core/app_theme.dart';
import '../../../domain/models/printer_config.dart';
import '../../../domain/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/branch_provider.dart';
import '../../providers/printer_provider.dart';
import '../../widgets/global/confirmation_dialog.dart';
import '../../widgets/global/editorial_background.dart';
import '../../widgets/global/coffee_katta_brand_badge.dart';
import '../../widgets/shared/thermal_receipt_preview.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  final List<PrinterDevice> _bluetoothDevices = [];
  final List<PrinterDevice> _usbDevices = [];
  final List<PrinterDevice> _networkDevices = [];

  StreamSubscription? _scanSubscription;
  bool _isScanning = false;
  bool _isTesting = false;
  String? _lastTestStatus; // 'success' | 'failed' | null
  String? _lastTestError;

  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = ref.read(printerConfigProvider);
      if (config.address != null) {
        _ipController.text = config.address!;
      }
    });
  }

  @override
  void dispose() {
    _stopScan();
    _ipController.dispose();
    super.dispose();
  }

  void _startScan() {
    final config = ref.read(printerConfigProvider);
    _stopScan();

    setState(() {
      _isScanning = true;
      _bluetoothDevices.clear();
      _usbDevices.clear();
      _networkDevices.clear();
    });

    final printerManager = PrinterManager.instance;

    switch (config.connectionType) {
      case PrinterConnectionType.bluetooth:
        _scanSubscription = printerManager.discovery(type: PrinterType.bluetooth, isBle: config.isBle).listen((device) {
          if (!_bluetoothDevices.any((d) => d.address == device.address)) {
            setState(() {
              _bluetoothDevices.add(device);
            });
          }
        });
        break;
      case PrinterConnectionType.usb:
        _scanSubscription = printerManager.discovery(type: PrinterType.usb).listen((device) {
          if (!_usbDevices.any((d) => d.vendorId == device.vendorId && d.productId == device.productId)) {
            setState(() {
              _usbDevices.add(device);
            });
          }
        });
        break;
      case PrinterConnectionType.network:
        _scanSubscription = printerManager.discovery(type: PrinterType.network).listen((device) {
          if (!_networkDevices.any((d) => d.address == device.address)) {
            setState(() {
              _networkDevices.add(device);
            });
          }
        });
        break;
      case PrinterConnectionType.rawbt:
        setState(() => _isScanning = false);
        return;
    }

    // Auto-timeout scan after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isScanning) {
        _stopScan();
      }
    });
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  bool _isValidIp(String ip) {
    final regex = RegExp(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$');
    return regex.hasMatch(ip.trim());
  }

  Future<void> _handleTestPrint() async {
    final config = ref.read(printerConfigProvider);
    final user = ref.read(userModelProvider).value;
    final branch = ref.read(branchProvider).value;

    setState(() {
      _isTesting = true;
      _lastTestStatus = null;
      _lastTestError = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating hardware diagnostic slip...'),
        backgroundColor: Color(0xFF382012),
        duration: Duration(seconds: 3),
      ),
    );

    try {
      final printService = ref.read(printServiceProvider);
      final testBytes = await printService.generateDiagnosticTestBytes(
        config,
        branchName: branch?.branchName ?? 'Coffee Katta — Latur Main',
        userRole: user?.role ?? 'Staff',
      );

      final success = await printService.printReceipt(testBytes, config);

      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _lastTestStatus = success ? 'success' : 'failed';
        if (!success) {
          _lastTestError = 'Printer did not respond. Ensure it is powered ON and reachable on this network/interface.';
        }
      });

      if (success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF287A55), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Printer Verified',
                    style: TextStyle(color: Color(0xFF29231F), fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Text(
              'Diagnostic test slip was successfully transmitted to ${config.name}. Thermal hardware is online and operational.',
              style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF382012)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('GREAT', style: TextStyle(color: Color(0xFF382012), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        _showErrorDialog(_lastTestError ?? 'Communication failed. Please check cables, power, and IP/Bluetooth pairing.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _lastTestStatus = 'failed';
        _lastTestError = e.toString();
      });
      _showErrorDialog('Hardware Connection Failed:\n\n$e');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hardware Error',
                style: TextStyle(color: Color(0xFF382012), fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF29231F))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DISMISS', style: TextStyle(color: Color(0xFF382012), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(printerConfigProvider);
    final userModel = ref.watch(userModelProvider).value;
    final branchModel = ref.watch(branchProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EF),
      body: SafeArea(
        child: Column(
          children: [
            // Top Branded Header (Responsive, zero overflow on mobile)
            _buildTopBrandedHeader(userModel),

            // Responsive Layout Body
            Expanded(
              child: EditorialBackground(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktopOrTablet = constraints.maxWidth >= 900;
                    if (isDesktopOrTablet) {
                      return _buildDesktopLayout(config, userModel, branchModel);
                    } else {
                      return _buildMobileLayout(config, userModel, branchModel);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomConfirmBar(config),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BRANDED HEADER (Responsive & Overflow-Free on Mobile)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopBrandedHeader(UserModel? user) {
    final isWaiter = user?.isWaiter ?? false;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 720;

    return Container(
      height: 62,
      color: const Color(0xFF382012), // Deep Coffee Brown
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),

          // Coffee Katta Branding with Bearded Man Mascot
          CoffeeKattaBrandBadge(showTagline: !isCompact),

          // Only on Desktop/Wide Tablet: show decorative vertical divider and "HARDWARE & THERMAL ENGINE" badge
          if (!isCompact) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              width: 1,
              height: 26,
              color: Colors.white24,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print_rounded, size: 13, color: Colors.white70),
                  SizedBox(width: 6),
                  Text(
                    'HARDWARE & THERMAL ENGINE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // Role Context Badge (Compact on mobile to guarantee zero overflow)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 10,
              vertical: 3.5,
            ),
            decoration: BoxDecoration(
              color: isWaiter
                  ? const Color(0xFF287A55)
                  : const Color(0xFFB77945),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isCompact
                  ? (isWaiter ? 'WAITER' : 'ADMIN')
                  : (isWaiter ? 'WAITER TERMINAL' : 'COUNTER CONSOLE'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DESKTOP & TABLET LAYOUT (Multi-Column Dashboard)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(PrinterConfig config, UserModel? user, dynamic branch) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column (400px): Status, Protocol, & Preferences
          SizedBox(
            width: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildActiveStatusCard(config),
                const SizedBox(height: 16),
                _buildProtocolSection(config),
                const SizedBox(height: 16),
                _buildPreferencesCard(config),
                const SizedBox(height: 16),
                _buildResetDefaultsButton(),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // Right Column (Expanded): Discovery / Configuration & Live Simulator
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDiscoveryAndSetupCard(config),
                const SizedBox(height: 16),
                ThermalReceiptPreview(
                  paperSize: config.paperSize,
                  branchName: branch?.branchName ?? 'Coffee Katta',
                  branchAddress: branch?.address ?? 'Near Rajiv Gandhi Chowk, Latur',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MOBILE LAYOUT (Single Column Stacked View)
  // ─────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(PrinterConfig config, UserModel? user, dynamic branch) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        _buildActiveStatusCard(config),
        const SizedBox(height: 16),
        _buildProtocolSection(config),
        const SizedBox(height: 16),
        _buildDiscoveryAndSetupCard(config),
        const SizedBox(height: 16),
        _buildPreferencesCard(config),
        const SizedBox(height: 16),
        ThermalReceiptPreview(
          paperSize: config.paperSize,
          branchName: branch?.branchName ?? 'Coffee Katta',
          branchAddress: branch?.address ?? 'Near Rajiv Gandhi Chowk, Latur',
        ),
        const SizedBox(height: 16),
        _buildResetDefaultsButton(),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. ACTIVE HARDWARE STATUS CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildActiveStatusCard(PrinterConfig config) {
    final isConfigured = config.address != null && config.address!.trim().isNotEmpty;
    final isVerified = _lastTestStatus == 'success';

    Color statusColor;
    String statusText;
    if (isVerified) {
      statusColor = const Color(0xFF287A55);
      statusText = 'ONLINE & VERIFIED';
    } else if (isConfigured) {
      statusColor = const Color(0xFFB77945);
      statusText = 'CONFIGURED (NOT VERIFIED)';
    } else {
      statusColor = const Color(0xFFDC2626);
      statusText = 'NOT CONFIGURED';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF382012).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    _getProtocolIcon(config.connectionType),
                    color: const Color(0xFF382012),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.name.isNotEmpty ? config.name : 'Default Printer',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF29231F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      config.address?.isNotEmpty == true
                          ? '${config.connectionType.name.toUpperCase()} • ${config.address}'
                          : '${config.connectionType.name.toUpperCase()} • Address Not Set',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B5E55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE8E1D8)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                child: Text(
                  '${config.paperSize.name.toUpperCase()} ROLL',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF382012),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Instant Test Print Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isTesting ? null : _handleTestPrint,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.print_rounded, size: 18, color: Colors.white),
              label: Text(
                _isTesting ? 'TRANSMITTING TEST...' : 'RUN HARDWARE TEST TICKET',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF382012), // Deep Espresso
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. CONNECTION PROTOCOL SECTION
  // ─────────────────────────────────────────────────────────────
  Widget _buildProtocolSection(PrinterConfig config) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONNECTION PROTOCOL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: Color(0xFF5A3825),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.55,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _buildProtocolCard(
                PrinterConnectionType.network,
                'WiFi / Network',
                'Counter & Kitchen LAN',
                Icons.wifi_rounded,
                config,
              ),
              _buildProtocolCard(
                PrinterConnectionType.bluetooth,
                'Bluetooth',
                'Mobile Handheld KOT',
                Icons.bluetooth_rounded,
                config,
              ),
              _buildProtocolCard(
                PrinterConnectionType.usb,
                'Direct USB',
                'Counter Thermal Hub',
                Icons.usb_rounded,
                config,
              ),
              _buildProtocolCard(
                PrinterConnectionType.rawbt,
                'RawBT / System',
                'OS Spooler / Android',
                Icons.print_rounded,
                config,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolCard(
    PrinterConnectionType type,
    String title,
    String subtitle,
    IconData icon,
    PrinterConfig config,
  ) {
    final isSelected = config.connectionType == type;

    return InkWell(
      onTap: () {
        ref.read(printerConfigProvider.notifier).updateConnectionType(type);
        setState(() {
          _lastTestStatus = null;
          _lastTestError = null;
        });
        _stopScan();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFBF7F2) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF382012) : const Color(0xFFE8E1D8),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? const Color(0xFF382012) : const Color(0xFF5A3825),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF287A55)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: isSelected ? const Color(0xFF382012) : const Color(0xFF29231F),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: isSelected ? const Color(0xFF5A3825) : const Color(0xFF6B5E55),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. DISCOVERY & SETUP CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildDiscoveryAndSetupCard(PrinterConfig config) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${config.connectionType.name.toUpperCase()} CONFIGURATION',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: Color(0xFF5A3825),
                ),
              ),
              if (config.connectionType != PrinterConnectionType.rawbt)
                TextButton.icon(
                  onPressed: _isScanning ? _stopScan : _startScan,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5A3825)),
                        )
                      : const Icon(Icons.radar_rounded, size: 16, color: Color(0xFF5A3825)),
                  label: Text(
                    _isScanning ? 'SCANNING...' : 'SCAN HARDWARE',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF5A3825)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Protocol-Specific Body
          if (config.connectionType == PrinterConnectionType.network) ...[
            _buildNetworkIpInputs(config),
          ] else if (config.connectionType == PrinterConnectionType.bluetooth ||
              config.connectionType == PrinterConnectionType.usb) ...[
            _buildDiscoveredDeviceList(config),
          ] else ...[
            _buildSystemAndRawBtInfo(config),
          ],
        ],
      ),
    );
  }

  Widget _buildNetworkIpInputs(PrinterConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: TextFormField(
                controller: _ipController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF29231F), fontWeight: FontWeight.bold, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Thermal Printer IP Address *',
                  labelStyle: const TextStyle(color: Color(0xFF5A3825), fontWeight: FontWeight.bold),
                  hintText: '192.168.1.100',
                  hintStyle: const TextStyle(color: Color(0xFF8C7B70)),
                  prefixIcon: const Icon(Icons.lan_outlined, color: Color(0xFF382012), size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  helperText: 'Fixed LAN / WiFi IP configured on thermal printer',
                  helperStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B5E55)),
                ),
                onChanged: (val) {
                  if (_isValidIp(val)) {
                    ref.read(printerConfigProvider.notifier).updateAddress(val.trim());
                    ref.read(printerConfigProvider.notifier).updateName('Network Printer ($val)');
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: '${config.port}',
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF29231F), fontWeight: FontWeight.bold, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Port',
                  labelStyle: const TextStyle(color: Color(0xFF5A3825), fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  helperText: 'Standard: 9100',
                  helperStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B5E55)),
                ),
                enabled: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F4EF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8E1D8)),
          ),
          child: const Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, size: 18, color: Color(0xFF5A3825)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Quick Tip: Direct Raw TCP uses port 9100. Ensure this device is connected to the same cafe WiFi router as your network printer.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF382012), height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveredDeviceList(PrinterConfig config) {
    List<PrinterDevice> devices;
    switch (config.connectionType) {
      case PrinterConnectionType.bluetooth:
        devices = _bluetoothDevices;
        break;
      case PrinterConnectionType.usb:
        devices = _usbDevices;
        break;
      default:
        devices = [];
    }

    if (devices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.print_disabled_rounded, size: 38, color: Color(0xFF8C7B70)),
            const SizedBox(height: 12),
            Text(
              _isScanning
                  ? 'Searching for nearby thermal hardware...'
                  : 'No devices detected yet. Tap "SCAN HARDWARE" above to search.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5A4D43)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: devices.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE8E1D8)),
      itemBuilder: (context, index) {
        final device = devices[index];
        final name = device.name.isNotEmpty ? device.name : 'Unknown Hardware';

        String address;
        if (config.connectionType == PrinterConnectionType.bluetooth) {
          address = device.address ?? '';
        } else {
          address = '${device.vendorId}:${device.productId}';
        }

        final isSelected = config.address == address;

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF382012) : const Color(0xFFF7F4EF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              config.connectionType == PrinterConnectionType.bluetooth
                  ? Icons.bluetooth_rounded
                  : Icons.usb_rounded,
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF382012),
            ),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF29231F))),
          subtitle: Text(address, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF6B5E55))),
          trailing: isSelected
              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF287A55), size: 22)
              : OutlinedButton(
                  onPressed: () {
                    ref.read(printerConfigProvider.notifier).updateAddress(address);
                    ref.read(printerConfigProvider.notifier).updateName(name);
                    setState(() => _lastTestStatus = null);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF382012),
                    side: const BorderSide(color: Color(0xFF382012), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  ),
                  child: const Text('SELECT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                ),
        );
      },
    );
  }

  Widget _buildSystemAndRawBtInfo(PrinterConfig config) {
    final systemPrintersAsync = ref.watch(systemPrintersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kIsWeb) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE8E1D8)),
            ),
            child: const Row(
              children: [
                Icon(Icons.language_rounded, size: 28, color: Color(0xFF382012)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Web Browser Printing Mode',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF29231F)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Running in Web browser. Printing triggers the standard browser print dialogue. For direct ESC/POS hardware thermal printing, run on Windows Desktop or Android/Tablet app.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF6B5E55), height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else if (defaultTargetPlatform == TargetPlatform.windows) ...[
          const Text(
            'INSTALLED WINDOWS PRINTERS',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF5A3825), letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),
          systemPrintersAsync.when(
            data: (printers) {
              if (printers.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No Windows OS printers found installed in system settings.',
                    style: TextStyle(color: Color(0xFF6B5E55), fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                );
              }
              return Column(
                children: printers.map((p) {
                  final isSelected = config.address == p.name;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.print_outlined, color: Color(0xFF382012)),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF29231F))),
                    subtitle: Text(p.url, style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E55))),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF287A55))
                        : TextButton(
                            onPressed: () {
                              ref.read(printerConfigProvider.notifier).updateAddress(p.name);
                              ref.read(printerConfigProvider.notifier).updateName(p.name);
                            },
                            child: const Text('SELECT', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF382012))),
                          ),
                  );
                }).toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error reading system printers: $e', style: const TextStyle(color: Colors.red)),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE8E1D8)),
            ),
            child: const Row(
              children: [
                Icon(Icons.android_rounded, size: 28, color: Color(0xFF382012)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RawBT Thermal Print Service',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF29231F)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Prints directly via Android RawBT driver intent. Ensure the RawBT app is installed and configured on your Android device.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF6B5E55), height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. PRINTING PREFERENCES & AUTOMATIONS CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildPreferencesCard(PrinterConfig config) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRINTING PREFERENCES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: Color(0xFF5A3825),
            ),
          ),
          const SizedBox(height: 14),

          // Paper Width Segmented Chips
          Row(
            children: [
              const Icon(Icons.straighten_rounded, size: 20, color: Color(0xFF382012)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Thermal Paper Roll',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Color(0xFF29231F),
                  ),
                ),
              ),
              _buildPaperChip(
                '58mm (Compact)',
                config.paperSize == PrinterPaperSize.mm58,
                () => ref.read(printerConfigProvider.notifier).updatePaperSize(PrinterPaperSize.mm58),
              ),
              const SizedBox(width: 8),
              _buildPaperChip(
                '80mm (Full Width)',
                config.paperSize == PrinterPaperSize.mm80,
                () => ref.read(printerConfigProvider.notifier).updatePaperSize(PrinterPaperSize.mm80),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE8E1D8)),

          // Auto-print KOT
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Auto-print KOT on Submit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF29231F)),
            ),
            subtitle: const Text(
              'Instantly dispatches kitchen slip upon placing order',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF6B5E55)),
            ),
            activeColor: const Color(0xFF287A55),
            activeTrackColor: const Color(0xFF287A55).withValues(alpha: 0.35),
            value: config.autoPrintKOT,
            onChanged: (val) => ref.read(printerConfigProvider.notifier).toggleAutoKOT(val),
          ),
          const Divider(height: 1, color: Color(0xFFE8E1D8)),

          // Auto-print Bill
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Auto-print Bill on Settle',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF29231F)),
            ),
            subtitle: const Text(
              'Generates final customer receipt upon payment completion',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF6B5E55)),
            ),
            activeColor: const Color(0xFF287A55),
            activeTrackColor: const Color(0xFF287A55).withValues(alpha: 0.35),
            value: config.autoPrintBill,
            onChanged: (val) => ref.read(printerConfigProvider.notifier).toggleAutoBill(val),
          ),

          if (config.connectionType == PrinterConnectionType.bluetooth) ...[
            const Divider(height: 1, color: Color(0xFFE8E1D8)),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Bluetooth Low Energy (BLE)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF29231F)),
              ),
              subtitle: const Text(
                'Enable for BLE-compatible handheld thermal printers',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF6B5E55)),
              ),
              activeColor: const Color(0xFF287A55),
              activeTrackColor: const Color(0xFF287A55).withValues(alpha: 0.35),
              value: config.isBle,
              onChanged: (val) => ref.read(printerConfigProvider.notifier).toggleBle(val),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaperChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF382012) : const Color(0xFFF7F4EF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF382012) : const Color(0xFFD5CDC2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF382012),
          ),
        ),
      ),
    );
  }

  Widget _buildResetDefaultsButton() {
    return Center(
      child: TextButton.icon(
        onPressed: () {
          ConfirmationDialog.show(
            context: context,
            title: 'Reset Printer Hardware?',
            message: 'This will reset all hardware connection preferences to defaults. Continue?',
            confirmLabel: 'RESET',
            onConfirm: () {
              ref.read(printerConfigProvider.notifier).updateConfig(const PrinterConfig());
              _ipController.clear();
              setState(() {
                _lastTestStatus = null;
                _lastTestError = null;
              });
            },
          );
        },
        icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFF7A6B60)),
        label: const Text(
          'RESET HARDWARE CONFIGURATION',
          style: TextStyle(
            color: Color(0xFF7A6B60),
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM CONFIRMATION BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomConfirmBar(PrinterConfig config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE8E1D8), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Printer configuration saved for ${config.name.isNotEmpty ? config.name : "Default Printer"} (${config.connectionType.name.toUpperCase()})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: const Color(0xFF287A55),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check_circle_outline_rounded, size: 20, color: Colors.white),
            label: const Text(
              'CONFIRM & SAVE HARDWARE SETUP',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF287A55),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getProtocolIcon(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.network:
        return Icons.wifi_rounded;
      case PrinterConnectionType.bluetooth:
        return Icons.bluetooth_rounded;
      case PrinterConnectionType.usb:
        return Icons.usb_rounded;
      case PrinterConnectionType.rawbt:
        return Icons.print_rounded;
    }
  }
}
