import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

class TaxSettingsScreen extends ConsumerStatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  ConsumerState<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends ConsumerState<TaxSettingsScreen> {
  static const _prefsKey = 'tax_settings';

  bool _loading = true;
  bool _saving = false;

  bool _taxEnabled = false;
  final _rateCtrl = TextEditingController(text: '0');
  final _nameCtrl = TextEditingController(text: 'Tax');
  String _taxType = 'exclusive'; // 'inclusive' or 'exclusive'

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _taxEnabled = prefs.getBool('${_prefsKey}_enabled') ?? false;
      _rateCtrl.text =
          (prefs.getDouble('${_prefsKey}_rate') ?? 0.0).toString();
      _nameCtrl.text = prefs.getString('${_prefsKey}_name') ?? 'Tax';
      _taxType = prefs.getString('${_prefsKey}_type') ?? 'exclusive';

      // Also fetch from server and override local values
      final tenantId = ref.read(currentUserProvider)?.tenantId ?? '';
      if (tenantId.isNotEmpty) {
        try {
          final res = await apiClient.dio
              .get(ApiEndpoints.tenantSettings(tenantId));
          final data = res.data as Map<String, dynamic>? ?? {};
          final serverRate = data['tax_rate'];
          if (serverRate != null) {
            _rateCtrl.text = serverRate.toString();
          }
          final serverInclusive = data['tax_inclusive'] as bool?;
          if (serverInclusive != null) {
            _taxType = serverInclusive ? 'inclusive' : 'exclusive';
          }
        } catch (_) {
          // Fall back to local prefs
        }
      }
    } catch (_) {
      // Use defaults
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final rate = double.tryParse(_rateCtrl.text);
    if (_taxEnabled && (rate == null || rate < 0 || rate > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid tax rate between 0 and 100'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('${_prefsKey}_enabled', _taxEnabled);
      await prefs.setDouble('${_prefsKey}_rate', rate ?? 0.0);
      await prefs.setString('${_prefsKey}_name', _nameCtrl.text.trim());
      await prefs.setString('${_prefsKey}_type', _taxType);

      // Also persist to server
      final tenantId = ref.read(currentUserProvider)?.tenantId ?? '';
      if (tenantId.isNotEmpty) {
        try {
          await apiClient.dio.patch(
            ApiEndpoints.tenantSettings(tenantId),
            data: {
              'tax_rate': rate ?? 0.0,
              'tax_inclusive': _taxType == 'inclusive',
            },
          );
        } catch (_) {
          // Best-effort: ignore server errors, local save succeeded
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tax settings saved'),
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
        title: const Text('Tax Settings',
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
                  // Enable tax toggle
                  _sectionHeader('TAX'),
                  const SizedBox(height: 8),
                  _card(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Enable Tax',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Apply tax to all sales transactions',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                      value: _taxEnabled,
                      onChanged: (v) => setState(() => _taxEnabled = v),
                      activeThumbColor: AppColors.primaryFg,
                      activeTrackColor: AppColors.primary,
                    ),
                  ),

                  if (_taxEnabled) ...[
                    const SizedBox(height: 20),

                    // Tax details
                    _sectionHeader('TAX DETAILS'),
                    const SizedBox(height: 8),
                    _card(
                      child: Column(
                        children: [
                          // Tax name
                          TextFormField(
                            controller: _nameCtrl,
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                            decoration: _inputDecoration(
                              label: 'Tax Name',
                              hint: 'e.g. GST, VAT, SST',
                              prefixIcon: Icons.label_outline,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Tax rate
                          TextFormField(
                            controller: _rateCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                            decoration: _inputDecoration(
                              label: 'Tax Rate',
                              hint: '0.0',
                              prefixIcon: Icons.percent,
                            ).copyWith(
                              suffixText: '%',
                              suffixStyle: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tax type
                    _sectionHeader('TAX TYPE'),
                    const SizedBox(height: 8),
                    _card(
                      child: RadioGroup<String>(
                        groupValue: _taxType,
                        onChanged: (v) => setState(() => _taxType = v!),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Exclusive',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                              subtitle: const Text(
                                'Tax is added on top of the price (price + tax)',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                              value: 'exclusive',
                              fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary),
                            ),
                            Divider(height: 1, color: AppColors.divider),
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Inclusive',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                              subtitle: const Text(
                                'Tax is already included in the price',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                              value: 'inclusive',
                              fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

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
