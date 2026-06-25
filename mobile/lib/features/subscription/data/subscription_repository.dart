import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';

class SubscriptionRepository {
  Dio get _dio => apiClient.dio;

  Future<Map<String, dynamic>> getStatus() async {
    final r = await _dio.get(ApiEndpoints.subscriptionStatus);
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getPlans() async {
    final r = await _dio.get(ApiEndpoints.subscriptionPlans);
    final raw = r.data as List<dynamic>? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getBillingHistory() async {
    final r = await _dio.get('/subscriptions/billing');
    final data = r.data as Map<String, dynamic>;
    final raw = data['items'] as List<dynamic>? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }

  // H-38: downgrade endpoint
  Future<void> requestDowngrade(String planId) async {
    await _dio.post(ApiEndpoints.subscriptionDowngrade, data: {'plan_id': planId});
  }

  Future<String> uploadProofFile(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post('/subscriptions/payment-proofs/upload', data: formData);
    final data = response.data as Map<String, dynamic>;
    return data['url'] as String? ?? '';
  }

  Future<Map<String, dynamic>> submitPaymentProof(Map<String, dynamic> payload) async {
    final response = await _dio.post('/subscriptions/payment-proofs', data: payload);
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getPaymentProofs({int page = 1}) async {
    final params = {'page': page, 'page_size': 20};
    final response = await _dio.get('/subscriptions/payment-proofs', queryParameters: params);
    final data = response.data as Map<String, dynamic>;
    final raw = data['items'] as List<dynamic>? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }
}

final subscriptionRepositoryProvider =
    Provider<SubscriptionRepository>((_) => SubscriptionRepository());
