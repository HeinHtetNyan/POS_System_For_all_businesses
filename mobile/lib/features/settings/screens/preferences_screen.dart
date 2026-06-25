import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  static const _prefsKey = 'user_preferences';

  bool _loading = true;
  bool _saving = false;

  final _currencySymbolCtrl = TextEditingController(text: 'MMK');
  String _numberFormat = '1,000'; // '1,000' or '1.000'
  int _decimalPlaces = 0; // 0 or 2
  String _dateFormat = 'DD/MM/YYYY'; // 'DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'
  String _defaultPayment = 'CASH'; // 'CASH' or 'CARD'
  bool _autoPrintReceipt = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _currencySymbolCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currencySymbolCtrl.text =
          prefs.getString('${_prefsKey}_currency_symbol') ?? 'MMK';
      _numberFormat =
          prefs.getString('${_prefsKey}_number_format') ?? '1,000';
      _decimalPlaces =
          prefs.getInt('${_prefsKey}_decimal_places') ?? 0;
      _dateFormat =
          prefs.getString('${_prefsKey}_date_format') ?? 'DD/MM/YYYY';
      _defaultPayment = prefs.getString('${_prefsKey}_default_payment') ?? 'CASH';
      _autoPrintReceipt = prefs.getBool('${_prefsKey}_auto_print_receipt') ?? false;
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
      await prefs.setString('${_prefsKey}_currency_symbol',
          _currencySymbolCtrl.text.trim().isEmpty
              ? 'MMK'
              : _currencySymbolCtrl.text.trim());
      await prefs.setString(
          '${_prefsKey}_number_format', _numberFormat);
      await prefs.setInt(
          '${_prefsKey}_decimal_places', _decimalPlaces);
      await prefs.setString('${_prefsKey}_date_format', _dateFormat);
      await prefs.setString('${_prefsKey}_default_payment', _defaultPayment);
      await prefs.setBool('${_prefsKey}_auto_print_receipt', _autoPrintReceipt);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Preferences',
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
                  // Currency display
                  _sectionHeader('CURRENCY DISPLAY'),
                  const SizedBox(height: 8),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _currencySymbolCtrl,
                          style: const TextStyle(
                              color: AppColors.textPrimary),
                          decoration: _inputDecoration(
                            label: 'Currency Symbol',
                            hint: 'e.g. MMK, USD, THB',
                            prefixIcon: Icons.currency_exchange,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Number Format',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        RadioGroup<String>(
                          groupValue: _numberFormat,
                          onChanged: (v) =>
                              setState(() => _numberFormat = v!),
                          child: Column(
                            children: [
                              RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text('1,000 (comma separator)',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13)),
                                value: '1,000',
                                fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary),
                              ),
                              RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text('1.000 (period separator)',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13)),
                                value: '1.000',
                                fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: AppColors.divider, height: 16),
                        const Text(
                          'Decimal Places',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        RadioGroup<int>(
                          groupValue: _decimalPlaces,
                          onChanged: (v) =>
                              setState(() => _decimalPlaces = v!),
                          child: Column(
                            children: [
                              RadioListTile<int>(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text('0 (e.g. 1,500)',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13)),
                                value: 0,
                                fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary),
                              ),
                              RadioListTile<int>(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text('2 (e.g. 1,500.00)',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13)),
                                value: 2,
                                fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Date format
                  _sectionHeader('DATE FORMAT'),
                  const SizedBox(height: 8),
                  _card(
                    child: RadioGroup<String>(
                      groupValue: _dateFormat,
                      onChanged: (v) => setState(() => _dateFormat = v!),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('DD/MM/YYYY',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                            subtitle: const Text('e.g. 25/06/2026',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                            value: 'DD/MM/YYYY',
                            fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary),
                          ),
                          Divider(height: 1, color: AppColors.divider),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('MM/DD/YYYY',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                            subtitle: const Text('e.g. 06/25/2026',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                            value: 'MM/DD/YYYY',
                            fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary),
                          ),
                          Divider(height: 1, color: AppColors.divider),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('YYYY-MM-DD',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                            subtitle: const Text('e.g. 2026-06-25',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                            value: 'YYYY-MM-DD',
                            fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _sectionHeader('CHECKOUT DEFAULTS'),
                  const SizedBox(height: 8),
                  _card(
                    child: Column(
                      children: [
                        // Default Payment Method
                        const Text('Default Payment Method', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _paymentChip('Cash', 'CASH', Icons.money_outlined),
                            const SizedBox(width: 8),
                            _paymentChip('Card', 'CARD', Icons.credit_card_outlined),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.divider, height: 1),
                        const SizedBox(height: 8),
                        // Auto-Print Receipt
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Auto-Print Receipt', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                          subtitle: const Text('Automatically print after each sale', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          value: _autoPrintReceipt,
                          onChanged: (v) => setState(() => _autoPrintReceipt = v),
                          activeThumbColor: AppColors.primary,
                          activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Theme
                  _sectionHeader('THEME'),
                  const SizedBox(height: 8),
                  _card(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.dark_mode_outlined,
                          color: AppColors.primary),
                      title: const Text('Dark Theme',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      subtitle: const Text('Dark theme is active',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
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
                          : const Text('Save Preferences',
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

  Widget _paymentChip(String label, String value, IconData icon) {
    final selected = _defaultPayment == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _defaultPayment = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textSecondary)),
            ],
          ),
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

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textDisabled),
      prefixIcon:
          Icon(prefixIcon, color: AppColors.textSecondary, size: 20),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}
