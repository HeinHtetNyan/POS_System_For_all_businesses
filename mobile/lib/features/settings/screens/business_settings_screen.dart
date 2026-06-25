import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

class BusinessSettingsScreen extends ConsumerStatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  ConsumerState<BusinessSettingsScreen> createState() =>
      _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState
    extends ConsumerState<BusinessSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  // Business info controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Timezone
  static const List<String> _timezones = [
    'UTC',
    'Asia/Yangon',
    'Asia/Bangkok',
    'Asia/Singapore',
    'Asia/Tokyo',
    'Asia/Shanghai',
    'Asia/Kolkata',
    'Asia/Dubai',
    'Europe/London',
    'Europe/Paris',
    'Europe/Berlin',
    'America/New_York',
    'America/Chicago',
    'America/Los_Angeles',
    'Australia/Sydney',
    'Pacific/Auckland',
  ];
  String _timezone = 'Asia/Yangon';

  // Business hours: Mon=0 .. Sun=6
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<bool> _dayEnabled =
      List.generate(7, (i) => i < 5); // Mon-Fri on by default
  final List<TimeOfDay> _openTime =
      List.generate(7, (_) => const TimeOfDay(hour: 9, minute: 0));
  final List<TimeOfDay> _closeTime =
      List.generate(7, (_) => const TimeOfDay(hour: 18, minute: 0));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tenantId =
        ref.read(currentUserProvider)?.tenantId ?? '';
    if (tenantId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await apiClient.dio
          .get(ApiEndpoints.tenant(tenantId));
      final data = res.data as Map<String, dynamic>? ?? {};
      _nameCtrl.text = data['name'] as String? ?? '';
      _phoneCtrl.text = data['phone'] as String? ?? '';
      _emailCtrl.text = data['email'] as String? ?? '';
      _addressCtrl.text = data['address'] as String? ?? '';

      // Timezone
      final tz = data['timezone'] as String? ?? 'Asia/Yangon';
      _timezone = _timezones.contains(tz) ? tz : 'Asia/Yangon';

      // Parse business hours if present
      final hours =
          data['business_hours'] as List<dynamic>? ?? [];
      for (final h in hours) {
        if (h is Map<String, dynamic>) {
          final idx = h['day_index'] as int?;
          if (idx != null && idx >= 0 && idx < 7) {
            _dayEnabled[idx] = h['enabled'] as bool? ?? false;
            final open = h['open'] as String? ?? '09:00';
            final close = h['close'] as String? ?? '18:00';
            _openTime[idx] = _parseTime(open);
            _closeTime[idx] = _parseTime(close);
          }
        }
      }
    } catch (_) {
      // Best-effort: start with empty form
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0);
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final tenantId =
        ref.read(currentUserProvider)?.tenantId ?? '';
    if (tenantId.isEmpty) return;

    setState(() => _saving = true);
    try {
      final hours = List.generate(
        7,
        (i) => {
          'day_index': i,
          'day': _days[i],
          'enabled': _dayEnabled[i],
          'open': _formatTime(_openTime[i]),
          'close': _formatTime(_closeTime[i]),
        },
      );

      await apiClient.dio.patch(
        ApiEndpoints.tenant(tenantId),
        data: {
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'timezone': _timezone,
          'business_hours': hours,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business settings saved'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
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

  Future<void> _pickTime(int dayIdx, bool isOpen) async {
    final initial = isOpen ? _openTime[dayIdx] : _closeTime[dayIdx];
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: AppColors.primaryFg,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isOpen) {
          _openTime[dayIdx] = picked;
        } else {
          _closeTime[dayIdx] = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Business Settings',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary))
          : (ref.read(currentUserProvider)?.tenantId ?? '').isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_outlined,
                            size: 56, color: AppColors.textDisabled),
                        SizedBox(height: 16),
                        Text(
                          'No business associated with your account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                )
              : ContentWrapper(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Business Info section
                    _sectionHeader('BUSINESS INFO'),
                    const SizedBox(height: 8),
                    _card(
                      child: Column(
                        children: [
                          _field(
                            controller: _nameCtrl,
                            label: 'Business Name',
                            icon: Icons.business_outlined,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _phoneCtrl,
                            label: 'Phone',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _emailCtrl,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _addressCtrl,
                            label: 'Address',
                            icon: Icons.location_on_outlined,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          _timezoneDropdown(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Business Hours section
                    _sectionHeader('BUSINESS HOURS'),
                    const SizedBox(height: 8),
                    _card(
                      child: Column(
                        children: List.generate(7, (i) {
                          return _HourRow(
                            day: _days[i],
                            enabled: _dayEnabled[i],
                            openTime: _openTime[i],
                            closeTime: _closeTime[i],
                            onToggle: (v) =>
                                setState(() => _dayEnabled[i] = v),
                            onTapOpen: () => _pickTime(i, true),
                            onTapClose: () => _pickTime(i, false),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Save button
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
                            : const Text('Save Changes',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _timezoneDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _timezone,
      onChanged: (v) {
        if (v != null) setState(() => _timezone = v);
      },
      decoration: InputDecoration(
        labelText: 'Timezone',
        prefixIcon: const Icon(Icons.public_outlined,
            color: AppColors.textSecondary, size: 20),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      dropdownColor: AppColors.surfaceVariant,
      iconEnabledColor: AppColors.textSecondary,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      isExpanded: true,
      items: _timezones
          .map((tz) => DropdownMenuItem(
                value: tz,
                child: Text(tz),
              ))
          .toList(),
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
        child: child,
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}

class _HourRow extends StatelessWidget {
  final String day;
  final bool enabled;
  final TimeOfDay openTime;
  final TimeOfDay closeTime;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTapOpen;
  final VoidCallback onTapClose;

  const _HourRow({
    required this.day,
    required this.enabled,
    required this.openTime,
    required this.closeTime,
    required this.onToggle,
    required this.onTapOpen,
    required this.onTapClose,
  });

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              day,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onToggle,
            activeThumbColor: AppColors.primaryFg,
            activeTrackColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          if (enabled) ...[
            Expanded(
              child: GestureDetector(
                onTap: onTapOpen,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    _fmt(openTime),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 12),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('–',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            Expanded(
              child: GestureDetector(
                onTap: onTapClose,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    _fmt(closeTime),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 12),
                  ),
                ),
              ),
            ),
          ] else
            Expanded(
              child: Text(
                'Closed',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}
