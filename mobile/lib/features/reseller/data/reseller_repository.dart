import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../models/reseller_wallet_model.dart';

class ResellerRepository {
  Dio get _dio => apiClient.dio;

  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _dio.get(ApiEndpoints.resellerDashboard);
    return response.data as Map<String, dynamic>;
  }

  Future<ResellerWalletModel> getWallet() async {
    final response = await _dio.get(ApiEndpoints.resellerWallet);
    return ResellerWalletModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<({List<CommissionModel> items, int total})> listCommissions({
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    final response = await _dio.get(
        ApiEndpoints.resellerCommissions, queryParameters: params);
    final data = response.data as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return (
      items: rawItems
          .map((e) =>
              CommissionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int? ?? 0,
    );
  }

  Future<({List<ReferralModel> items, int total})> listReferrals({
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    final response = await _dio.get(
        ApiEndpoints.resellerReferrals, queryParameters: params);
    final data = response.data as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return (
      items: rawItems
          .map((e) =>
              ReferralModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int? ?? 0,
    );
  }

  Future<void> requestPayout(double amount, {String? reason}) async {
    final body = <String, dynamic>{'amount': amount};
    if (reason != null && reason.trim().isNotEmpty) {
      body['reason'] = reason.trim();
    }
    await _dio.post(ApiEndpoints.resellerPayouts, data: body);
  }

  Future<List<Map<String, dynamic>>> getBusinesses({int page = 1}) async {
    final r = await _dio.get(ApiEndpoints.resellerMeBusinesses,
        queryParameters: {'page': page, 'page_size': 20});
    final data = r.data as Map<String, dynamic>;
    final raw = data['items'] as List<dynamic>? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getAnalytics({String? period}) async {
    final params = <String, dynamic>{};
    if (period != null) params['period'] = period;
    final r = await _dio.get('/reseller/analytics',
        queryParameters: params.isNotEmpty ? params : null);
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getManagedBusinesses() async {
    final r = await _dio.get('/resellers/me/businesses');
    final raw = r.data as List<dynamic>? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }

  Future<({List<Map<String, dynamic>> items, int total})> getBusinessCustomers(
    String tenantId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'tenant_id': tenantId,
      'page': page,
      'page_size': pageSize,
    };
    final r = await _dio.get('/customers', queryParameters: params);
    final data = r.data as Map<String, dynamic>;
    final raw = data['items'] as List<dynamic>? ?? [];
    return (
      items: raw.cast<Map<String, dynamic>>(),
      total: data['total'] as int? ?? 0,
    );
  }

  Future<({List<Map<String, dynamic>> items, int total})> getBusinessInventory(
    String tenantId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'tenant_id': tenantId,
      'page': page,
      'page_size': pageSize,
    };
    final r = await _dio.get('/inventory/stock-levels', queryParameters: params);
    final data = r.data as Map<String, dynamic>;
    final raw = data['items'] as List<dynamic>? ?? [];
    return (
      items: raw.cast<Map<String, dynamic>>(),
      total: data['total'] as int? ?? 0,
    );
  }

  Future<({List<Map<String, dynamic>> items, int total})> getBusinessPurchaseOrders(
    String tenantId, {
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'tenant_id': tenantId,
      'page': page,
      'page_size': pageSize,
    };
    if (status != null) params['status'] = status;
    final r = await _dio.get('/procurement/purchase-orders', queryParameters: params);
    final data = r.data as Map<String, dynamic>;
    final raw = data['items'] as List<dynamic>? ?? [];
    return (
      items: raw.cast<Map<String, dynamic>>(),
      total: data['total'] as int? ?? 0,
    );
  }

  Future<({List<Map<String,dynamic>> branches, Map<String,dynamic>? business})> getBusinessDetail(String tenantId) async {
    final branchResponse = await _dio.get('/resellers/me/branches', queryParameters: {'tenant_id': tenantId});
    final branchData = branchResponse.data as Map<String, dynamic>? ?? {};
    final rawBranches = branchData['branches'] as List<dynamic>? ?? [];
    return (
      branches: rawBranches.cast<Map<String, dynamic>>(),
      business: null,
    );
  }

  Future<List<String>> getMyPermissions(String tenantId) async {
    final r = await _dio.get('/resellers/me/permissions', queryParameters: {'tenant_id': tenantId});
    final data = r.data as Map<String, dynamic>? ?? {};
    final raw = data['permissions'] as List<dynamic>? ?? [];
    return raw.cast<String>();
  }

  Future<Map<String, dynamic>> getBusinessSubscription(String tenantId) async {
    final r = await _dio.get('/reseller/tenants/$tenantId/subscription');
    return r.data as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getResellerProfile() async {
    final r = await _dio.get('/auth/me');
    return r.data as Map<String, dynamic>? ?? {};
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await _dio.patch('/users/$userId', data: data);
  }

  Future<List<Map<String, dynamic>>> getReferralCodes() async {
    final r = await _dio.get(ApiEndpoints.resellerReferralCodes,
        queryParameters: {'page': 1, 'page_size': 20});
    final data = r.data as Map<String, dynamic>;
    final raw = data['items'] as List<dynamic>? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getReferralStats() async {
    final r = await _dio.get(ApiEndpoints.resellerReferralStats);
    return r.data as Map<String, dynamic>? ?? {};
  }

  Future<String?> getReferralCodeLink(String codeId) async {
    try {
      final r = await _dio.get(ApiEndpoints.resellerReferralCodeLink(codeId));
      final data = r.data as Map<String, dynamic>?;
      return data?['referral_url'] as String? ?? data?['registration_url'] as String? ?? data?['link'] as String? ?? data?['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listWalletTransactions({int page = 1, int pageSize = 20}) async {
    final r = await _dio.get(ApiEndpoints.resellerWalletTransactions,
        queryParameters: {'page': page, 'page_size': pageSize});
    final data = r.data as Map<String, dynamic>;
    final raw = data['items'] as List<dynamic>? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getTenantLatestProof(
      String tenantId) async {
    try {
      final r = await _dio
          .get(ApiEndpoints.resellerTenantLatestProof(tenantId));
      final data = r.data;
      if (data == null) return null;
      return data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> uploadTenantPaymentProof(
      String tenantId, File file, String actionType) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
      'action_type': actionType,
    });
    await _dio.post(
      ApiEndpoints.resellerTenantProofUpload(tenantId),
      data: formData,
    );
  }

  Future<Map<String, dynamic>> generateReferralCode() async {
    final res = await _dio.post(ApiEndpoints.resellerReferralCodes);
    return (res.data as Map<String, dynamic>? ?? {});
  }

  Future<void> cancelPayout(String payoutId) async {
    await _dio.delete('/reseller/payouts/$payoutId');
  }
}

final resellerRepositoryProvider =
    Provider((_) => ResellerRepository());
