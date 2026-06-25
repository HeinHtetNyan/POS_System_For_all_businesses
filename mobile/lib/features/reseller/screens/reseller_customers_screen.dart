import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/reseller_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_loader.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _CustomersState {
  final List<Map<String, dynamic>> businesses;
  final String? selectedBusinessId;
  final List<Map<String, dynamic>> customers;
  final bool isLoadingBusinesses;
  final bool isLoadingCustomers;
  final String? error;
  final String searchQuery;

  const _CustomersState({
    this.businesses = const [],
    this.selectedBusinessId,
    this.customers = const [],
    this.isLoadingBusinesses = false,
    this.isLoadingCustomers = false,
    this.error,
    this.searchQuery = '',
  });

  _CustomersState copyWith({
    List<Map<String, dynamic>>? businesses,
    String? selectedBusinessId,
    List<Map<String, dynamic>>? customers,
    bool? isLoadingBusinesses,
    bool? isLoadingCustomers,
    String? error,
    String? searchQuery,
    bool clearError = false,
    bool clearSelectedBusiness = false,
  }) =>
      _CustomersState(
        businesses: businesses ?? this.businesses,
        selectedBusinessId: clearSelectedBusiness
            ? null
            : (selectedBusinessId ?? this.selectedBusinessId),
        customers: customers ?? this.customers,
        isLoadingBusinesses: isLoadingBusinesses ?? this.isLoadingBusinesses,
        isLoadingCustomers: isLoadingCustomers ?? this.isLoadingCustomers,
        error: clearError ? null : (error ?? this.error),
        searchQuery: searchQuery ?? this.searchQuery,
      );

  String? get displayBusinessName {
    if (selectedBusinessId == null && businesses.isNotEmpty) {
      return businesses.first['name'] as String? ?? 'Unknown';
    }
    if (selectedBusinessId == null) return null;
    final match = businesses.where((b) => b['id']?.toString() == selectedBusinessId).toList();
    if (match.isEmpty) return null;
    return match.first['name'] as String?;
  }

  List<Map<String, dynamic>> get filteredCustomers {
    if (searchQuery.isEmpty) return customers;
    final q = searchQuery.toLowerCase();
    return customers.where((c) {
      final name = (c['name'] as String? ?? '').toLowerCase();
      return name.contains(q);
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class _CustomersNotifier extends StateNotifier<_CustomersState> {
  final ResellerRepository _repo;

  _CustomersNotifier(this._repo) : super(const _CustomersState());

  Future<void> init() async {
    state = state.copyWith(isLoadingBusinesses: true, clearError: true);
    try {
      final businesses = await _repo.getManagedBusinesses();
      state = state.copyWith(
        businesses: businesses,
        isLoadingBusinesses: false,
      );
      await _loadCustomers();
    } catch (e) {
      state = state.copyWith(
        isLoadingBusinesses: false,
        error: e.toString(),
      );
    }
  }

  Future<void> selectBusiness(String? businessId) async {
    state = state.copyWith(
      selectedBusinessId: businessId,
      clearSelectedBusiness: businessId == null,
    );
    await _loadCustomers();
  }

  Future<void> refresh() async {
    state = state.copyWith(clearError: true);
    await _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    if (state.businesses.isEmpty) return;
    final tenantId = state.selectedBusinessId ?? state.businesses.first['id']?.toString();
    if (tenantId == null) return;

    state = state.copyWith(isLoadingCustomers: true, clearError: true);
    try {
      final r = await apiClient.dio.get(
        '/customers',
        queryParameters: {'tenant_id': tenantId, 'page_size': 50},
      );
      final data = r.data as Map<String, dynamic>;
      final raw = (data['items'] as List<dynamic>?) ??
          (r.data is List ? r.data as List<dynamic> : []);
      state = state.copyWith(
        customers: raw.cast<Map<String, dynamic>>(),
        isLoadingCustomers: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingCustomers: false, error: e.toString());
    }
  }

  void setSearch(String q) {
    state = state.copyWith(searchQuery: q);
  }
}

final _customersProvider =
    StateNotifierProvider.autoDispose<_CustomersNotifier, _CustomersState>(
  (ref) => _CustomersNotifier(ref.watch(resellerRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ResellerCustomersScreen extends ConsumerStatefulWidget {
  const ResellerCustomersScreen({super.key});

  @override
  ConsumerState<ResellerCustomersScreen> createState() =>
      _ResellerCustomersScreenState();
}

class _ResellerCustomersScreenState
    extends ConsumerState<ResellerCustomersScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(_customersProvider.notifier).init());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_customersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Customers',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: state.isLoadingBusinesses
          ? const ShimmerList(itemCount: 8, itemHeight: 76)
          : state.error != null && state.customers.isEmpty
              ? ErrorView(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(_customersProvider.notifier).init(),
                )
              : Column(
                  children: [
                    _BusinessDropdown(state: state),
                    _SearchBar(controller: _searchController, state: state),
                    if (state.selectedBusinessId == null &&
                        state.displayBusinessName != null)
                      _AllBusinessesNote(
                          businessName: state.displayBusinessName!),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        onRefresh: () =>
                            ref.read(_customersProvider.notifier).refresh(),
                        child: state.isLoadingCustomers
                            ? const ShimmerList(itemCount: 8, itemHeight: 76)
                            : state.filteredCustomers.isEmpty
                                ? const EmptyView(
                                    icon: Icons.people_outline,
                                    title: 'No Customers Found',
                                    subtitle:
                                        'No customers match your search or this business has none.',
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 16),
                                    itemCount: state.filteredCustomers.length,
                                    itemBuilder: (context, index) =>
                                        _CustomerCard(
                                            data: state
                                                .filteredCustomers[index]),
                                  ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Business dropdown
// ---------------------------------------------------------------------------

class _BusinessDropdown extends ConsumerWidget {
  final _CustomersState state;

  const _BusinessDropdown({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(
        value: null,
        child: Text(
          'All Businesses',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      ...state.businesses.map((b) {
        final id = b['id']?.toString() ?? '';
        final name = b['name'] as String? ?? 'Unknown';
        return DropdownMenuItem(
          value: id,
          child: Text(
            name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: state.selectedBusinessId,
          isExpanded: true,
          dropdownColor: AppColors.surfaceVariant,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textSecondary, size: 20),
          items: items,
          onChanged: (id) =>
              ref.read(_customersProvider.notifier).selectBusiness(id),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search bar
// ---------------------------------------------------------------------------

class _SearchBar extends ConsumerWidget {
  final TextEditingController controller;
  final _CustomersState state;

  const _SearchBar({required this.controller, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by name...',
          hintStyle:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon:
              const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
          suffixIcon: state.searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    controller.clear();
                    ref.read(_customersProvider.notifier).setSearch('');
                  },
                  child: const Icon(Icons.close,
                      color: AppColors.textSecondary, size: 18),
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
        onChanged: (q) =>
            ref.read(_customersProvider.notifier).setSearch(q),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// All businesses note banner
// ---------------------------------------------------------------------------

class _AllBusinessesNote extends StatelessWidget {
  final String businessName;

  const _AllBusinessesNote({required this.businessName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 14, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing from $businessName',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Customer card
// ---------------------------------------------------------------------------

class _CustomerCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CustomerCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Unknown';
    final email = data['email'] as String?;
    final phone = data['phone'] as String?;
    final creditBalance =
        (data['credit_balance'] as num?)?.toDouble() ?? 0.0;
    final hasCredit = creditBalance != 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
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
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (email != null && email.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined,
                            size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            email,
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
                  if (phone != null && phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined,
                            size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (hasCredit) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Credit',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.formatCompact(creditBalance),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: creditBalance > 0
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
