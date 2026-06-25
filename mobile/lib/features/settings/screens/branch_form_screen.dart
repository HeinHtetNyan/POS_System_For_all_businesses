import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import 'branches_screen.dart';

class BranchFormScreen extends StatefulWidget {
  final BranchModel? branch;
  final String tenantId;

  const BranchFormScreen({
    super.key,
    this.branch,
    required this.tenantId,
  });

  @override
  State<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends State<BranchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _currencyController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;

  bool get _isEdit => widget.branch != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameController.text = widget.branch!.name;
      _phoneController.text = widget.branch!.phone ?? '';
      _addressController.text = widget.branch!.address ?? '';
      _cityController.text = widget.branch!.city ?? '';
      _timezoneController.text = widget.branch!.timezone ?? '';
      _currencyController.text = widget.branch!.currency ?? '';
      _isActive = widget.branch!.status == 'active';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _timezoneController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final String name = _nameController.text.trim();
    final String phone = _phoneController.text.trim();
    final String address = _addressController.text.trim();
    final String city = _cityController.text.trim();
    final String timezone = _timezoneController.text.trim();
    final String currency = _currencyController.text.trim();
    final String status = _isActive ? 'active' : 'inactive';

    try {
      if (_isEdit) {
        final Map<String, dynamic> payload = {};
        if (name != widget.branch!.name) payload['name'] = name;
        if (phone != (widget.branch!.phone ?? '')) {
          payload['phone'] = phone.isEmpty ? null : phone;
        }
        if (address != (widget.branch!.address ?? '')) {
          payload['address'] = address.isEmpty ? null : address;
        }
        if (city != (widget.branch!.city ?? '')) {
          payload['city'] = city.isEmpty ? null : city;
        }
        if (timezone != (widget.branch!.timezone ?? '')) {
          payload['timezone'] = timezone.isEmpty ? null : timezone;
        }
        if (currency != (widget.branch!.currency ?? '')) {
          payload['currency'] = currency.isEmpty ? null : currency;
        }
        if (status != widget.branch!.status) payload['status'] = status;

        if (payload.isNotEmpty) {
          await apiClient.patch(
            '/tenants/${widget.tenantId}/branches/${widget.branch!.id}',
            data: payload,
          );
        }
      } else {
        final Map<String, dynamic> payload = {
          'name': name,
          'status': status,
          if (phone.isNotEmpty) 'phone': phone,
          if (address.isNotEmpty) 'address': address,
          if (city.isNotEmpty) 'city': city,
          if (timezone.isNotEmpty) 'timezone': timezone,
          if (currency.isNotEmpty) 'currency': currency,
        };
        await apiClient.post(
          '/tenants/${widget.tenantId}/branches',
          data: payload,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppException.fromDio(e).message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          _isEdit ? 'Edit Branch' : 'New Branch',
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: ContentWrapper(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionLabel(label: 'BRANCH DETAILS'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Branch Name *',
                  labelStyle:
                      const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.store_outlined,
                      color: AppColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.error, width: 1.5),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: 'CONTACT'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: AppColors.textPrimary),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  labelStyle:
                      const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.phone_outlined,
                      color: AppColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Address',
                  labelStyle:
                      const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.location_on_outlined,
                        color: AppColors.textSecondary, size: 20),
                  ),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'City',
                  labelStyle:
                      const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.location_city_outlined,
                      color: AppColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: 'LOCALE'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _timezoneController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Timezone',
                        hintText: 'UTC',
                        labelStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        hintStyle:
                            const TextStyle(color: AppColors.textDisabled),
                        prefixIcon: const Icon(Icons.schedule_outlined,
                            color: AppColors.textSecondary, size: 20),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _currencyController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Currency',
                        hintText: 'MMK',
                        labelStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        hintStyle:
                            const TextStyle(color: AppColors.textDisabled),
                        prefixIcon: const Icon(Icons.attach_money_outlined,
                            color: AppColors.textSecondary, size: 20),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: 'STATUS'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  activeThumbColor: AppColors.primaryFg,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: AppColors.textSecondary,
                  inactiveTrackColor: AppColors.surfaceVariant,
                  title: Text(
                    _isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: _isActive
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Branch is open and operational'
                        : 'Branch is currently closed',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryFg,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryFg,
                          ),
                        )
                      : Text(
                          _isEdit ? 'Update Branch' : 'Create Branch',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.0,
      ),
    );
  }
}
