import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../data/users_repository.dart';
import '../providers/users_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/user_model.dart';

class _BranchItem {
  final String id;
  final String name;
  const _BranchItem({required this.id, required this.name});
}

final _branchesForFormProvider =
    FutureProvider.autoDispose.family<List<_BranchItem>, String>((ref, tenantId) async {
  if (tenantId.isEmpty) return [];
  try {
    final resp = await apiClient.dio.get(
      '/tenants/$tenantId/branches',
      queryParameters: {'page_size': 100},
    );
    final data = resp.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return _BranchItem(id: m['id'] as String, name: m['name'] as String? ?? '');
    }).toList();
  } on DioException {
    return [];
  }
});

class UserFormScreen extends ConsumerStatefulWidget {
  final UserModel? user;
  const UserFormScreen({super.key, this.user});

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = UserRole.cashier;
  String? _selectedBranchId;
  bool _isLoading = false;
  bool _isResettingPassword = false;
  bool _showPassword = false;
  bool _showNewPassword = false;

  bool get _isEdit => widget.user != null;

  final _roles = [
    UserRole.cashier,
    UserRole.manager,
    UserRole.inventoryStaff,
    UserRole.businessOwner,
  ];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _firstNameController.text = widget.user!.firstName;
      _lastNameController.text = widget.user!.lastName;
      _emailController.text = widget.user!.email;
      _phoneController.text = widget.user!.phone ?? '';
      _selectedRole = widget.user!.role;
      _selectedBranchId = widget.user!.primaryBranchId;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = <String, dynamic>{
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'role': _selectedRole,
      if (_phoneController.text.trim().isNotEmpty)
        'phone': _phoneController.text.trim(),
      if (_selectedBranchId != null) 'primary_branch_id': _selectedBranchId,
      if (!_isEdit && _passwordController.text.isNotEmpty)
        'password': _passwordController.text,
    };

    try {
      final repo = ref.read(usersRepositoryProvider);
      UserModel result;
      if (_isEdit) {
        result = await repo.updateUser(widget.user!.id, data);
        ref.read(usersProvider.notifier).updateItem(result);
      } else {
        result = await repo.createUser(data);
        ref.read(usersProvider.notifier).addItem(result);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    final newPw = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (newPw.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }
    if (newPw != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    setState(() => _isResettingPassword = true);
    try {
      await ref.read(usersRepositoryProvider).resetPassword(widget.user!.id, newPw);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(authProvider).user?.tenantId ?? '';
    final branchesAsync = ref.watch(_branchesForFormProvider(tenantId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(_isEdit ? 'Edit Staff' : 'New Staff'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isLoading ? null : _save,
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
      body: ContentWrapper(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Account Info section
              _SectionHeader(title: 'Account Info'),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      style:
                          const TextStyle(color: AppColors.textPrimary),
                      decoration: _fieldDecoration(label: 'First Name *'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      style:
                          const TextStyle(color: AppColors.textPrimary),
                      decoration: _fieldDecoration(label: 'Last Name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _fieldDecoration(
                  label: 'Email *',
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: AppColors.textSecondary),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _fieldDecoration(
                  label: 'Phone',
                  prefixIcon: const Icon(Icons.phone_outlined,
                      color: AppColors.textSecondary),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 28),

              // Role & Permissions section
              _SectionHeader(title: 'Role & Permissions'),
              const SizedBox(height: 12),
              // Role segmented selector
              _RoleSelector(
                roles: _roles,
                selected: _selectedRole,
                onChanged: (r) => setState(() => _selectedRole = r),
              ),
              const SizedBox(height: 16),
              branchesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (branches) => branches.isEmpty
                    ? const SizedBox.shrink()
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedBranchId,
                        decoration: _fieldDecoration(
                          label: 'Primary Branch',
                          prefixIcon: const Icon(Icons.store_outlined,
                              color: AppColors.textSecondary),
                        ),
                        dropdownColor: AppColors.surfaceVariant,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        iconEnabledColor: AppColors.textSecondary,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No branch assigned',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          ...branches.map((b) => DropdownMenuItem<String>(
                                value: b.id,
                                child: Text(b.name),
                              )),
                        ],
                        onChanged: (v) => setState(() => _selectedBranchId = v),
                      ),
              ),
              const SizedBox(height: 28),

              // Reset Password section (edit only)
              if (_isEdit) ...[
                _SectionHeader(title: 'Reset Password'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set a new password for this staff member.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPasswordController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _fieldDecoration(
                          label: 'New Password',
                          prefixIcon: const Icon(Icons.lock_outlined,
                              color: AppColors.textSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showNewPassword ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                          ),
                        ),
                        obscureText: !_showNewPassword,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirmPasswordController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _fieldDecoration(
                          label: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outlined,
                              color: AppColors.textSecondary),
                        ),
                        obscureText: !_showNewPassword,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _isResettingPassword ? null : _resetPassword,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isResettingPassword
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.primary),
                                )
                              : const Text('Reset Password',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // Security section (create only)
              if (!_isEdit) ...[
                _SectionHeader(title: 'Security'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _fieldDecoration(
                    label: 'Password *',
                    prefixIcon: const Icon(Icons.lock_outlined,
                        color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  obscureText: !_showPassword,
                  validator: _isEdit
                      ? null
                      : (v) => v == null || v.length < 8
                          ? 'Min 8 characters'
                          : null,
                ),
                const SizedBox(height: 28),
              ],

              // Submit
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primaryFg,
                          ),
                        )
                      : Text(
                          _isEdit ? 'Update Staff' : 'Create Staff',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// Helpers

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        const Divider(color: AppColors.divider, height: 1),
      ],
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final List<String> roles;
  final String selected;
  final ValueChanged<String> onChanged;

  const _RoleSelector({
    required this.roles,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: roles.map((role) {
        final isSelected = role == selected;
        return GestureDetector(
          onTap: () => onChanged(role),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.divider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    UserRole.displayName(role),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle,
                      size: 18, color: AppColors.primary),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
