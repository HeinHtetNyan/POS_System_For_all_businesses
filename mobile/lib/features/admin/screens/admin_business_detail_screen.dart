import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/utils/currency_formatter.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _fmtDate(String? raw) {
  if (raw == null) return '—';
  try {
    final dt = DateTime.parse(raw);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
  } catch (_) {
    return raw;
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AdminBusinessDetailScreen extends ConsumerStatefulWidget {
  final String tenantId;
  const AdminBusinessDetailScreen({super.key, required this.tenantId});

  @override
  ConsumerState<AdminBusinessDetailScreen> createState() =>
      _AdminBusinessDetailScreenState();
}

class _AdminBusinessDetailScreenState
    extends ConsumerState<AdminBusinessDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Overview
  Map<String, dynamic>? _overview;
  bool _overviewLoading = false;
  String? _overviewError;

  // Users
  List<Map<String, dynamic>> _users = [];
  bool _usersLoading = false;
  String? _usersError;
  int _usersPage = 1;
  bool _usersHasMore = true;
  bool _usersLoadingMore = false;

  // Branches
  List<Map<String, dynamic>> _branches = [];
  bool _branchesLoading = false;
  String? _branchesError;

  // Subscription
  Map<String, dynamic>? _subscription;
  bool _subLoading = false;
  String? _subError;

  // Billing — proofs
  List<Map<String, dynamic>> _proofs = [];
  bool _proofsLoading = false;
  String? _proofsError;
  int _proofsPage = 1;
  bool _proofsHasMore = true;
  bool _proofsLoadingMore = false;

  // Billing — history
  List<Map<String, dynamic>> _history = [];
  bool _historyLoading = false;
  String? _historyError;
  int _historyPage = 1;
  bool _historyHasMore = true;
  bool _historyLoadingMore = false;

  // Billing sub-tab
  int _billingTab = 0;

  Dio get _dio => apiClient.dio;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadOverview();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    switch (_tabController.index) {
      case 0:
        if (_overview == null && !_overviewLoading) _loadOverview();
        break;
      case 1:
        if (_users.isEmpty && !_usersLoading) _loadUsers();
        break;
      case 2:
        if (_branches.isEmpty && !_branchesLoading) _loadBranches();
        break;
      case 3:
        if (_subscription == null && !_subLoading) _loadSubscription();
        break;
      case 4:
        if (_proofs.isEmpty && !_proofsLoading) _loadProofs();
        if (_history.isEmpty && !_historyLoading) _loadHistory();
        break;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  // Data loaders

  Future<void> _loadOverview() async {
    setState(() {
      _overviewLoading = true;
      _overviewError = null;
    });
    try {
      final resp = await _dio.get('/tenants/${widget.tenantId}');
      final data = resp.data;
      setState(() {
        _overview = data is Map<String, dynamic> ? data : {};
      });
    } on DioException catch (e) {
      setState(() {
        _overviewError = AppException.fromDio(e).message;
      });
    } catch (e) {
      setState(() {
        _overviewError = e.toString();
      });
    } finally {
      setState(() => _overviewLoading = false);
    }
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (refresh) {
      _usersPage = 1;
      _usersHasMore = true;
      _users = [];
    }
    if (!_usersHasMore) return;
    if (_usersPage == 1) {
      setState(() {
        _usersLoading = true;
        _usersError = null;
      });
    } else {
      setState(() => _usersLoadingMore = true);
    }
    try {
      final resp = await _dio.get(
        '/users',
        queryParameters: {
          'tenant_id': widget.tenantId,
          'page': _usersPage,
          'page_size': 20,
        },
      );
      final data = resp.data;
      final List<dynamic> items;
      if (data is Map<String, dynamic>) {
        items = data['items'] as List<dynamic>? ??
            data['users'] as List<dynamic>? ??
            [];
        final total = data['total'] as int? ?? items.length;
        _usersHasMore = _usersPage * 20 < total;
      } else if (data is List) {
        items = data;
        _usersHasMore = items.length == 20;
      } else {
        items = [];
        _usersHasMore = false;
      }
      setState(() {
        _users.addAll(items.cast<Map<String, dynamic>>());
        _usersPage++;
      });
    } on DioException catch (e) {
      setState(() => _usersError = AppException.fromDio(e).message);
    } catch (e) {
      setState(() => _usersError = e.toString());
    } finally {
      setState(() {
        _usersLoading = false;
        _usersLoadingMore = false;
      });
    }
  }

  Future<void> _loadBranches() async {
    setState(() {
      _branchesLoading = true;
      _branchesError = null;
    });
    try {
      final resp = await _dio.get('/tenants/${widget.tenantId}/branches');
      final data = resp.data;
      List<dynamic> items;
      if (data is Map<String, dynamic>) {
        items = data['items'] as List<dynamic>? ??
            data['branches'] as List<dynamic>? ??
            [];
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }
      setState(() {
        _branches = items.cast<Map<String, dynamic>>();
      });
    } on DioException catch (e) {
      setState(() => _branchesError = AppException.fromDio(e).message);
    } catch (e) {
      setState(() => _branchesError = e.toString());
    } finally {
      setState(() => _branchesLoading = false);
    }
  }

  Future<void> _loadSubscription() async {
    setState(() {
      _subLoading = true;
      _subError = null;
    });
    try {
      final resp = await _dio
          .get('/subscriptions/admin/tenants/${widget.tenantId}');
      final data = resp.data;
      setState(() {
        _subscription = data is Map<String, dynamic> ? data : {};
      });
    } on DioException catch (e) {
      setState(() => _subError = AppException.fromDio(e).message);
    } catch (e) {
      setState(() => _subError = e.toString());
    } finally {
      setState(() => _subLoading = false);
    }
  }

  Future<void> _loadProofs({bool refresh = false}) async {
    if (refresh) {
      _proofsPage = 1;
      _proofsHasMore = true;
      _proofs = [];
    }
    if (!_proofsHasMore) return;
    if (_proofsPage == 1) {
      setState(() {
        _proofsLoading = true;
        _proofsError = null;
      });
    } else {
      setState(() => _proofsLoadingMore = true);
    }
    try {
      final resp = await _dio.get(
        '/subscriptions/admin/payment-proofs',
        queryParameters: {
          'tenant_id': widget.tenantId,
          'page': _proofsPage,
          'page_size': 20,
        },
      );
      final data = resp.data;
      final List<dynamic> items;
      if (data is Map<String, dynamic>) {
        items = data['items'] as List<dynamic>? ??
            data['proofs'] as List<dynamic>? ??
            [];
        final total = data['total'] as int? ?? items.length;
        _proofsHasMore = _proofsPage * 20 < total;
      } else if (data is List) {
        items = data;
        _proofsHasMore = items.length == 20;
      } else {
        items = [];
        _proofsHasMore = false;
      }
      setState(() {
        _proofs.addAll(items.cast<Map<String, dynamic>>());
        _proofsPage++;
      });
    } on DioException catch (e) {
      setState(() => _proofsError = AppException.fromDio(e).message);
    } catch (e) {
      setState(() => _proofsError = e.toString());
    } finally {
      setState(() {
        _proofsLoading = false;
        _proofsLoadingMore = false;
      });
    }
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    if (refresh) {
      _historyPage = 1;
      _historyHasMore = true;
      _history = [];
    }
    if (!_historyHasMore) return;
    if (_historyPage == 1) {
      setState(() {
        _historyLoading = true;
        _historyError = null;
      });
    } else {
      setState(() => _historyLoadingMore = true);
    }
    try {
      final resp = await _dio.get(
        '/subscriptions/admin/tenants/${widget.tenantId}/history',
        queryParameters: {'page': _historyPage, 'page_size': 20},
      );
      final data = resp.data;
      final List<dynamic> items;
      if (data is Map<String, dynamic>) {
        items = data['items'] as List<dynamic>? ??
            data['history'] as List<dynamic>? ??
            [];
        final total = data['total'] as int? ?? items.length;
        _historyHasMore = _historyPage * 20 < total;
      } else if (data is List) {
        items = data;
        _historyHasMore = items.length == 20;
      } else {
        items = [];
        _historyHasMore = false;
      }
      setState(() {
        _history.addAll(items.cast<Map<String, dynamic>>());
        _historyPage++;
      });
    } on DioException catch (e) {
      setState(() => _historyError = AppException.fromDio(e).message);
    } catch (e) {
      setState(() => _historyError = e.toString());
    } finally {
      setState(() {
        _historyLoading = false;
        _historyLoadingMore = false;
      });
    }
  }

  // Admin actions

  void _showExtendSheet() {
    final daysCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        bool loading = false;
        return StatefulBuilder(
          builder: (ctx2, setSt) => Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx2).viewInsets.bottom + 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Extend Subscription',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DarkField(
                    controller: daysCtrl,
                    label: 'Days',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = int.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Enter a positive number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _DarkField(
                    controller: reasonCtrl,
                    label: 'Reason (optional)',
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryFg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: loading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSt(() => loading = true);
                              try {
                                await _dio.post(
                                  '/subscriptions/admin/tenants/${widget.tenantId}/extend',
                                  data: {
                                    'days': int.parse(daysCtrl.text.trim()),
                                    if (reasonCtrl.text.trim().isNotEmpty)
                                      'reason': reasonCtrl.text.trim(),
                                  },
                                );
                                if (ctx2.mounted) Navigator.of(ctx2).pop();
                                _showSnack('Subscription extended successfully',
                                    success: true);
                                _loadSubscription();
                              } on DioException catch (e) {
                                if (ctx2.mounted) Navigator.of(ctx2).pop();
                                _showSnack(AppException.fromDio(e).message);
                              } catch (e) {
                                if (ctx2.mounted) Navigator.of(ctx2).pop();
                                _showSnack(e.toString());
                              }
                            },
                      child: loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  color: AppColors.primaryFg, strokeWidth: 2),
                            )
                          : const Text('Extend',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showChangePlanSheet() {
    String? selectedPlanId;
    final reasonCtrl = TextEditingController();
    List<Map<String, dynamic>> plans = [];
    bool plansLoading = true;
    String? plansError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSt) {
            // Load plans on first build
            if (plansLoading && plans.isEmpty && plansError == null) {
              Future.microtask(() async {
                try {
                  final resp = await _dio.get(
                    '/subscriptions/plans',
                    queryParameters: {'page_size': 50},
                  );
                  final data = resp.data;
                  List<dynamic> items;
                  if (data is Map<String, dynamic>) {
                    items = data['items'] as List<dynamic>? ??
                        data['plans'] as List<dynamic>? ??
                        [];
                  } else if (data is List) {
                    items = data;
                  } else {
                    items = [];
                  }
                  setSt(() {
                    plans = items.cast<Map<String, dynamic>>();
                    plansLoading = false;
                  });
                } on DioException catch (e) {
                  setSt(() {
                    plansError = AppException.fromDio(e).message;
                    plansLoading = false;
                  });
                } catch (e) {
                  setSt(() {
                    plansError = e.toString();
                    plansLoading = false;
                  });
                }
              });
            }

            bool submitting = false;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(ctx2).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Change Plan',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (plansLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    )
                  else if (plansError != null)
                    Text(plansError!,
                        style: const TextStyle(color: AppColors.error))
                  else ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: plans.length,
                        itemBuilder: (_, i) {
                          final p = plans[i];
                          final pid = p['id']?.toString() ?? '';
                          final pname = p['name']?.toString() ?? pid;
                          final price =
                              (p['monthly_price'] as num?)?.toDouble() ?? 0.0;
                          final isSelected = selectedPlanId == pid;
                          return GestureDetector(
                            onTap: () => setSt(() => selectedPlanId = pid),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.divider,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pname,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.format(price),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle,
                                        color: AppColors.primary, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DarkField(
                      controller: reasonCtrl,
                      label: 'Reason (optional)',
                    ),
                    const SizedBox(height: 20),
                    StatefulBuilder(
                      builder: (ctx3, setBtn) => SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.primaryFg,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: (submitting || selectedPlanId == null)
                              ? null
                              : () async {
                                  setBtn(() => submitting = true);
                                  try {
                                    await _dio.post(
                                      '/subscriptions/admin/tenants/${widget.tenantId}/change-plan',
                                      data: {
                                        'plan_id': selectedPlanId!,
                                        if (reasonCtrl.text.trim().isNotEmpty)
                                          'reason': reasonCtrl.text.trim(),
                                      },
                                    );
                                    if (ctx2.mounted) Navigator.of(ctx2).pop();
                                    _showSnack('Plan changed successfully',
                                        success: true);
                                    _loadSubscription();
                                  } on DioException catch (e) {
                                    if (ctx2.mounted) Navigator.of(ctx2).pop();
                                    _showSnack(
                                        AppException.fromDio(e).message);
                                  } catch (e) {
                                    if (ctx2.mounted) Navigator.of(ctx2).pop();
                                    _showSnack(e.toString());
                                  }
                                },
                          child: submitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      color: AppColors.primaryFg,
                                      strokeWidth: 2),
                                )
                              : const Text('Change Plan',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmSuspendReactivate(bool isSuspended) async {
    final action = isSuspended ? 'Reactivate' : 'Suspend';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          '$action Business',
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          isSuspended
              ? 'Reactivate this business subscription?'
              : 'Suspend this business subscription? They will lose access.',
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isSuspended ? AppColors.success : AppColors.error,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final endpoint = isSuspended
          ? '/subscriptions/admin/tenants/${widget.tenantId}/reactivate'
          : '/subscriptions/admin/tenants/${widget.tenantId}/suspend';
      await _dio.post(endpoint);
      _showSnack('$action successful', success: true);
      _loadSubscription();
    } on DioException catch (e) {
      _showSnack(AppException.fromDio(e).message);
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  void _showProofActionSheet(
      Map<String, dynamic> proof, bool isApprove) {
    final notesCtrl = TextEditingController();
    final proofId = proof['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        bool loading = false;
        return StatefulBuilder(
          builder: (ctx2, setSt) => Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx2).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isApprove ? 'Approve Payment Proof' : 'Reject Payment Proof',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _DarkField(
                  controller: notesCtrl,
                  label: 'Review Notes (optional)',
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isApprove ? AppColors.success : AppColors.error,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: loading
                        ? null
                        : () async {
                            setSt(() => loading = true);
                            try {
                              final endpoint = isApprove
                                  ? '/subscriptions/payment-proofs/$proofId/approve'
                                  : '/subscriptions/payment-proofs/$proofId/reject';
                              await _dio.post(
                                endpoint,
                                data: {
                                  if (notesCtrl.text.trim().isNotEmpty)
                                    'review_notes': notesCtrl.text.trim(),
                                },
                              );
                              if (ctx2.mounted) Navigator.of(ctx2).pop();
                              _showSnack(
                                isApprove
                                    ? 'Proof approved'
                                    : 'Proof rejected',
                                success: isApprove,
                              );
                              _loadProofs(refresh: true);
                            } on DioException catch (e) {
                              if (ctx2.mounted) Navigator.of(ctx2).pop();
                              _showSnack(AppException.fromDio(e).message);
                            } catch (e) {
                              if (ctx2.mounted) Navigator.of(ctx2).pop();
                              _showSnack(e.toString());
                            }
                          },
                    child: loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            isApprove ? 'Approve' : 'Reject',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Build

  @override
  Widget build(BuildContext context) {
    final businessName =
        _overview?['business_name']?.toString() ?? 'Business Detail';
    final status = _overview?['status']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              businessName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (status.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: StatusBadge(status: status),
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: [
              Container(height: 1, color: AppColors.divider),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w400),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Users'),
                  Tab(text: 'Branches'),
                  Tab(text: 'Subscription'),
                  Tab(text: 'Billing'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildUsersTab(),
          _buildBranchesTab(),
          _buildSubscriptionTab(),
          _buildBillingTab(),
        ],
      ),
    );
  }

  // Tab 0: Overview

  Widget _buildOverviewTab() {
    if (_overviewLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_overviewError != null) {
      return ErrorView(message: _overviewError!, onRetry: _loadOverview);
    }
    if (_overview == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    final ov = _overview!;
    final name = ov['business_name']?.toString() ?? '—';
    final code = ov['business_code']?.toString();
    final email = ov['email']?.toString();
    final phone = ov['phone']?.toString();
    final address = ov['address']?.toString();
    final statusVal = ov['status']?.toString() ?? '—';
    final createdAt = _fmtDate(ov['created_at']?.toString());
    final userCount = ov['user_count']?.toString() ?? '0';
    final branchCount = ov['branch_count']?.toString() ?? '0';

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _loadOverview,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                StatusBadge(status: statusVal),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Info card
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _OvRow(
                    icon: Icons.business_outlined,
                    label: 'Business Name',
                    value: name),
                if (code != null && code.isNotEmpty) ...[
                  _Divider(),
                  _OvRow(
                      icon: Icons.tag_outlined,
                      label: 'Code',
                      value: code),
                ],
                if (email != null && email.isNotEmpty) ...[
                  _Divider(),
                  _OvRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: email),
                ],
                if (phone != null && phone.isNotEmpty) ...[
                  _Divider(),
                  _OvRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: phone),
                ],
                if (address != null && address.isNotEmpty) ...[
                  _Divider(),
                  _OvRow(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: address),
                ],
                _Divider(),
                _OvRow(
                    icon: Icons.circle_outlined,
                    label: 'Status',
                    value: statusVal),
                _Divider(),
                _OvRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Created',
                    value: createdAt),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Count chips
          Row(
            children: [
              Expanded(
                child: _CountCard(
                  icon: Icons.people_outline,
                  label: 'Users',
                  count: userCount,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CountCard(
                  icon: Icons.store_outlined,
                  label: 'Branches',
                  count: branchCount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tab 1: Users

  Widget _buildUsersTab() {
    if (_usersLoading && _users.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_usersError != null && _users.isEmpty) {
      return ErrorView(
          message: _usersError!, onRetry: () => _loadUsers(refresh: true));
    }
    if (_users.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => _loadUsers(refresh: true),
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyView(
              icon: Icons.people_outline,
              title: 'No users found',
              subtitle: 'This business has no users yet.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => _loadUsers(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _users.length + (_usersHasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _users.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _usersLoadingMore
                    ? const CircularProgressIndicator(
                        color: AppColors.primary)
                    : TextButton(
                        onPressed: _loadUsers,
                        child: const Text('Load More',
                            style: TextStyle(color: AppColors.primary)),
                      ),
              ),
            );
          }
          final u = _users[i];
          final fullName = u['full_name']?.toString() ??
              u['name']?.toString() ??
              '—';
          final email = u['email']?.toString() ?? '';
          final role = u['role']?.toString() ?? '';
          final uStatus = u['status']?.toString() ?? 'ACTIVE';

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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _initials(fullName),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (role.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          StatusBadge(status: role, label: role),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: uStatus),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Tab 2: Branches

  Widget _buildBranchesTab() {
    if (_branchesLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_branchesError != null) {
      return ErrorView(
          message: _branchesError!, onRetry: _loadBranches);
    }
    if (_branches.isEmpty) {
      return const EmptyView(
        icon: Icons.store_outlined,
        title: 'No branches',
        subtitle: 'This business has no branches yet.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async => _loadBranches(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _branches.length,
        itemBuilder: (_, i) {
          final b = _branches[i];
          final bName = b['name']?.toString() ?? '—';
          final isActive = b['is_active'] as bool? ?? true;
          final addr = b['address']?.toString();

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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.store_outlined,
                        size: 20, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (addr != null && addr.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 11,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  addr,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: isActive ? 'ACTIVE' : 'INACTIVE'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Tab 3: Subscription

  Widget _buildSubscriptionTab() {
    if (_subLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_subError != null) {
      return ErrorView(message: _subError!, onRetry: _loadSubscription);
    }
    if (_subscription == null) {
      return RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _loadSubscription,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyView(
              icon: Icons.card_membership_outlined,
              title: 'No subscription data',
              subtitle: 'Subscription info not available.',
            ),
          ],
        ),
      );
    }

    final sub = _subscription!;
    final subStatus = sub['status']?.toString() ?? '—';
    final planName = sub['plan_name']?.toString() ?? '—';
    final startedAt = _fmtDate(sub['started_at']?.toString());
    final expiresAt = _fmtDate(
        sub['expires_at']?.toString() ??
            sub['renewal_date']?.toString());
    final trialEndsAt = _fmtDate(sub['trial_ends_at']?.toString());
    final isSuspended = subStatus.toUpperCase() == 'SUSPENDED';

    Color headerColor;
    switch (subStatus.toUpperCase()) {
      case 'ACTIVE':
        headerColor = AppColors.successLight;
        break;
      case 'TRIAL':
        headerColor = AppColors.warningLight;
        break;
      case 'SUSPENDED':
      case 'EXPIRED':
        headerColor = AppColors.errorLight;
        break;
      default:
        headerColor = AppColors.surfaceVariant;
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _loadSubscription,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // Subscription info card
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colored header
                Container(
                  width: double.infinity,
                  color: headerColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.card_membership_outlined,
                          color: AppColors.textPrimary, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Subscription',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      StatusBadge(status: subStatus),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SubRow(label: 'Plan', value: planName),
                      const SizedBox(height: 10),
                      _SubRow(label: 'Started', value: startedAt),
                      const SizedBox(height: 10),
                      _SubRow(label: 'Expires', value: expiresAt),
                      if (trialEndsAt != '—') ...[
                        const SizedBox(height: 10),
                        _SubRow(label: 'Trial Ends', value: trialEndsAt),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Admin actions
          const Text(
            'Admin Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.access_time_outlined,
                  label: 'Extend',
                  color: AppColors.info,
                  onTap: _showExtendSheet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.swap_horiz_outlined,
                  label: 'Change Plan',
                  color: AppColors.primary,
                  onTap: _showChangePlanSheet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: isSuspended
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                  label: isSuspended ? 'Reactivate' : 'Suspend',
                  color: isSuspended ? AppColors.success : AppColors.error,
                  onTap: () => _confirmSuspendReactivate(isSuspended),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tab 4: Billing

  Widget _buildBillingTab() {
    return Column(
      children: [
        // Sub-tab chips
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _BillingChip(
                label: 'Payment Proofs',
                selected: _billingTab == 0,
                onTap: () => setState(() => _billingTab = 0),
              ),
              const SizedBox(width: 8),
              _BillingChip(
                label: 'History',
                selected: _billingTab == 1,
                onTap: () => setState(() => _billingTab = 1),
              ),
            ],
          ),
        ),
        Container(height: 1, color: AppColors.divider),
        Expanded(
          child: _billingTab == 0
              ? _buildProofsContent()
              : _buildHistoryContent(),
        ),
      ],
    );
  }

  Widget _buildProofsContent() {
    if (_proofsLoading && _proofs.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_proofsError != null && _proofs.isEmpty) {
      return ErrorView(
          message: _proofsError!,
          onRetry: () => _loadProofs(refresh: true));
    }
    if (_proofs.isEmpty) {
      return const EmptyView(
        icon: Icons.receipt_long_outlined,
        title: 'No payment proofs',
        subtitle: 'No payment proofs submitted yet.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => _loadProofs(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _proofs.length + (_proofsHasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _proofs.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _proofsLoadingMore
                    ? const CircularProgressIndicator(
                        color: AppColors.primary)
                    : TextButton(
                        onPressed: _loadProofs,
                        child: const Text('Load More',
                            style: TextStyle(color: AppColors.primary)),
                      ),
              ),
            );
          }

          final proof = _proofs[i];
          final pName = proof['plan_name']?.toString() ?? '—';
          final amount =
              (proof['amount'] as num?)?.toDouble() ?? 0.0;
          final pStatus = proof['status']?.toString() ?? '—';
          final createdAt = _fmtDate(proof['created_at']?.toString());
          final isPending = pStatus.toUpperCase() == 'PENDING';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusBadge(status: pStatus),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        CurrencyFormatter.format(amount),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        createdAt,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 10),
                    Container(height: 1, color: AppColors.divider),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.success,
                              side: const BorderSide(
                                  color: AppColors.success),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                            ),
                            onPressed: () =>
                                _showProofActionSheet(proof, true),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Approve',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side:
                                  const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                            ),
                            onPressed: () =>
                                _showProofActionSheet(proof, false),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Reject',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryContent() {
    if (_historyLoading && _history.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_historyError != null && _history.isEmpty) {
      return ErrorView(
          message: _historyError!,
          onRetry: () => _loadHistory(refresh: true));
    }
    if (_history.isEmpty) {
      return const EmptyView(
        icon: Icons.history_outlined,
        title: 'No history',
        subtitle: 'No subscription history found.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => _loadHistory(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _history.length + (_historyHasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _history.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _historyLoadingMore
                    ? const CircularProgressIndicator(
                        color: AppColors.primary)
                    : TextButton(
                        onPressed: _loadHistory,
                        child: const Text('Load More',
                            style: TextStyle(color: AppColors.primary)),
                      ),
              ),
            );
          }

          final h = _history[i];
          final hPlan = h['plan_name']?.toString() ?? '—';
          final action = h['action']?.toString() ?? '—';
          final createdAt = _fmtDate(h['created_at']?.toString());

          IconData actionIcon;
          Color actionColor;
          switch (action.toUpperCase()) {
            case 'ACTIVATED':
              actionIcon = Icons.play_circle_outline;
              actionColor = AppColors.success;
              break;
            case 'UPGRADED':
              actionIcon = Icons.arrow_upward;
              actionColor = AppColors.primary;
              break;
            case 'DOWNGRADED':
              actionIcon = Icons.arrow_downward;
              actionColor = AppColors.warning;
              break;
            case 'SUSPENDED':
              actionIcon = Icons.pause_circle_outline;
              actionColor = AppColors.error;
              break;
            case 'REACTIVATED':
              actionIcon = Icons.restart_alt;
              actionColor = AppColors.success;
              break;
            case 'EXTENDED':
              actionIcon = Icons.access_time_outlined;
              actionColor = AppColors.info;
              break;
            default:
              actionIcon = Icons.history_outlined;
              actionColor = AppColors.textSecondary;
          }

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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(actionIcon,
                        size: 18, color: actionColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: actionColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hPlan,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    createdAt,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small private widgets
// ---------------------------------------------------------------------------

class _OvRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _OvRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(color: AppColors.divider, height: 1);
}

class _SubRow extends StatelessWidget {
  final String label;
  final String value;
  const _SubRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;
  const _CountCard(
      {required this.icon, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            count,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BillingChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primaryFg : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;

  const _DarkField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
