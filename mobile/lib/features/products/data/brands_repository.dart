import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';

class BrandModel {
  final String id;
  final String name;
  final String? description;
  final bool isActive;

  const BrandModel({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) => BrandModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );
}

class BrandsRepository {
  Dio get _dio => apiClient.dio;

  Future<List<BrandModel>> getBrands() async {
    final r = await _dio.get(ApiEndpoints.brands);
    final List<dynamic> raw;
    if (r.data is Map<String, dynamic>) {
      final data = r.data as Map<String, dynamic>;
      raw = data['items'] as List<dynamic>? ?? [];
    } else {
      raw = r.data as List<dynamic>? ?? [];
    }
    return raw
        .map((e) => BrandModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BrandModel> createBrand(Map<String, dynamic> data) async {
    final r = await _dio.post(ApiEndpoints.brands, data: data);
    return BrandModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<BrandModel> updateBrand(String id, Map<String, dynamic> data) async {
    final r = await _dio.patch('${ApiEndpoints.brands}/$id', data: data);
    return BrandModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deleteBrand(String id) async {
    await _dio.delete('${ApiEndpoints.brands}/$id');
  }
}

final brandsRepositoryProvider =
    Provider<BrandsRepository>((_) => BrandsRepository());
