import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/error_view.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _UserDetail {
  final String id;
  final String fullName;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String role;
  final String status;
  final String createdAt;
  final String? tenantId;
  final String? businessName;

  const _UserDetail({
    required this.id,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    required this.role,
    required this.status,
    required this.createdAt,
    this.tenantId,
    this.businessName,
  });

  factory _UserDetail.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name'] as String? ?? '';
    final lastName = json['last_name'] as String? ?? '';
    final fullName = (json['full_name'] as String?)?.isNotEmpty == true
        ? json['full_name'] as String
        : '$firstName $lastName'.trim();
    return _UserDetail(
      id: json['id'] as String,
      fullName: fullName,
      firstName: firstName,
      lastName: lastName,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      status: json['status'] as String? ?? 'ACTIVE',
      createdAt: json['created_at'] as String? ?? '',
      tenantId: json['tenant_id'] as String?,
      businessName: json['business_name'] as String?,
    );
  }

  String get initials {
    final parts = fullName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// Role labels
// ---------------------------------------------------------------------------

const _roleLabels = {
  'SUPER_ADMIN': 'Super Admin',
  'RESELLER': 'Reseller',
  'BUSINESS_OWNER': 'Business Owner',
  'MANAGER': 'Manager',
  'CASHIER': 'Cashier',
  'INVENTORY_STAFF': 'Inventory Staff',
};

String _roleLabel(String role) => _roleLabels[role] ?? role;

// ---------------------------------------------------------------------------
// Dio getter (never stored as a field)
// ---------------------------------------------------------------------------

Dio get _dio => apiClient.dio;

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState
    extends ConsumerState<AdminUserDetailScreen> {
  _UserDetail? _user;
  bool _isLoading = true;
  String? _error;
  bool _isStatusLoading = false;

  // Lifecycle

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  // API calls

  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _dio.get('/users/${widget.userId}');
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _user = _UserDetail.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = AppException.fromDio(e is DioException
                ? e
                : DioException(
                    requestOptions: RequestOptions(path: ''),
                    error: e,
                  ))
            .message;
        _isLoading = false;
      });
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    setState(() => _isStatusLoading = true);
    try {
      await _dio.patch(
        '/users/${widget.userId}/status',
        data: {'status': newStatus},
      );
      await _loadUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: AppColors.successLight,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppException.fromDio(e is DioException
                    ? e
                    : DioException(
                        requestOptions: RequestOptions(path: ''),
                        error: e,
                      ))
                .message),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStatusLoading = false);
    }
  }

  // Dialogs / Sheets

  Future<void> _confirmSuspend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Suspend User',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to suspend "${_user?.fullName}"? They will no longer be able to sign in.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: AppColors.primaryFg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Suspend',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _changeStatus('SUSPENDED');
    }
  }

  void _showResetPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ResetPasswordSheet(userId: widget.userId),
    );
  }

  // Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _user?.fullName ?? 'User Detail',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_user != null) ...[
              const SizedBox(width: 8),
              StatusBadge(status: _user!.status),
            ],
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _loadUser);
    }
    if (_user == null) {
      return const ErrorView(message: 'User not found.');
    }

    final user = _user!;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _loadUser,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Center(
              child: CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Profile section
            _SectionHeader(label: 'Profile'),
            const SizedBox(height: 12),
            _InfoCard(
              children: [
                _InfoRow(label: 'Full Name', value: user.fullName),
                _divider(),
                _InfoRow(label: 'Email', value: user.email),
                if (user.phone != null && user.phone!.isNotEmpty) ...[
                  _divider(),
                  _InfoRow(label: 'Phone', value: user.phone!),
                ],
                _divider(),
                _InfoRowWidget(
                  label: 'Role',
                  child: _RoleBadge(role: user.role),
                ),
                _divider(),
                _InfoRowWidget(
                  label: 'Status',
                  child: StatusBadge(status: user.status),
                ),
                _divider(),
                _InfoRow(
                  label: 'Created',
                  value: _formatDate(user.createdAt),
                ),
              ],
            ),

            // Business section
            if (user.tenantId != null || user.businessName != null) ...[
              const SizedBox(height: 24),
              _SectionHeader(label: 'Business'),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  if (user.businessName != null)
                    _InfoRow(label: 'Business', value: user.businessName!),
                  if (user.role == 'RESELLER') ...[
                    if (user.businessName != null) _divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context
                              .push('/admin/resellers-detail/${user.id}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.info,
                            side: BorderSide(
                                color: AppColors.info.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.store_outlined, size: 17),
                          label: const Text(
                            'View Reseller Detail',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // Actions section
            const SizedBox(height: 24),
            _SectionHeader(label: 'Actions'),
            const SizedBox(height: 12),
            _isStatusLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    ),
                  )
                : Column(
                    children: [
                      if (user.status == 'ACTIVE')
                        _ActionButton(
                          label: 'Suspend User',
                          icon: Icons.block_outlined,
                          foregroundColor: AppColors.warning,
                          borderColor: AppColors.warning.withValues(alpha: 0.5),
                          onTap: _confirmSuspend,
                        )
                      else ...[
                        _ActionButton(
                          label: 'Activate User',
                          icon: Icons.check_circle_outline,
                          foregroundColor: AppColors.success,
                          borderColor:
                              AppColors.success.withValues(alpha: 0.5),
                          onTap: () => _changeStatus('ACTIVE'),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _ActionButton(
                        label: 'Reset Password',
                        icon: Icons.lock_reset_outlined,
                        foregroundColor: AppColors.textSecondary,
                        borderColor: AppColors.border,
                        onTap: _showResetPasswordSheet,
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, thickness: 1, color: AppColors.divider);

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
    } catch (_) {
      return raw;
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

// ---------------------------------------------------------------------------
// Reset Password Bottom Sheet
// ---------------------------------------------------------------------------

class _ResetPasswordSheet extends ConsumerStatefulWidget {
  final String userId;
  const _ResetPasswordSheet({required this.userId});

  @override
  ConsumerState<_ResetPasswordSheet> createState() =>
      _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends ConsumerState<_ResetPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _newObscure = true;
  bool _confirmObscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _dio.post(
        '/users/${widget.userId}/reset-password',
        data: {'new_password': _newPwCtrl.text},
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully'),
            backgroundColor: AppColors.successLight,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = AppException.fromDio(e is DioException
                ? e
                : DioException(
                    requestOptions: RequestOptions(path: ''),
                    error: e,
                  ))
            .message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Reset Password',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 20),

            // New password
            TextFormField(
              controller: _newPwCtrl,
              obscureText: _newObscure,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDecoration(
                label: 'New Password',
                suffix: IconButton(
                  icon: Icon(
                    _newObscure ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _newObscure = !_newObscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 8) return 'Minimum 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Confirm password
            TextFormField(
              controller: _confirmPwCtrl,
              obscureText: _confirmObscure,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDecoration(
                label: 'Confirm Password',
                suffix: IconButton(
                  icon: Icon(
                    _confirmObscure ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _confirmObscure = !_confirmObscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _newPwCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryFg,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryFg,
                        ),
                      )
                    : const Text(
                        'Reset',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String label, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
    );
  }
}

// ---------------------------------------------------------------------------
// Small reusable widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRowWidget extends StatelessWidget {
  final String label;
  final Widget child;
  const _InfoRowWidget({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const Spacer(),
          child,
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        _roleLabel(role),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: BorderSide(color: borderColor),
          backgroundColor: foregroundColor.withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }
}
