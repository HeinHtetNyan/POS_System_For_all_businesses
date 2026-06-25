import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customers_repository.dart';
import '../../../models/customer_model.dart';

class CustomersState {
  final List<CustomerModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int page;
  final String? searchQuery;
  // null = All, true = Active, false = Inactive
  final bool? activeFilter;

  const CustomersState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.page = 1,
    this.searchQuery,
    this.activeFilter,
  });

  CustomersState copyWith({
    List<CustomerModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    int? page,
    String? searchQuery,
    bool clearError = false,
    Object? activeFilter = _sentinel,
  }) {
    return CustomersState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter:
          activeFilter == _sentinel ? this.activeFilter : activeFilter as bool?,
    );
  }
}

const _sentinel = Object();

class CustomersNotifier extends StateNotifier<CustomersState> {
  final CustomersRepository _repo;
  CustomersNotifier(this._repo) : super(const CustomersState());

  Future<void> load({
    bool refresh = false,
    String? search,
    Object? activeFilter = _sentinel,
  }) async {
    final newActive =
        activeFilter == _sentinel ? state.activeFilter : activeFilter as bool?;
    if (refresh || search != state.searchQuery || newActive != state.activeFilter) {
      state = CustomersState(
        isLoading: true,
        searchQuery: search ?? state.searchQuery,
        activeFilter: newActive,
      );
    } else if (state.items.isEmpty) {
      state = state.copyWith(isLoading: true);
    }

    try {
      final result = await _repo.listCustomers(
        search: state.searchQuery,
        isActive: state.activeFilter,
        page: 1,
      );
      state = state.copyWith(
        items: result.items,
        isLoading: false,
        hasMore: result.items.length >= 20,
        page: 1,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.listCustomers(
        search: state.searchQuery,
        isActive: state.activeFilter,
        page: state.page + 1,
      );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false,
        hasMore: result.items.length >= 20,
        page: state.page + 1,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void search(String query) {
    load(refresh: true, search: query.isEmpty ? null : query);
  }

  void filterActive(bool? active) {
    // Pass active directly — null means "All", which load() treats as clearing the filter.
    load(refresh: true, search: state.searchQuery, activeFilter: active);
  }

  void addItem(CustomerModel customer) {
    state = state.copyWith(items: [customer, ...state.items]);
  }

  void updateItem(CustomerModel updated) {
    state = state.copyWith(
      items: state.items.map((c) => c.id == updated.id ? updated : c).toList(),
    );
  }
}

final customersProvider =
    StateNotifierProvider<CustomersNotifier, CustomersState>((ref) {
  return CustomersNotifier(ref.watch(customersRepositoryProvider));
});
