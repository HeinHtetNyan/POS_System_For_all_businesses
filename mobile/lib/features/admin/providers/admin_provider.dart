import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_repository.dart';
import '../../../models/tenant_model.dart';
import '../../../models/user_model.dart';
import '../../../models/device_model.dart';
import '../../../models/audit_log_model.dart';
import '../../../models/subscription_model.dart';

// Tenants
class TenantsState {
  final List<TenantModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int page;
  final String search;
  final String? statusFilter;

  const TenantsState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.page = 1,
    this.search = '',
    this.statusFilter,
  });

  TenantsState copyWith({
    List<TenantModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    int? page,
    String? search,
    Object? statusFilter = _sentinel,
    bool clearError = false,
  }) =>
      TenantsState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        search: search ?? this.search,
        statusFilter: statusFilter == _sentinel ? this.statusFilter : statusFilter as String?,
      );
}

const _sentinel = Object();

class TenantsNotifier extends StateNotifier<TenantsState> {
  final AdminRepository _repo;
  TenantsNotifier(this._repo) : super(const TenantsState());

  Future<void> load({bool refresh = false}) async {
    if (refresh || state.items.isEmpty) {
      state = TenantsState(isLoading: true, search: state.search, statusFilter: state.statusFilter);
    }
    try {
      final result = await _repo.listTenants(
        page: 1,
        search: state.search.isEmpty ? null : state.search,
        status: state.statusFilter,
      );
      state = state.copyWith(
        items: result.items, isLoading: false,
        hasMore: result.items.length >= 20, page: 1, clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.listTenants(
        page: state.page + 1,
        search: state.search.isEmpty ? null : state.search,
        status: state.statusFilter,
      );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false, hasMore: result.items.length >= 20,
        page: state.page + 1,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setSearch(String q) {
    state = state.copyWith(search: q);
    load(refresh: true);
  }

  void setStatusFilter(String? s) {
    state = TenantsState(statusFilter: s, search: state.search, isLoading: true);
    load();
  }
}

// Admin Users
class AdminUsersState {
  final List<UserModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int page;
  final String search;
  final String? roleFilter;

  const AdminUsersState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.page = 1,
    this.search = '',
    this.roleFilter,
  });

  AdminUsersState copyWith({
    List<UserModel>? items, bool? isLoading, bool? isLoadingMore,
    String? error, bool? hasMore, int? page,
    String? search, Object? roleFilter = _sentinel, bool clearError = false,
  }) => AdminUsersState(
    items: items ?? this.items, isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: clearError ? null : (error ?? this.error),
    hasMore: hasMore ?? this.hasMore, page: page ?? this.page,
    search: search ?? this.search,
    roleFilter: roleFilter == _sentinel ? this.roleFilter : roleFilter as String?,
  );
}

class AdminUsersNotifier extends StateNotifier<AdminUsersState> {
  final AdminRepository _repo;
  AdminUsersNotifier(this._repo) : super(const AdminUsersState());

  Future<void> load({bool refresh = false}) async {
    if (refresh || state.items.isEmpty) {
      state = AdminUsersState(isLoading: true, search: state.search, roleFilter: state.roleFilter);
    }
    try {
      final result = await _repo.listAllUsers(
        page: 1,
        search: state.search.isEmpty ? null : state.search,
        role: state.roleFilter,
      );
      state = state.copyWith(
        items: result.items, isLoading: false,
        hasMore: result.items.length >= 20, page: 1, clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.listAllUsers(
        page: state.page + 1,
        search: state.search.isEmpty ? null : state.search,
        role: state.roleFilter,
      );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false, hasMore: result.items.length >= 20,
        page: state.page + 1,
      );
    } catch (_) { state = state.copyWith(isLoadingMore: false); }
  }

  void setSearch(String q) {
    state = state.copyWith(search: q);
    load(refresh: true);
  }

  void setRoleFilter(String? role) {
    state = AdminUsersState(roleFilter: role, search: state.search, isLoading: true);
    load();
  }
}

// Resellers
class AdminResellersState {
  final List<ResellerModel> items;
  final bool isLoading;
  final String? error;

  const AdminResellersState({this.items = const [], this.isLoading = false, this.error});

  AdminResellersState copyWith({List<ResellerModel>? items, bool? isLoading, String? error, bool clearError = false}) =>
      AdminResellersState(
        items: items ?? this.items, isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class AdminResellersNotifier extends StateNotifier<AdminResellersState> {
  final AdminRepository _repo;
  AdminResellersNotifier(this._repo) : super(const AdminResellersState());

  Future<void> load({bool refresh = false}) async {
    if (refresh || state.items.isEmpty) state = const AdminResellersState(isLoading: true);
    try {
      final result = await _repo.listResellers();
      state = state.copyWith(items: result.items, isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// Plans
class PlansState {
  final List<SubscriptionPlanModel> items;
  final bool isLoading;
  final String? error;

  const PlansState({this.items = const [], this.isLoading = false, this.error});

  PlansState copyWith({List<SubscriptionPlanModel>? items, bool? isLoading, String? error, bool clearError = false}) =>
      PlansState(
        items: items ?? this.items, isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class PlansNotifier extends StateNotifier<PlansState> {
  final AdminRepository _repo;
  PlansNotifier(this._repo) : super(const PlansState());

  Future<void> load({bool refresh = false}) async {
    if (refresh || state.items.isEmpty) state = const PlansState(isLoading: true);
    try {
      final items = await _repo.listPlans();
      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// Devices
class DevicesState {
  final List<DeviceModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int page;

  const DevicesState({
    this.items = const [], this.isLoading = false, this.isLoadingMore = false,
    this.error, this.hasMore = true, this.page = 1,
  });

  DevicesState copyWith({
    List<DeviceModel>? items, bool? isLoading, bool? isLoadingMore,
    String? error, bool? hasMore, int? page, bool clearError = false,
  }) => DevicesState(
    items: items ?? this.items, isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: clearError ? null : (error ?? this.error),
    hasMore: hasMore ?? this.hasMore, page: page ?? this.page,
  );
}

class DevicesNotifier extends StateNotifier<DevicesState> {
  final AdminRepository _repo;
  DevicesNotifier(this._repo) : super(const DevicesState());

  Future<void> load({bool refresh = false}) async {
    if (refresh || state.items.isEmpty) state = const DevicesState(isLoading: true);
    try {
      final result = await _repo.listDevices(page: 1);
      state = state.copyWith(
        items: result.items, isLoading: false,
        hasMore: result.items.length >= 20, page: 1, clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.listDevices(page: state.page + 1);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false, hasMore: result.items.length >= 20,
        page: state.page + 1,
      );
    } catch (_) { state = state.copyWith(isLoadingMore: false); }
  }

  Future<void> approveDevice(String deviceId) async {
    await _repo.approveDevice(deviceId);
    final updated = state.items.map((d) {
      if (d.id == deviceId) return d.copyWith(status: 'ACTIVE');
      return d;
    }).toList();
    state = state.copyWith(items: updated);
  }

  Future<void> revokeDevice(String deviceId) async {
    await _repo.revokeDevice(deviceId);
    final updated = state.items.map((d) {
      if (d.id == deviceId) return d.copyWith(status: 'REVOKED');
      return d;
    }).toList();
    state = state.copyWith(items: updated);
  }
}

// Audit Logs
class AuditLogsState {
  final List<AuditLogModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int page;
  final String? entityTypeFilter;
  final String? actionFilter;
  final String? startDate;
  final String? endDate;

  const AuditLogsState({
    this.items = const [], this.isLoading = false, this.isLoadingMore = false,
    this.error, this.hasMore = true, this.page = 1,
    this.entityTypeFilter, this.actionFilter,
    this.startDate, this.endDate,
  });

  AuditLogsState copyWith({
    List<AuditLogModel>? items, bool? isLoading, bool? isLoadingMore,
    String? error, bool? hasMore, int? page, bool clearError = false,
    Object? entityTypeFilter = _sentinel, Object? actionFilter = _sentinel,
    Object? startDate = _sentinel, Object? endDate = _sentinel,
  }) => AuditLogsState(
    items: items ?? this.items, isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: clearError ? null : (error ?? this.error),
    hasMore: hasMore ?? this.hasMore, page: page ?? this.page,
    entityTypeFilter: entityTypeFilter == _sentinel ? this.entityTypeFilter : entityTypeFilter as String?,
    actionFilter: actionFilter == _sentinel ? this.actionFilter : actionFilter as String?,
    startDate: startDate == _sentinel ? this.startDate : startDate as String?,
    endDate: endDate == _sentinel ? this.endDate : endDate as String?,
  );
}

class AuditLogsNotifier extends StateNotifier<AuditLogsState> {
  final AdminRepository _repo;
  AuditLogsNotifier(this._repo) : super(const AuditLogsState());

  Future<void> load({bool refresh = false}) async {
    if (refresh || state.items.isEmpty) {
      state = AuditLogsState(
        isLoading: true,
        entityTypeFilter: state.entityTypeFilter,
        actionFilter: state.actionFilter,
        startDate: state.startDate,
        endDate: state.endDate,
      );
    }
    try {
      final result = await _repo.listAuditLogs(
        page: 1,
        entityType: state.entityTypeFilter,
        action: state.actionFilter,
        startDate: state.startDate,
        endDate: state.endDate,
      );
      state = state.copyWith(
        items: result.items, isLoading: false,
        hasMore: result.items.length >= 30, page: 1, clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.listAuditLogs(
        page: state.page + 1,
        entityType: state.entityTypeFilter,
        action: state.actionFilter,
        startDate: state.startDate,
        endDate: state.endDate,
      );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false, hasMore: result.items.length >= 30,
        page: state.page + 1,
      );
    } catch (_) { state = state.copyWith(isLoadingMore: false); }
  }

  void setEntityType(String? et) {
    state = AuditLogsState(
      entityTypeFilter: et, actionFilter: state.actionFilter,
      startDate: state.startDate, endDate: state.endDate, isLoading: true,
    );
    load();
  }

  void setAction(String? a) {
    state = AuditLogsState(
      actionFilter: a, entityTypeFilter: state.entityTypeFilter,
      startDate: state.startDate, endDate: state.endDate, isLoading: true,
    );
    load();
  }

  void setDateRange(String? startDate, String? endDate) {
    state = AuditLogsState(
      entityTypeFilter: state.entityTypeFilter, actionFilter: state.actionFilter,
      startDate: startDate, endDate: endDate, isLoading: true,
    );
    load();
  }
}

// Subscriptions
class AdminSubscriptionsState {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int page;
  final String? statusFilter;

  const AdminSubscriptionsState({
    this.items = const [], this.isLoading = false, this.isLoadingMore = false,
    this.error, this.hasMore = true, this.page = 1, this.statusFilter,
  });

  AdminSubscriptionsState copyWith({
    List<Map<String, dynamic>>? items, bool? isLoading, bool? isLoadingMore,
    String? error, bool? hasMore, int? page,
    Object? statusFilter = _sentinel, bool clearError = false,
  }) => AdminSubscriptionsState(
    items: items ?? this.items, isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: clearError ? null : (error ?? this.error),
    hasMore: hasMore ?? this.hasMore, page: page ?? this.page,
    statusFilter: statusFilter == _sentinel ? this.statusFilter : statusFilter as String?,
  );
}

class AdminSubscriptionsNotifier extends StateNotifier<AdminSubscriptionsState> {
  final AdminRepository _repo;
  AdminSubscriptionsNotifier(this._repo) : super(const AdminSubscriptionsState());

  Future<void> load({bool refresh = false}) async {
    if (refresh || state.items.isEmpty) {
      state = AdminSubscriptionsState(isLoading: true, statusFilter: state.statusFilter);
    }
    try {
      final result = await _repo.listSubscriptions(
        page: 1, status: state.statusFilter,
      );
      state = state.copyWith(
        items: result.items, isLoading: false,
        hasMore: result.items.length >= 20, page: 1, clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.listSubscriptions(
        page: state.page + 1, status: state.statusFilter,
      );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false, hasMore: result.items.length >= 20,
        page: state.page + 1,
      );
    } catch (_) { state = state.copyWith(isLoadingMore: false); }
  }

  void setStatusFilter(String? s) {
    state = AdminSubscriptionsState(statusFilter: s, isLoading: true);
    load();
  }
}

// Providers
final tenantsProvider =
    StateNotifierProvider<TenantsNotifier, TenantsState>((ref) =>
        TenantsNotifier(ref.watch(adminRepositoryProvider)));

final adminUsersProvider =
    StateNotifierProvider<AdminUsersNotifier, AdminUsersState>((ref) =>
        AdminUsersNotifier(ref.watch(adminRepositoryProvider)));

final adminResellersProvider =
    StateNotifierProvider<AdminResellersNotifier, AdminResellersState>(
        (ref) => AdminResellersNotifier(ref.watch(adminRepositoryProvider)));

final plansProvider =
    StateNotifierProvider<PlansNotifier, PlansState>((ref) =>
        PlansNotifier(ref.watch(adminRepositoryProvider)));

final devicesProvider =
    StateNotifierProvider<DevicesNotifier, DevicesState>((ref) =>
        DevicesNotifier(ref.watch(adminRepositoryProvider)));

final auditLogsProvider =
    StateNotifierProvider<AuditLogsNotifier, AuditLogsState>((ref) =>
        AuditLogsNotifier(ref.watch(adminRepositoryProvider)));

final adminSubscriptionsProvider =
    StateNotifierProvider<AdminSubscriptionsNotifier, AdminSubscriptionsState>(
        (ref) => AdminSubscriptionsNotifier(ref.watch(adminRepositoryProvider)));
