import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:usb_serial/usb_serial.dart';
import '../../../core/hardware/printer_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/user_model.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Settings',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ContentWrapper(
        child: ListView(
          children: [
            // User info card
            if (user != null)
              _SettingsCard(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        radius: 28,
                        child: Text(
                          user.firstName.isNotEmpty
                              ? user.firstName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(user.email,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                UserRole.displayName(user.role),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // General / Configuration
            const _SectionHeader(title: 'GENERAL'),
            _SettingsCard(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    tileColor: Colors.transparent,
                    leading: const Icon(Icons.business_outlined,
                        color: AppColors.primary),
                    title: const Text('Business Settings',
                        style: TextStyle(color: AppColors.textPrimary)),
                    subtitle: const Text(
                        'Name, contact, address & hours',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () => context.push('/settings/business'),
                  ),
                  if (user != null && (user.isBusinessOwner || user.isManager)) ...[
                    Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.divider),
                    ListTile(
                      tileColor: Colors.transparent,
                      leading: const Icon(Icons.store_outlined,
                          color: AppColors.primary),
                      title: const Text('Branches',
                          style: TextStyle(color: AppColors.textPrimary)),
                      subtitle: const Text(
                          'Manage store locations and branches',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary),
                      onTap: () {
                        final u = ref.read(currentUserProvider);
                        if (u != null && u.tenantId != null) {
                          context.push('/settings/branches?tenantId=${u.tenantId}');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No business associated with your account'),
                            ),
                          );
                        }
                      },
                    ),
                    Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.divider),
                    ListTile(
                      tileColor: Colors.transparent,
                      leading: const Icon(Icons.group_outlined,
                          color: AppColors.primary),
                      title: const Text('Staff Management',
                          style: TextStyle(color: AppColors.textPrimary)),
                      subtitle: const Text(
                          'Manage staff accounts and roles',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary),
                      onTap: () => context.push('/users'),
                    ),
                  ],
                  Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.divider),
                  ListTile(
                    tileColor: Colors.transparent,
                    leading: const Icon(Icons.receipt_long_outlined,
                        color: AppColors.primary),
                    title: const Text('Receipt Settings',
                        style: TextStyle(color: AppColors.textPrimary)),
                    subtitle: const Text(
                        'Header, footer, paper size & display',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () => context.push('/settings/receipt'),
                  ),
                  Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.divider),
                  ListTile(
                    tileColor: Colors.transparent,
                    leading: const Icon(Icons.percent,
                        color: AppColors.primary),
                    title: const Text('Tax Settings',
                        style: TextStyle(color: AppColors.textPrimary)),
                    subtitle: const Text(
                        'Tax rate, name & type',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () => context.push('/settings/tax'),
                  ),
                  Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.divider),
                  ListTile(
                    tileColor: Colors.transparent,
                    leading: const Icon(Icons.tune_outlined,
                        color: AppColors.primary),
                    title: const Text('Preferences',
                        style: TextStyle(color: AppColors.textPrimary)),
                    subtitle: const Text(
                        'Currency, date format & display',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () => context.push('/settings/preferences'),
                  ),
                ],
              ),
            ),

            // Connection
            const _SectionHeader(title: 'CONNECTION'),
            _SettingsCard(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                tileColor: Colors.transparent,
                leading: const Icon(Icons.cloud_outlined,
                    color: AppColors.primary),
                title: const Text('Backend URL',
                    style: TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(AppConstants.baseUrl,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
            ),

            // Account
            const _SectionHeader(title: 'ACCOUNT'),
            _SettingsCard(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    tileColor: Colors.transparent,
                    leading: const Icon(Icons.person_outline,
                        color: AppColors.primary),
                    title: const Text('Edit Profile',
                        style: TextStyle(color: AppColors.textPrimary)),
                    subtitle: const Text('Update name & phone',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () => context.push('/settings/profile'),
                  ),
                  Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.divider),
                  ListTile(
                    tileColor: Colors.transparent,
                    leading: const Icon(Icons.lock_outlined,
                        color: AppColors.primary),
                    title: const Text('Change Password',
                        style: TextStyle(color: AppColors.textPrimary)),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () => _showChangePassword(context),
                  ),
                ],
              ),
            ),

            // Hardware
            const _SectionHeader(title: 'HARDWARE'),
            _SettingsCard(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                tileColor: Colors.transparent,
                leading: const Icon(Icons.print_outlined,
                    color: AppColors.primary),
                title: const Text('Receipt Printer',
                    style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text(
                    'USB, Bluetooth & WiFi ESC/POS printers',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
                onTap: () => _showPrinterSettings(context),
              ),
            ),

            // About
            const _SectionHeader(title: 'ABOUT'),
            _SettingsCard(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    tileColor: Colors.transparent,
                    leading: const Icon(Icons.info_outline,
                        color: AppColors.primary),
                    title: const Text('Version',
                        style: TextStyle(color: AppColors.textPrimary)),
                    trailing: const Text('1.0.0',
                        style:
                            TextStyle(color: AppColors.textSecondary)),
                  ),
                  Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.divider),
                  ListTile(
                    tileColor: Colors.transparent,
                    leading: const Icon(Icons.logout,
                        color: AppColors.error),
                    title: const Text('Sign Out',
                        style: TextStyle(color: AppColors.error)),
                    onTap: () => _confirmLogout(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Change Password',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DarkTextField(
                controller: currentController,
                label: 'Current Password',
                obscureText: true,
              ),
              const SizedBox(height: 12),
              _DarkTextField(
                controller: newController,
                label: 'New Password',
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: AppColors.textSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryFg),
              onPressed: loading
                  ? null
                  : () async {
                      // Validate before calling API
                      final current = currentController.text;
                      final newPw = newController.text;
                      if (current.isEmpty || newPw.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Both fields are required'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      if (newPw.length < 8) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'New password must be at least 8 characters'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      setStateDialog(() => loading = true);
                      try {
                        await apiClient.dio.post(
                          '/auth/change-password',
                          data: {
                            'current_password': current,
                            'new_password': newPw,
                          },
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text('Password changed'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryFg))
                  : const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrinterSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _PrinterSettingsSheet(),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign Out',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
            'Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// Shared card widget

class _SettingsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const _SettingsCard({required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}

// Section header

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// Dark-themed text field helper

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;

  const _DarkTextField({
    required this.controller,
    required this.label,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: AppColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

// Printer Settings Bottom Sheet

class _PrinterSettingsSheet extends StatefulWidget {
  const _PrinterSettingsSheet();

  @override
  State<_PrinterSettingsSheet> createState() =>
      _PrinterSettingsSheetState();
}

class _PrinterSettingsSheetState
    extends State<_PrinterSettingsSheet> {
  // WiFi
  late TextEditingController _ipCtrl;
  late TextEditingController _portCtrl;
  bool _wifiSaving = false;

  // Bluetooth
  List<BluetoothDevice> _btResults = [];
  bool _btScanning = false;
  String? _btError;

  // USB
  List<UsbDevice> _usbDevices = [];
  bool _usbLoading = false;

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(
        text: printerService.savedWifiIp ?? '');
    _portCtrl = TextEditingController(
        text: printerService.savedWifiPort.toString());
    _loadUsbDevices();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsbDevices() async {
    setState(() => _usbLoading = true);
    try {
      final devices = await printerService.listUsbDevices();
      if (mounted) {
        setState(() {
          _usbDevices = devices;
          _usbLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _usbLoading = false);
    }
  }

  Future<void> _saveWifi() async {
    final ip = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
    if (ip.isEmpty) return;
    setState(() => _wifiSaving = true);
    await printerService.saveWifiConfig(ip, port);
    if (mounted) {
      setState(() => _wifiSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('WiFi printer config saved'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _scanBluetooth() async {
    setState(() {
      _btScanning = true;
      _btResults = [];
      _btError = null;
    });
    try {
      final devices = await printerService.scanBluetooth(
          timeout: const Duration(seconds: 6));
      if (mounted) {
        setState(() {
          _btResults = devices;
          _btScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _btScanning = false;
          _btError = e.toString();
        });
      }
    }
  }

  Future<void> _connectBt(BluetoothDevice device) async {
    final ok = await printerService.connectBluetooth(device);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '${device.platformName} connected'
          : 'Could not connect to ${device.platformName}'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
    if (ok) setState(() {});
  }

  Future<void> _connectUsb(UsbDevice device) async {
    final ok = await printerService.connectUsb(device);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          ok ? 'USB printer connected' : 'USB connection failed'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
    if (ok) setState(() {});
  }

  Future<void> _connectSerial(UsbDevice device) async {
    final ok = await printerService.connectSerial(device);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Serial printer connected'
          : 'Serial connection failed'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
    if (ok) setState(() {});
  }

  Future<void> _disconnect() async {
    await printerService.disconnectUsb();
    await printerService.disconnectBluetooth();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = printerService.isAnyConnected;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.print_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Printer Settings',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
                if (isConnected)
                  TextButton.icon(
                    onPressed: _disconnect,
                    icon:
                        const Icon(Icons.link_off, size: 16),
                    label: const Text('Disconnect All'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.error),
                  ),
              ],
            ),
          ),
          // Connection status banner
          Padding(
            padding:
                const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isConnected
                    ? AppColors.successLight
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isConnected
                      ? AppColors.success
                          .withValues(alpha: 0.3)
                      : AppColors.divider,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: isConnected
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected
                        ? _connectionLabel()
                        : 'No printer connected',
                    style: TextStyle(
                        fontSize: 13,
                        color: isConnected
                            ? AppColors.success
                            : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // WiFi
                _SheetSection(
                  icon: Icons.wifi,
                  title: 'WiFi / LAN Printer',
                  child: Column(
                    children: [
                      _DarkTextField(
                        controller: _ipCtrl,
                        label: 'IP Address',
                      ),
                      const SizedBox(height: 10),
                      _DarkTextField(
                        controller: _portCtrl,
                        label: 'Port',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  AppColors.primary,
                              foregroundColor:
                                  AppColors.primaryFg),
                          onPressed:
                              _wifiSaving ? null : _saveWifi,
                          icon: _wifiSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors
                                              .primaryFg))
                              : const Icon(
                                  Icons.save_outlined,
                                  size: 18),
                          label:
                              const Text('Save WiFi Config'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Bluetooth
                _SheetSection(
                  icon: Icons.bluetooth,
                  title: 'Bluetooth Printer',
                  trailing: _btScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary))
                      : TextButton(
                          onPressed: _scanBluetooth,
                          child: const Text('Scan',
                              style: TextStyle(
                                  color: AppColors.primary)),
                        ),
                  child: Column(
                    children: [
                      if (_btError != null)
                        Text(_btError!,
                            style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12)),
                      if (_btResults.isEmpty && !_btScanning)
                        const Text(
                          'Tap Scan to discover nearby Bluetooth printers',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12),
                        ),
                      ..._btResults.map((d) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                                Icons.bluetooth,
                                color: AppColors.primary),
                            title: Text(
                                d.platformName.isNotEmpty
                                    ? d.platformName
                                    : d.remoteId.str,
                                style: const TextStyle(
                                    color:
                                        AppColors.textPrimary)),
                            subtitle: Text(d.remoteId.str,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors
                                        .textSecondary)),
                            trailing: printerService.isBtConnected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: AppColors.success,
                                    size: 20)
                                : TextButton(
                                    onPressed: () =>
                                        _connectBt(d),
                                    child: const Text(
                                        'Connect',
                                        style: TextStyle(
                                            color: AppColors
                                                .primary))),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // USB
                _SheetSection(
                  icon: Icons.usb,
                  title: 'USB Printer (Android OTG)',
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh,
                        size: 18,
                        color: AppColors.textSecondary),
                    tooltip: 'Refresh',
                    onPressed: _loadUsbDevices,
                  ),
                  child: _usbLoading
                      ? const Center(
                          child: Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary),
                        ))
                      : _usbDevices.isEmpty
                          ? const Text(
                              'No USB devices detected. Connect a USB printer via OTG.',
                              style: TextStyle(
                                  color:
                                      AppColors.textSecondary,
                                  fontSize: 12),
                            )
                          : Column(
                              children: _usbDevices
                                  .map((d) => ListTile(
                                        contentPadding:
                                            EdgeInsets.zero,
                                        leading: const Icon(
                                            Icons.usb,
                                            color: AppColors
                                                .primary),
                                        title: Text(
                                            d.manufacturerName ??
                                                'USB Device',
                                            style: const TextStyle(
                                                color: AppColors
                                                    .textPrimary)),
                                        subtitle: Text(
                                            'VID:${d.vid?.toRadixString(16)} PID:${d.pid?.toRadixString(16)}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors
                                                    .textSecondary)),
                                        trailing: printerService
                                                .isUsbConnected
                                            ? const Icon(
                                                Icons.check_circle,
                                                color: AppColors
                                                    .success,
                                                size: 20)
                                            : Row(
                                                mainAxisSize:
                                                    MainAxisSize
                                                        .min,
                                                children: [
                                                  TextButton(
                                                    onPressed:
                                                        () => _connectUsb(
                                                            d),
                                                    style: TextButton.styleFrom(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal:
                                                                8)),
                                                    child: const Text(
                                                        'USB',
                                                        style: TextStyle(
                                                            color: AppColors.primary,
                                                            fontSize:
                                                                12)),
                                                  ),
                                                  TextButton(
                                                    onPressed:
                                                        () => _connectSerial(
                                                            d),
                                                    style: TextButton.styleFrom(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal:
                                                                8)),
                                                    child: const Text(
                                                        'Serial',
                                                        style: TextStyle(
                                                            color: AppColors.textSecondary,
                                                            fontSize:
                                                                12)),
                                                  ),
                                                ],
                                              ),
                                      ))
                                  .toList(),
                            ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _connectionLabel() {
    if (printerService.isUsbConnected) {
      return printerService.isSerialConnected
          ? 'Serial (USB-to-Serial) printer connected'
          : 'USB printer connected';
    }
    if (printerService.isBtConnected) {
      return 'Bluetooth printer connected';
    }
    if (printerService.isWifiConfigured) {
      return 'WiFi printer: ${printerService.savedWifiIp}:${printerService.savedWifiPort}';
    }
    return 'Connected';
  }
}

class _SheetSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SheetSection({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
