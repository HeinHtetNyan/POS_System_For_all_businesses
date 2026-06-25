import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../models/category_model.dart';

class CategoriesRepository {
  Dio get _dio => apiClient.dio;

  Future<List<CategoryModel>> getCategories() async {
    final r = await _dio.get(ApiEndpoints.categories);
    final List<dynamic> raw;
    if (r.data is Map<String, dynamic>) {
      final data = r.data as Map<String, dynamic>;
      raw = data['items'] as List<dynamic>? ?? [];
    } else {
      raw = r.data as List<dynamic>? ?? [];
    }
    return raw
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CategoryModel> createCategory(Map<String, dynamic> data) async {
    final r = await _dio.post(ApiEndpoints.categories, data: data);
    return CategoryModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<CategoryModel> updateCategory(
      String id, Map<String, dynamic> data) async {
    final r =
        await _dio.patch('${ApiEndpoints.categories}/$id', data: data);
    return CategoryModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String id) async {
    await _dio.delete('${ApiEndpoints.categories}/$id');
  }
}

final categoriesRepositoryProvider =
    Provider<CategoriesRepository>((_) => CategoriesRepository());
