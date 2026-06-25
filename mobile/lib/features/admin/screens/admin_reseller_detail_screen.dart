import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/utils/currency_formatter.dart';

// local data models

class _ResellerUser {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final String status;
  final double commissionRate;
  final double walletBalance;
  final DateTime createdAt;
  final String? businessName;

  const _ResellerUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    required this.status,
    required this.commissionRate,
    required this.walletBalance,
    required this.createdAt,
    this.businessName,
  });

  factory _ResellerUser.fromJson(Map<String, dynamic> j) => _ResellerUser(
        id: j['id'] as String,
        fullName: j['full_name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        phone: j['phone'] as String?,
        role: j['role'] as String? ?? 'RESELLER',
        status: j['status'] as String? ?? 'ACTIVE',
        commissionRate: (j['commission_rate'] as num?)?.toDouble() ?? 0.0,
        walletBalance: (j['wallet_balance'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.parse(j['created_at'] as String),
        businessName: j['business_name'] as String?,
      );
}

class _WalletSummary {
  final double balance;
  final double totalEarned;
  final double totalWithdrawn;

  const _WalletSummary({
    required this.balance,
    required this.totalEarned,
    required this.totalWithdrawn,
  });

  factory _WalletSummary.fromJson(Map<String, dynamic> j) => _WalletSummary(
        balance: (j['balance'] as num?)?.toDouble() ?? 0.0,
        totalEarned: (j['total_earned'] as num?)?.toDouble() ?? 0.0,
        totalWithdrawn: (j['total_withdrawn'] as num?)?.toDouble() ?? 0.0,
      );
}

class _ReferralItem {
  final String id;
  final String tenantName;
  final String status;
  final DateTime joinedDate;

  const _ReferralItem({
    required this.id,
    required this.tenantName,
    required this.status,
    required this.joinedDate,
  });

  factory _ReferralItem.fromJson(Map<String, dynamic> j) => _ReferralItem(
        id: j['id'] as String,
        tenantName: j['tenant_name'] as String? ?? j['business_name'] as String? ?? '',
        status: j['status'] as String? ?? 'ACTIVE',
        joinedDate: DateTime.parse(
          j['joined_date'] as String? ??
              j['joined_at'] as String? ??
              j['created_at'] as String,
        ),
      );
}

class _TxItem {
  final String id;
  final String type;
  final double amount;
  final String? description;
  final DateTime createdAt;

  const _TxItem({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    required this.createdAt,
  });

  bool get isCredit => const {
        'COMMISSION',
        'CREDIT',
        'ADJUSTMENT_CREDIT',
        'REFERRAL_BONUS',
      }.contains(type.toUpperCase());

  factory _TxItem.fromJson(Map<String, dynamic> j) => _TxItem(
        id: j['id'] as String,
        type: j['type'] as String? ?? j['transaction_type'] as String? ?? 'CREDIT',
        amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
        description: j['description'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// main screen

class AdminResellerDetailScreen extends ConsumerStatefulWidget {
  final String resellerId;
  const AdminResellerDetailScreen({super.key, required this.resellerId});

  @override
  ConsumerState<AdminResellerDetailScreen> createState() =>
      _AdminResellerDetailScreenState();
}

class _AdminResellerDetailScreenState
    extends ConsumerState<AdminResellerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // data
  _ResellerUser? _user;
  _WalletSummary? _wallet;
  List<_ReferralItem> _referrals = [];
  int _referralTotal = 0;
  List<_TxItem> _transactions = [];
  int _txTotal = 0;

  bool _isLoading = true;
  String? _error;

  Dio get _dio => apiClient.dio;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // data loading

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Future.wait([
        _loadUser(),
        _loadWallet(),
        _loadReferrals(),
        _loadTransactions(),
      ]);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUser() async {
    final res = await _dio.get(ApiEndpoints.user(widget.resellerId));
    final data = res.data as Map<String, dynamic>;
    if (mounted) setState(() => _user = _ResellerUser.fromJson(data));
  }

  Future<void> _loadWallet() async {
    final res = await _dio.get(ApiEndpoints.adminResellerWallet(widget.resellerId));
    final data = res.data as Map<String, dynamic>;
    if (mounted) setState(() => _wallet = _WalletSummary.fromJson(data));
  }

  Future<void> _loadReferrals() async {
    final res = await _dio.get(
      ApiEndpoints.adminResellerReferrals(widget.resellerId),
      queryParameters: {'page_size': 50},
    );
    final data = res.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => _ReferralItem.fromJson(e as Map<String, dynamic>))
        .toList();
    if (mounted) {
      setState(() {
        _referrals = items;
        _referralTotal = data['total'] as int? ?? items.length;
      });
    }
  }

  Future<void> _loadTransactions() async {
    final res = await _dio.get(
      '${ApiEndpoints.adminResellerWallet(widget.resellerId)}/transactions',
      queryParameters: {'page_size': 20},
    );
    final data = res.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => _TxItem.fromJson(e as Map<String, dynamic>))
        .toList();
    if (mounted) {
      setState(() {
        _transactions = items;
        _txTotal = data['total'] as int? ?? items.length;
      });
    }
  }

  // actions

  Future<void> _changeStatus(String newStatus) async {
    if (newStatus == 'SUSPENDED') {
      final confirmed = await _showConfirmDialog(
        title: 'Suspend Reseller',
        message:
            'Are you sure you want to suspend this reseller? They will lose access until reactivated.',
        confirmLabel: 'Suspend',
        confirmColor: AppColors.warning,
      );
      if (confirmed != true) return;
    }

    try {
      await _dio.patch(
        ApiEndpoints.adminUserStatus(widget.resellerId),
        data: {'status': newStatus},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Reseller ${newStatus == 'ACTIVE' ? 'activated' : 'suspended'} successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadUser();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showResetPasswordSheet() async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure1 = true;
    bool obscure2 = true;
    bool saving = false;
    String? sheetError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          Future<void> submit() async {
            final pw = passwordCtrl.text.trim();
            final confirm = confirmCtrl.text.trim();
            if (pw.isEmpty) {
              setSheetState(() => sheetError = 'Password cannot be empty.');
              return;
            }
            if (pw != confirm) {
              setSheetState(
                  () => sheetError = 'Passwords do not match.');
              return;
            }
            setSheetState(() {
              saving = true;
              sheetError = null;
            });
            try {
              await _dio.post(
                ApiEndpoints.adminUserResetPassword(widget.resellerId),
                data: {'new_password': pw},
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset successfully'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              setSheetState(() {
                saving = false;
                sheetError = e.toString();
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_reset_outlined,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Reset Password',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.textSecondary, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _PasswordField(
                  controller: passwordCtrl,
                  label: 'New Password',
                  obscure: obscure1,
                  onToggle: () =>
                      setSheetState(() => obscure1 = !obscure1),
                ),
                const SizedBox(height: 14),
                _PasswordField(
                  controller: confirmCtrl,
                  label: 'Confirm Password',
                  obscure: obscure2,
                  onToggle: () =>
                      setSheetState(() => obscure2 = !obscure2),
                ),
                if (sheetError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    sheetError!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryFg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryFg,
                            ),
                          )
                        : const Text(
                            'Reset Password',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );

    passwordCtrl.dispose();
    confirmCtrl.dispose();
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          message,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: AppColors.primaryFg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(confirmLabel,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // build

  @override
  Widget build(BuildContext context) {
    final title = _user?.fullName ?? 'Reseller Detail';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: _isLoading
            ? Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_user != null) ...[
                    const SizedBox(width: 10),
                    StatusBadge(status: _user!.status),
                  ],
                ],
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(height: 1, color: AppColors.divider),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Referrals'),
                  Tab(text: 'Finance'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? ErrorView(message: _error!, onRetry: _loadAll)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(
                      user: _user!,
                      wallet: _wallet,
                      referralCount: _referralTotal,
                      onChangeStatus: _changeStatus,
                      onResetPassword: _showResetPasswordSheet,
                    ),
                    _ReferralsTab(
                      referrals: _referrals,
                      total: _referralTotal,
                    ),
                    _FinanceTab(
                      wallet: _wallet,
                      transactions: _transactions,
                      txTotal: _txTotal,
                    ),
                  ],
                ),
    );
  }
}

// Tab 0: Overview

class _OverviewTab extends StatelessWidget {
  final _ResellerUser user;
  final _WalletSummary? wallet;
  final int referralCount;
  final Future<void> Function(String) onChangeStatus;
  final Future<void> Function() onResetPassword;

  const _OverviewTab({
    required this.user,
    required this.wallet,
    required this.referralCount,
    required this.onChangeStatus,
    required this.onResetPassword,
  });

  String get _initials {
    final parts = user.fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return user.fullName.isNotEmpty
        ? user.fullName[0].toUpperCase()
        : '?';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile card
          _Card(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (user.phone != null && user.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.phone!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Wallet',
                  value: CurrencyFormatter.format(
                      wallet?.balance ?? user.walletBalance),
                  valueColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  label: 'Total Earned',
                  value: CurrencyFormatter.format(
                      wallet?.totalEarned ?? 0.0),
                  valueColor: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  label: 'Commission',
                  value: '${user.commissionRate.toStringAsFixed(1)}%',
                  valueColor: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Role + client count row
          _Card(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'RESELLER',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.people_outline,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  '$referralCount client${referralCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Status + action buttons
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusBadge(status: user.status),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (user.status == 'ACTIVE')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onChangeStatus('SUSPENDED'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.warning.withValues(alpha: 0.12),
                            foregroundColor: AppColors.warning,
                            elevation: 0,
                            side: BorderSide(
                                color: AppColors.warning
                                    .withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.pause_circle_outline,
                              size: 16),
                          label: const Text(
                            'Suspend',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      )
                    else if (user.status == 'SUSPENDED')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onChangeStatus('ACTIVE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.success.withValues(alpha: 0.12),
                            foregroundColor: AppColors.success,
                            elevation: 0,
                            side: BorderSide(
                                color: AppColors.success
                                    .withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.play_circle_outline,
                              size: 16),
                          label: const Text(
                            'Activate',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                    if (user.status == 'ACTIVE' ||
                        user.status == 'SUSPENDED') ...[
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onResetPassword,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.lock_reset_outlined, size: 16),
                        label: const Text(
                          'Reset Password',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Tab 1: Referrals

class _ReferralsTab extends StatelessWidget {
  final List<_ReferralItem> referrals;
  final int total;

  const _ReferralsTab({required this.referrals, required this.total});

  @override
  Widget build(BuildContext context) {
    if (referrals.isEmpty) {
      return const EmptyView(
        icon: Icons.handshake_outlined,
        title: 'No referrals yet',
        subtitle: 'Businesses referred by this reseller will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: referrals.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '$total Referred Business${total == 1 ? '' : 'es'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }
        final r = referrals[i - 1];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business_outlined,
                      color: AppColors.info, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.tenantName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Joined ${_formatDate(r.joinedDate)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: r.status),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// Tab 2: Finance

class _FinanceTab extends StatelessWidget {
  final _WalletSummary? wallet;
  final List<_TxItem> transactions;
  final int txTotal;

  const _FinanceTab({
    required this.wallet,
    required this.transactions,
    required this.txTotal,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // Wallet summary card
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wallet Summary',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                wallet != null
                    ? CurrencyFormatter.format(wallet!.balance)
                    : '—',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Current Balance',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _WalletStatRow(
                      icon: Icons.trending_up_rounded,
                      iconColor: AppColors.success,
                      label: 'Total Earned',
                      value: wallet != null
                          ? CurrencyFormatter.format(wallet!.totalEarned)
                          : '—',
                      valueColor: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WalletStatRow(
                      icon: Icons.arrow_upward_rounded,
                      iconColor: AppColors.error,
                      label: 'Total Withdrawn',
                      value: wallet != null
                          ? CurrencyFormatter.format(wallet!.totalWithdrawn)
                          : '—',
                      valueColor: AppColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Transactions header
        Text(
          '$txTotal Transaction${txTotal == 1 ? '' : 's'}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          const EmptyView(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions',
            subtitle: 'Wallet activity will appear here.',
          )
        else
          ...transactions.map((tx) => _TxCard(tx: tx)),
      ],
    );
  }
}

class _TxCard extends StatelessWidget {
  final _TxItem tx;
  const _TxCard({required this.tx});

  Color get _typeColor {
    switch (tx.type.toUpperCase()) {
      case 'COMMISSION':
      case 'REFERRAL_BONUS':
      case 'ADJUSTMENT_CREDIT':
      case 'CREDIT':
        return AppColors.success;
      case 'WITHDRAWAL':
      case 'DEBIT':
      case 'PAYOUT':
        return AppColors.error;
      case 'ADJUSTMENT':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  Color get _typeBg {
    switch (tx.type.toUpperCase()) {
      case 'COMMISSION':
      case 'REFERRAL_BONUS':
      case 'ADJUSTMENT_CREDIT':
      case 'CREDIT':
        return AppColors.successLight;
      case 'WITHDRAWAL':
      case 'DEBIT':
      case 'PAYOUT':
        return AppColors.errorLight;
      case 'ADJUSTMENT':
        return AppColors.infoLight;
      default:
        return AppColors.surfaceVariant;
    }
  }

  String get _typeLabel {
    final raw = tx.type.replaceAll('_', ' ');
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() +
        raw.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final amountColor = tx.isCredit ? AppColors.success : AppColors.error;
    final sign = tx.isCredit ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _typeBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: _typeColor.withValues(alpha: 0.25)),
              ),
              child: Text(
                _typeLabel,
                style: TextStyle(
                  color: _typeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tx.description != null &&
                      tx.description!.isNotEmpty) ...[
                    Text(
                      tx.description!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    _formatDateTime(tx.createdAt),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$sign${CurrencyFormatter.format(tx.amount)}',
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m';
  }
}

// Shared helpers

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatChip({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _WalletStatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  const _WalletStatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: iconColor, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.textSecondary,
            size: 18,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
