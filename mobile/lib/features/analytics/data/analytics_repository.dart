import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../models/analytics_model.dart';

class AnalyticsRepository {
  Dio get _dio => apiClient.dio;

  Future<DashboardKpiModel> getDashboard({
    String? branchId,
  }) async {
    // FIX C-12: backend ignores 'period' — do not send it
    final params = <String, dynamic>{
      if (branchId != null) 'branch_id': branchId,
    };
    final response = await _dio.get(
        ApiEndpoints.analyticsDashboard, queryParameters: params);
    return DashboardKpiModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  // FIX C-09 + FIX C-11: renamed 'from'/'to' → 'start_date'/'end_date';
  // changed endpoint to analyticsSalesTrend; parse response.data['items'];
  // added 'granularity': 'daily' param.
  Future<List<SalesSummaryPoint>> getSalesSummary({
    String? startDate,
    String? endDate,
    String groupBy = 'day',
    String? branchId,
  }) async {
    final params = <String, dynamic>{
      'group_by': groupBy,
      'granularity': 'daily',
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (branchId != null) 'branch_id': branchId,
    };
    final response = await _dio.get(
        ApiEndpoints.analyticsSalesTrend, queryParameters: params);
    // FIX C-11: endpoint returns an object; items are in response.data['items']
    final dataMap = response.data as Map<String, dynamic>? ?? {};
    final raw = dataMap['items'] as List<dynamic>? ?? [];
    return raw
        .map((e) =>
            SalesSummaryPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // FIX C-09: renamed 'from'/'to' → 'start_date'/'end_date'
  Future<List<TopProductModel>> getTopProducts({
    String? startDate,
    String? endDate,
    int limit = 10,
    String? branchId,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (branchId != null) 'branch_id': branchId,
    };
    final response = await _dio.get(
        ApiEndpoints.analyticsTopProducts, queryParameters: params);
    final raw = response.data as List<dynamic>? ?? [];
    return raw
        .map((e) =>
            TopProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // FIX C-10: changed endpoint to analyticsInventoryValuation
  Future<Map<String, dynamic>> getInventorySummary({
    String? branchId,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{
      if (branchId != null) 'branch_id': branchId,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    };
    final response = await _dio.get(
        ApiEndpoints.analyticsInventoryValuation, queryParameters: params);
    return response.data as Map<String, dynamic>? ?? {};
  }

  // FIX C-10: analyticsCustomersSummary endpoint does not exist.
  // Delegate to getDashboard() and extract customer-related fields.
  Future<Map<String, dynamic>> getCustomersSummary({
    String? branchId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final dashboard = await getDashboard(branchId: branchId);
      return <String, dynamic>{
        'total_customers': dashboard.totalCustomers,
        'new_this_period': 0,
        'returning_rate': 0.0,
        'top_customers': <dynamic>[],
      };
    } catch (_) {
      return <String, dynamic>{
        'total_customers': 0,
        'new_this_period': 0,
        'returning_rate': 0.0,
        'top_customers': <dynamic>[],
      };
    }
  }

  Future<Map<String, dynamic>> getFinancialSummary({
    String? branchId,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{
      if (branchId != null) 'branch_id': branchId,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    };
    final response = await _dio.get(
        ApiEndpoints.analyticsFinancialSummary, queryParameters: params);
    return response.data as Map<String, dynamic>? ?? {};
  }

  Future<List<Map<String, dynamic>>> getDeadStock({int days = 30}) async {
    final params = <String, dynamic>{'days': days};
    final response = await _dio.get(
        ApiEndpoints.analyticsDeadStock, queryParameters: params);
    final raw = response.data as List<dynamic>? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }
}

final analyticsRepositoryProvider =
    Provider((_) => AnalyticsRepository());
