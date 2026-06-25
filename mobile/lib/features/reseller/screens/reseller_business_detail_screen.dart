import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/reseller_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/shimmer_loader.dart';

// ---------------------------------------------------------------------------
// Permission labels
// ---------------------------------------------------------------------------

const _permLabels = <String, String>{
  'view_revenue': 'View Revenue',
  'view_profit': 'View Profit',
  'view_analytics': 'View Analytics',
  'view_inventory': 'View Inventory',
  'adjust_inventory': 'Adjust Inventory',
  'transfer_inventory': 'Transfer Inventory',
  'view_customers': 'View Customers',
  'view_customer_debt': 'View Customer Debt',
  'record_customer_payment': 'Record Customer Payment',
  'view_procurement': 'View Procurement',
  'create_purchase_order': 'Create Purchase Order',
  'approve_purchase_order': 'Approve Purchase Order',
  'view_subscription_status': 'View Subscription',
  'view_staff': 'View Staff',
  'manage_staff': 'Manage Staff',
  'export_data': 'Export Data',
  'view_branch_reports': 'View Branch Reports',
};

// ---------------------------------------------------------------------------
// Data holder
// ---------------------------------------------------------------------------

class _DetailData {
  final Map<String, dynamic> business;
  final List<Map<String, dynamic>> branches;
  final List<String> grantedPermissions;

  const _DetailData({
    required this.business,
    required this.branches,
    required this.grantedPermissions,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _detailProvider = FutureProvider.autoDispose
    .family<_DetailData, String>((ref, tenantId) async {
  final repo = ref.watch(resellerRepositoryProvider);
  final dio = apiClient.dio;

  // 1. Get all managed businesses and find the matching one
  final businesses = await repo.getManagedBusinesses();
  final business = businesses.firstWhere(
    (b) => b['tenant_id']?.toString() == tenantId || b['id']?.toString() == tenantId,
    orElse: () => <String, dynamic>{'name': 'Unknown Business', 'id': tenantId},
  );

  // 2. Get branches
  final branchesResp = await dio.get(
    '/resellers/me/branches',
    queryParameters: {'tenant_id': tenantId},
  );
  final branchesData = branchesResp.data;
  final List<Map<String, dynamic>> branches;
  if (branchesData is Map<String, dynamic>) {
    final raw = branchesData['branches'] as List<dynamic>? ?? [];
    branches = raw.cast<Map<String, dynamic>>();
  } else if (branchesData is List) {
    branches = branchesData.cast<Map<String, dynamic>>();
  } else {
    branches = [];
  }

  // 3. Get permissions
  final permResp = await dio.get(
    '/resellers/me/permissions',
    queryParameters: {'tenant_id': tenantId},
  );
  final permData = permResp.data;
  final List<String> granted;
  if (permData is Map<String, dynamic>) {
    final rawPerms = permData['permissions'];
    if (rawPerms is List) {
      granted = rawPerms.cast<String>();
    } else if (rawPerms is Map<String, dynamic>) {
      granted = rawPerms.entries
          .where((e) => e.value == true)
          .map((e) => e.key)
          .toList();
    } else {
      // top-level map of String -> bool
      granted = permData.entries
          .where((e) => e.value == true)
          .map((e) => e.key)
          .toList();
    }
  } else {
    granted = [];
  }

  return _DetailData(
    business: business,
    branches: branches,
    grantedPermissions: granted,
  );
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ResellerBusinessDetailScreen extends ConsumerStatefulWidget {
  final String tenantId;
  const ResellerBusinessDetailScreen({super.key, required this.tenantId});

  @override
  ConsumerState<ResellerBusinessDetailScreen> createState() =>
      _ResellerBusinessDetailScreenState();
}

class _ResellerBusinessDetailScreenState
    extends ConsumerState<ResellerBusinessDetailScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(_detailProvider(widget.tenantId));

    return asyncData.when(
      loading: () => _LoadingScaffold(tenantId: widget.tenantId),
      error: (err, _) => _ErrorScaffold(
        tenantId: widget.tenantId,
        error: err.toString(),
        onRetry: () => ref.invalidate(_detailProvider(widget.tenantId)),
      ),
      data: (data) => _DetailScaffold(
        tenantId: widget.tenantId,
        data: data,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading scaffold
// ---------------------------------------------------------------------------

class _LoadingScaffold extends StatelessWidget {
  final String tenantId;
  const _LoadingScaffold({required this.tenantId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, 'Loading...', tenantId),
      body: const ShimmerList(itemCount: 6, itemHeight: 80),
    );
  }
}

// ---------------------------------------------------------------------------
// Error scaffold
// ---------------------------------------------------------------------------

class _ErrorScaffold extends StatelessWidget {
  final String tenantId;
  final String error;
  final VoidCallback onRetry;
  const _ErrorScaffold({
    required this.tenantId,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, 'Business Detail', tenantId),
      body: ErrorView(message: error, onRetry: onRetry),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail scaffold
// ---------------------------------------------------------------------------

class _DetailScaffold extends StatelessWidget {
  final String tenantId;
  final _DetailData data;
  const _DetailScaffold({required this.tenantId, required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data.business['name'] as String? ?? 'Unknown Business';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, name, tenantId),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _BusinessInfoCard(business: data.business),
          const SizedBox(height: 20),
          _BranchesSection(branches: data.branches),
          const SizedBox(height: 20),
          _PermissionsSection(grantedPermissions: data.grantedPermissions),
          const SizedBox(height: 20),
          _QuickActionsRow(tenantId: tenantId),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared AppBar builder
// ---------------------------------------------------------------------------

AppBar _buildAppBar(BuildContext context, String title, String tenantId) {
  return AppBar(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    title: Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    actions: [
      IconButton(
        icon: const Icon(Icons.card_membership_outlined,
            color: AppColors.primary, size: 22),
        tooltip: 'View Subscription',
        onPressed: () {
          context.push('/reseller/businesses/$tenantId/subscription');
        },
      ),
      const SizedBox(width: 4),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: AppColors.divider),
    ),
  );
}

// ---------------------------------------------------------------------------
// Business info card
// ---------------------------------------------------------------------------

class _BusinessInfoCard extends StatelessWidget {
  final Map<String, dynamic> business;
  const _BusinessInfoCard({required this.business});

  @override
  Widget build(BuildContext context) {
    final name = business['name'] as String? ?? 'Unknown Business';
    final status = business['status'] as String? ?? 'unknown';
    final plan = business['plan_name'] as String?;
    final createdAt = business['created_at'] as String?;
    final joinedDate = _formatDate(createdAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.business_outlined,
                    size: 26, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StatusBadge(status: status),
                  ],
                ),
              ),
            ],
          ),
          if (plan != null && plan.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.card_membership_outlined,
              label: 'Plan',
              value: plan,
            ),
          ],
          if (joinedDate != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Joined',
              value: joinedDate,
            ),
          ],
        ],
      ),
    );
  }

  String? _formatDate(String? raw) {
    if (raw == null) return null;
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return null;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Branches section
// ---------------------------------------------------------------------------

class _BranchesSection extends StatelessWidget {
  final List<Map<String, dynamic>> branches;
  const _BranchesSection({required this.branches});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: Icons.store_outlined,
          title: 'Branches',
          count: branches.length,
        ),
        const SizedBox(height: 10),
        if (branches.isEmpty)
          const EmptyView(
            icon: Icons.store_outlined,
            title: 'No Branches',
            subtitle: 'No branches found',
          )
        else
          ...branches.map((b) => _BranchCard(branch: b)),
      ],
    );
  }
}

class _BranchCard extends StatelessWidget {
  final Map<String, dynamic> branch;
  const _BranchCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    final name = branch['name'] as String? ?? 'Unknown Branch';
    final address = branch['address'] as String?;
    final isActive = branch['is_active'] as bool? ?? true;
    final status = isActive ? 'active' : 'inactive';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store_outlined,
                size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (address != null && address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 11, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
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
          StatusBadge(status: status),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Permissions section
// ---------------------------------------------------------------------------

class _PermissionsSection extends StatelessWidget {
  final List<String> grantedPermissions;
  const _PermissionsSection({required this.grantedPermissions});

  @override
  Widget build(BuildContext context) {
    final grantedSet = grantedPermissions.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: Icons.security_outlined,
          title: 'Your Permissions',
          count: grantedPermissions.length,
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _permLabels.entries.map((entry) {
              final isGranted = grantedSet.contains(entry.key);
              return _PermissionChip(
                label: entry.value,
                isGranted: isGranted,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PermissionChip extends StatelessWidget {
  final String label;
  final bool isGranted;
  const _PermissionChip({required this.label, required this.isGranted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isGranted
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGranted
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.divider,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGranted ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: 12,
            color: isGranted ? AppColors.success : AppColors.textDisabled,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isGranted ? FontWeight.w600 : FontWeight.w400,
              color: isGranted ? AppColors.success : AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions row
// ---------------------------------------------------------------------------

class _QuickActionsRow extends StatelessWidget {
  final String tenantId;
  const _QuickActionsRow({required this.tenantId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: Icons.flash_on_outlined,
          title: 'Quick Actions',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.people_outline,
                label: 'Customers',
                color: AppColors.info,
                onTap: () => context.push(
                  '/reseller/customers',
                  extra: {'tenantId': tenantId},
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.inventory_2_outlined,
                label: 'Inventory',
                color: AppColors.warning,
                onTap: () => context.push(
                  '/reseller/inventory',
                  extra: {'tenantId': tenantId},
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.shopping_cart_outlined,
                label: 'Procurement',
                color: AppColors.success,
                onTap: () => context.push(
                  '/reseller/procurement',
                  extra: {'tenantId': tenantId},
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section title
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final int? count;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
