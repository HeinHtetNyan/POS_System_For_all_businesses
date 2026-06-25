import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../models/purchase_order_model.dart';

class ProcurementRepository {
  Dio get _dio => apiClient.dio;

  Future<({List<PurchaseOrderModel> items, int total})>
      listPurchaseOrders({
    String? status,
    String? supplierId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (status != null) 'status': status,
      if (supplierId != null) 'supplier_id': supplierId,
    };
    final response = await _dio.get(
        ApiEndpoints.purchaseOrders, queryParameters: params);
    final data = response.data as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return (
      items: rawItems
          .map((e) =>
              PurchaseOrderModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int? ?? 0,
    );
  }

  Future<PurchaseOrderModel> getPurchaseOrder(String id) async {
    final response =
        await _dio.get('${ApiEndpoints.purchaseOrders}/$id');
    return PurchaseOrderModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<PurchaseOrderModel> createPurchaseOrder(
      Map<String, dynamic> data) async {
    final response =
        await _dio.post(ApiEndpoints.purchaseOrders, data: data);
    return PurchaseOrderModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<PurchaseOrderModel> submitPurchaseOrder(String id) async {
    final response = await _dio.post(
      '${ApiEndpoints.purchaseOrders}/$id/submit',
    );
    return PurchaseOrderModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<PurchaseOrderModel> approvePurchaseOrder(String id) async {
    final response = await _dio.post(
      '${ApiEndpoints.purchaseOrders}/$id/approve',
    );
    return PurchaseOrderModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<void> cancelPurchaseOrder(String id, {String? reason}) async {
    await _dio.post(
      '${ApiEndpoints.purchaseOrders}/$id/cancel',
      data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason},
    );
  }

  Future<List<SupplierModel>> getSuppliers() async {
    final response = await _dio.get(ApiEndpoints.suppliers);
    final data = response.data as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return rawItems
        .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SupplierModel> createSupplier(Map<String, dynamic> data) async {
    final response = await _dio.post(ApiEndpoints.suppliers, data: data);
    return SupplierModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SupplierModel> updateSupplier(
      String id, Map<String, dynamic> data) async {
    final response =
        await _dio.put('${ApiEndpoints.suppliers}/$id', data: data);
    return SupplierModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteSupplier(String id) async {
    await _dio.delete('${ApiEndpoints.suppliers}/$id');
  }

  Future<Map<String, dynamic>> getPayables({String? supplierId}) async {
    final params = <String, dynamic>{
      if (supplierId != null) 'supplier_id': supplierId,
    };
    final response = await _dio.get(ApiEndpoints.payables,
        queryParameters: params.isNotEmpty ? params : null);
    return response.data as Map<String, dynamic>;
  }

  Future<void> createPurchaseOrderItem(
      String poId, Map<String, dynamic> data) async {
    await _dio.post('${ApiEndpoints.purchaseOrders}/$poId/items', data: data);
  }

  Future<({List<Map<String, dynamic>> items, int total})> listGoodsReceipts(
      {String? purchaseOrderId, int page = 1, int pageSize = 20}) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (purchaseOrderId != null) 'purchase_order_id': purchaseOrderId,
    };
    final response = await _dio.get('/procurement/receipts', queryParameters: params);
    final data = response.data as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return (
      items: rawItems.map((e) => e as Map<String, dynamic>).toList(),
      total: data['total'] as int? ?? 0,
    );
  }

  Future<Map<String, dynamic>> getGoodsReceipt(String id) async {
    final response = await _dio.get('/procurement/receipts/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createGoodsReceipt(Map<String, dynamic> data) async {
    final response = await _dio.post('/procurement/receipts', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirmGoodsReceipt(String id) async {
    final response = await _dio.post('/procurement/receipts/$id/confirm');
    return response.data as Map<String, dynamic>;
  }

  Future<({List<Map<String, dynamic>> items, int total})> listPayables(
      {String? supplierId, String? status, int page = 1, int pageSize = 20}) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (supplierId != null) 'supplier_id': supplierId,
      if (status != null) 'status': status,
    };
    final response = await _dio.get(ApiEndpoints.payables, queryParameters: params);
    final data = response.data as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return (
      items: rawItems.map((e) => e as Map<String, dynamic>).toList(),
      total: data['total'] as int? ?? 0,
    );
  }

  Future<Map<String, dynamic>> recordPayablePayment(
      String payableId, Map<String, dynamic> data) async {
    final response = await _dio.post(
        '${ApiEndpoints.payables}/$payableId/payments',
        data: data);
    return response.data as Map<String, dynamic>;
  }
}

final procurementRepositoryProvider =
    Provider((_) => ProcurementRepository());
