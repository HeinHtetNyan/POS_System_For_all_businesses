import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../models/category_model.dart';
import '../data/categories_repository.dart';

class CategoriesState {
  final bool isLoading;
  final String? error;
  final List<CategoryModel> items;

  const CategoriesState({
    this.isLoading = false,
    this.error,
    this.items = const [],
  });

  CategoriesState copyWith({
    bool? isLoading,
    String? error,
    List<CategoryModel>? items,
    bool clearError = false,
  }) {
    return CategoriesState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      items: items ?? this.items,
    );
  }
}

class CategoriesNotifier extends Notifier<CategoriesState> {
  @override
  CategoriesState build() => const CategoriesState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data =
          await ref.read(categoriesRepositoryProvider).getCategories();
      state = state.copyWith(isLoading: false, items: data);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void addItem(CategoryModel category) {
    state = state.copyWith(items: [category, ...state.items]);
  }

  void updateItem(CategoryModel updated) {
    state = state.copyWith(
      items: state.items
          .map((c) => c.id == updated.id ? updated : c)
          .toList(),
    );
  }

  void removeItem(String id) {
    state = state.copyWith(
      items: state.items.where((c) => c.id != id).toList(),
    );
  }
}

final categoriesProvider =
    NotifierProvider<CategoriesNotifier, CategoriesState>(
        CategoriesNotifier.new);
