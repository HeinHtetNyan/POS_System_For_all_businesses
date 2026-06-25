// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';

class ReceiptSettingsScreen extends StatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  State<ReceiptSettingsScreen> createState() =>
      _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends State<ReceiptSettingsScreen> {
  static const _prefsKey = 'receipt_settings';

  bool _loading = true;
  bool _saving = false;

  final _headerCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();

  String? _logoPath;
  bool _showLogo = true;
  bool _showOrderNumber = true;
  bool _showCashierName = true;
  bool _showBarcode = false;
  bool _showItemTax = false;
  bool _showCostPrice = false;
  bool _showMargin = false;
  String _paperSize = '80mm';
  String _fontSize = 'medium';

  @override
  void initState() {
    super.initState();
    _headerCtrl.addListener(() => setState(() {}));
    _footerCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _headerCtrl.text = map['header'] as String? ?? '';
        _footerCtrl.text = map['footer'] as String? ?? '';
        _logoPath = map['logo_path'] as String?;
        _showLogo = map['show_logo'] as bool? ?? true;
        _showOrderNumber = map['show_order_number'] as bool? ?? true;
        _showCashierName = map['show_cashier_name'] as bool? ?? true;
        _showBarcode = map['show_barcode'] as bool? ?? false;
        _showItemTax = map['show_item_tax'] as bool? ?? false;
        _showCostPrice = map['show_cost_price'] as bool? ?? false;
        _showMargin = map['show_margin'] as bool? ?? false;
        _paperSize = map['paper_size'] as String? ?? '80mm';
        _fontSize = map['font_size'] as String? ?? 'medium';
      }
    } catch (_) {
      // Use defaults
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'header': _headerCtrl.text,
        'footer': _footerCtrl.text,
        'logo_path': _logoPath,
        'show_logo': _showLogo,
        'show_order_number': _showOrderNumber,
        'show_cashier_name': _showCashierName,
        'show_barcode': _showBarcode,
        'show_item_tax': _showItemTax,
        'show_cost_price': _showCostPrice,
        'show_margin': _showMargin,
        'paper_size': _paperSize,
        'font_size': _fontSize,
      };
      await prefs.setString(_prefsKey, jsonEncode(map));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt settings saved'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _logoPath = picked.path);
  }

  void _removeLogo() {
    setState(() => _logoPath = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Receipt Settings',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ContentWrapper(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionHeader('RECEIPT CONTENT'),
                  const SizedBox(height: 8),
                  _card(
                    child: Column(
                      children: [
                        _multilineField(
                          controller: _headerCtrl,
                          label: 'Header Text',
                          hint: 'e.g. Thank you for shopping!',
                        ),
                        const SizedBox(height: 12),
                        _multilineField(
                          controller: _footerCtrl,
                          label: 'Footer Text',
                          hint: 'e.g. Returns accepted within 7 days.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _sectionHeader('LOGO'),
                  const SizedBox(height: 8),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_logoPath != null &&
                            File(_logoPath!).existsSync()) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_logoPath!),
                              height: 80,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.divider,
                                  style: BorderStyle.solid),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_outlined,
                                    color: AppColors.textDisabled,
                                    size: 28),
                                SizedBox(height: 4),
                                Text(
                                  'No logo selected',
                                  style: TextStyle(
                                      color: AppColors.textDisabled,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                      color: AppColors.primary),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.photo_library_outlined,
                                    size: 16),
                                label: const Text('Choose from Gallery',
                                    style: TextStyle(fontSize: 13)),
                                onPressed: _pickLogo,
                              ),
                            ),
                            if (_logoPath != null) ...[
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(
                                      color: AppColors.error),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                                onPressed: _removeLogo,
                                child: const Text('Remove',
                                    style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Logo is stored locally on this device.',
                          style: TextStyle(
                              color: AppColors.textDisabled, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _sectionHeader('DISPLAY OPTIONS'),
                  const SizedBox(height: 8),
                  _card(
                    child: Column(
                      children: [
                        _toggle(
                          title: 'Show Logo',
                          subtitle: 'Print business logo at top',
                          value: _showLogo,
                          onChanged: (v) => setState(() => _showLogo = v),
                        ),
                        _divider(),
                        _toggle(
                          title: 'Show Order Number',
                          subtitle: 'Print order/receipt number',
                          value: _showOrderNumber,
                          onChanged: (v) =>
                              setState(() => _showOrderNumber = v),
                        ),
                        _divider(),
                        _toggle(
                          title: 'Show Cashier Name',
                          subtitle: 'Print name of cashier who processed sale',
                          value: _showCashierName,
                          onChanged: (v) =>
                              setState(() => _showCashierName = v),
                        ),
                        _divider(),
                        _toggle(
                          title: 'Show Barcode',
                          subtitle: 'Print barcode at bottom of receipt',
                          value: _showBarcode,
                          onChanged: (v) =>
                              setState(() => _showBarcode = v),
                        ),
                        _divider(),
                        _toggle(
                          title: 'Show Tax on Items',
                          subtitle: 'Display tax amount per line item',
                          value: _showItemTax,
                          onChanged: (v) =>
                              setState(() => _showItemTax = v),
                        ),
                        _divider(),
                        _toggle(
                          title: 'Show Cost Price',
                          subtitle: 'Print cost price alongside sale price',
                          value: _showCostPrice,
                          onChanged: (v) =>
                              setState(() => _showCostPrice = v),
                        ),
                        _divider(),
                        _toggle(
                          title: 'Show Margin',
                          subtitle: 'Display profit margin per item',
                          value: _showMargin,
                          onChanged: (v) =>
                              setState(() => _showMargin = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _sectionHeader('PAPER SIZE'),
                  const SizedBox(height: 8),
                  _card(
                    child: RadioGroup<String>(
                      groupValue: _paperSize,
                      onChanged: (v) => setState(() => _paperSize = v!),
                      child: Column(
                        children: [
                          _radioOption(
                            title: '58mm',
                            subtitle:
                                'Narrow thermal paper (compact printer)',
                            value: '58mm',
                          ),
                          _divider(),
                          _radioOption(
                            title: '80mm',
                            subtitle:
                                'Standard thermal paper (most POS printers)',
                            value: '80mm',
                          ),
                          _divider(),
                          _radioOption(
                            title: 'A4',
                            subtitle: 'Standard paper (office printer)',
                            value: 'A4',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  _sectionHeader('FONT SIZE'),
                  const SizedBox(height: 8),
                  _card(
                    child: RadioGroup<String>(
                      groupValue: _fontSize,
                      onChanged: (v) => setState(() => _fontSize = v!),
                      child: Column(
                        children: [
                          _radioOption(
                            title: 'Small',
                            subtitle: '9px — compact, fits more lines',
                            value: 'small',
                          ),
                          _divider(),
                          _radioOption(
                            title: 'Medium',
                            subtitle: '12px — default, balanced readability',
                            value: 'medium',
                          ),
                          _divider(),
                          _radioOption(
                            title: 'Large',
                            subtitle: '14px — easier to read',
                            value: 'large',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Receipt preview
                  _sectionHeader('PREVIEW'),
                  const SizedBox(height: 8),
                  _ReceiptPreview(
                    header: _headerCtrl.text,
                    footer: _footerCtrl.text,
                    showOrderNumber: _showOrderNumber,
                    showCashierName: _showCashierName,
                    showBarcode: _showBarcode,
                    showItemTax: _showItemTax,
                    showCostPrice: _showCostPrice,
                    showMargin: _showMargin,
                    paperSize: _paperSize,
                    fontSize: _fontSize,
                    logoPath: _logoPath,
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryFg,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primaryFg))
                          : const Text('Save Settings',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
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

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.all(16),
        clipBehavior: Clip.hardEdge,
        child: child,
      );

  Widget _divider() =>
      Divider(height: 1, color: AppColors.divider);

  Widget _toggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primaryFg,
      activeTrackColor: AppColors.primary,
    );
  }

  Widget _radioOption<T>({
    required String title,
    required String subtitle,
    required T value,
  }) {
    return RadioListTile<T>(
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12)),
      value: value,
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary),
    );
  }

  Widget _multilineField({
    required TextEditingController controller,
    required String label,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: 3,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textDisabled),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        alignLabelWithHint: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

// Receipt preview widget

class _ReceiptPreview extends StatelessWidget {
  final String header;
  final String footer;
  final bool showOrderNumber;
  final bool showCashierName;
  final bool showBarcode;
  final bool showItemTax;
  final bool showCostPrice;
  final bool showMargin;
  final String paperSize;
  final String fontSize;
  final String? logoPath;

  const _ReceiptPreview({
    required this.header,
    required this.footer,
    required this.showOrderNumber,
    required this.showCashierName,
    required this.showBarcode,
    required this.showItemTax,
    required this.showCostPrice,
    required this.showMargin,
    required this.paperSize,
    required this.fontSize,
    this.logoPath,
  });

  double get _baseFontSize {
    switch (fontSize) {
      case 'small':
        return 9.0;
      case 'large':
        return 14.0;
      case 'medium':
      default:
        return 12.0;
    }
  }

  String get _paperLabel {
    switch (paperSize) {
      case '58mm':
        return '-- 58mm paper --';
      case 'A4':
        return '-- A4 paper --';
      case '80mm':
      default:
        return '-- 80mm paper --';
    }
  }

  @override
  Widget build(BuildContext context) {
    const divLine = '--------------------------------';
    final baseFz = _baseFontSize;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: 'Courier',
          fontSize: baseFz,
          color: const Color(0xFF1A1A1A),
          height: 1.5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (logoPath != null && File(logoPath!).existsSync()) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(File(logoPath!),
                    height: 48, fit: BoxFit.contain),
              ),
              const SizedBox(height: 4),
            ] else if (logoPath != null) ...[
              Container(
                width: 64,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text('[LOGO]',
                      style: TextStyle(
                          fontSize: 10, color: Color(0xFF6B7280))),
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (header.trim().isNotEmpty)
              Text(header.trim(), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Your Business Name',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: baseFz + 2),
                textAlign: TextAlign.center),
            if (showOrderNumber)
              const Text('Order: #ORD-00001',
                  textAlign: TextAlign.center),
            const Text(divLine),
            _PreviewRow(
                left: 'Product A x2',
                right: '10,000',
                fontSize: baseFz),
            if (showItemTax)
              _PreviewRow(
                  left: '  Tax (5%)',
                  right: '500',
                  fontSize: baseFz - 1),
            if (showCostPrice)
              _PreviewRow(
                  left: '  Cost: 4,000',
                  right: '',
                  fontSize: baseFz - 1),
            if (showMargin)
              _PreviewRow(
                  left: '  Margin: 50%',
                  right: '',
                  fontSize: baseFz - 1),
            _PreviewRow(
                left: 'Product B x1',
                right: '5,000',
                fontSize: baseFz),
            if (showItemTax)
              _PreviewRow(
                  left: '  Tax (5%)',
                  right: '250',
                  fontSize: baseFz - 1),
            if (showCostPrice)
              _PreviewRow(
                  left: '  Cost: 2,500',
                  right: '',
                  fontSize: baseFz - 1),
            if (showMargin)
              _PreviewRow(
                  left: '  Margin: 50%',
                  right: '',
                  fontSize: baseFz - 1),
            const Text(divLine),
            _PreviewRow(
                left: 'Subtotal', right: '15,000', fontSize: baseFz),
            _PreviewRow(
                left: 'Tax (5%)', right: '750', fontSize: baseFz),
            _PreviewRow(
                left: 'TOTAL',
                right: '15,750',
                bold: true,
                fontSize: baseFz),
            if (showCashierName)
              Text('Cashier: John Doe',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: baseFz - 1)),
            if (showBarcode) ...[
              const SizedBox(height: 6),
              Container(
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    28,
                    (i) => Container(
                      width: i.isEven ? 2.0 : 1.0,
                      color: i % 3 == 0
                          ? const Color(0xFF1A1A1A)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text('ORD-00001',
                  style: TextStyle(fontSize: baseFz - 3),
                  textAlign: TextAlign.center),
            ],
            if (footer.trim().isNotEmpty) ...[
              const Text(divLine),
              Text(footer.trim(), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 4),
            Text(
              _paperLabel,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String left;
  final String right;
  final bool bold;
  final double fontSize;

  const _PreviewRow({
    required this.left,
    required this.right,
    this.bold = false,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Courier',
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: const Color(0xFF1A1A1A),
    );
    if (right.isEmpty) {
      return Text(left, style: style);
    }
    final spaces = ' ' *
        (32 - left.length - right.length)
            .clamp(1, 32);
    return Text('$left$spaces$right', style: style);
  }
}
