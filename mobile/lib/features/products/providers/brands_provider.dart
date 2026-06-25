import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../data/brands_repository.dart';

class BrandsState {
  final bool isLoading;
  final String? error;
  final List<BrandModel> items;

  const BrandsState({
    this.isLoading = false,
    this.error,
    this.items = const [],
  });

  BrandsState copyWith({
    bool? isLoading,
    String? error,
    List<BrandModel>? items,
    bool clearError = false,
  }) {
    return BrandsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      items: items ?? this.items,
    );
  }
}

class BrandsNotifier extends Notifier<BrandsState> {
  @override
  BrandsState build() => const BrandsState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await ref.read(brandsRepositoryProvider).getBrands();
      state = state.copyWith(isLoading: false, items: data);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void addItem(BrandModel brand) {
    state = state.copyWith(items: [brand, ...state.items]);
  }

  void updateItem(BrandModel updated) {
    state = state.copyWith(
      items:
          state.items.map((b) => b.id == updated.id ? updated : b).toList(),
    );
  }

  void removeItem(String id) {
    state = state.copyWith(
      items: state.items.where((b) => b.id != id).toList(),
    );
  }
}

final brandsProvider =
    NotifierProvider<BrandsNotifier, BrandsState>(BrandsNotifier.new);
