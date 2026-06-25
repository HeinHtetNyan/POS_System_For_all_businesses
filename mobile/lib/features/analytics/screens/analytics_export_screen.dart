import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

Map<String, String> _dateRangeForPeriod(String period) {
  final now = DateTime.now();
  late DateTime from;
  switch (period) {
    case '1d':
      from = DateTime(now.year, now.month, now.day);
      break;
    case '7d':
      from = now.subtract(const Duration(days: 6));
      break;
    case '30d':
      from = now.subtract(const Duration(days: 29));
      break;
    case '90d':
      from = now.subtract(const Duration(days: 89));
      break;
    default:
      from = now.subtract(const Duration(days: 6));
  }
  final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return {
    'date_from': from.toIso8601String().split('T').first,
    'date_to': to.toIso8601String().split('T').first,
  };
}

class _ExportOption {
  final String title;
  final String subtitle;
  final IconData icon;
  final String endpoint;
  final String fileName;

  const _ExportOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.endpoint,
    required this.fileName,
  });
}

const _exportOptions = [
  _ExportOption(
    title: 'Sales Report',
    subtitle: 'All orders with totals and payment methods',
    icon: Icons.receipt_long,
    endpoint: '/analytics/export/orders',
    fileName: 'SalesReport',
  ),
  _ExportOption(
    title: 'Sales Refunds',
    subtitle: 'Refunded orders and amounts',
    icon: Icons.assignment_return,
    endpoint: '/analytics/export/sales-refunds',
    fileName: 'SalesRefunds',
  ),
  _ExportOption(
    title: 'Top Products',
    subtitle: 'Best-selling products by quantity and revenue',
    icon: Icons.star,
    endpoint: '/analytics/export/top-products',
    fileName: 'TopProducts',
  ),
  _ExportOption(
    title: 'Sales by Category',
    subtitle: 'Revenue breakdown by product category',
    icon: Icons.category,
    endpoint: '/analytics/export/sales-by-category',
    fileName: 'SalesByCategory',
  ),
  _ExportOption(
    title: 'Sales by Cashier',
    subtitle: 'Performance summary per cashier',
    icon: Icons.people,
    endpoint: '/analytics/export/sales-by-cashier',
    fileName: 'SalesByCashier',
  ),
  _ExportOption(
    title: 'Inventory Stock',
    subtitle: 'Current stock levels for all products',
    icon: Icons.inventory_2,
    endpoint: '/analytics/export/inventory-stocks',
    fileName: 'InventoryStock',
  ),
  _ExportOption(
    title: 'Low Stock Report',
    subtitle: 'Products below reorder threshold',
    icon: Icons.warning_amber,
    endpoint: '/analytics/export/low-stock',
    fileName: 'LowStock',
  ),
  _ExportOption(
    title: 'Payment Methods',
    subtitle: 'Sales split by payment method',
    icon: Icons.payment,
    endpoint: '/analytics/export/payment-methods',
    fileName: 'PaymentMethods',
  ),
  _ExportOption(
    title: 'Profit Report',
    subtitle: 'Revenue, cost and profit margin analysis',
    icon: Icons.trending_up,
    endpoint: '/analytics/export/profit-report',
    fileName: 'ProfitReport',
  ),
];

class AnalyticsExportScreen extends ConsumerStatefulWidget {
  const AnalyticsExportScreen({super.key});

  @override
  ConsumerState<AnalyticsExportScreen> createState() =>
      _AnalyticsExportScreenState();
}

class _AnalyticsExportScreenState
    extends ConsumerState<AnalyticsExportScreen> {
  String _selectedPeriod = '30d';
  final Set<int> _loadingIndices = {};

  Future<void> _download(int index, _ExportOption option) async {
    setState(() => _loadingIndices.add(index));
    try {
      final dateRange = _dateRangeForPeriod(_selectedPeriod);
      final queryParams = {
        'format': 'csv',
        'date_from': dateRange['date_from']!,
        'date_to': dateRange['date_to']!,
      };

      final response = await apiClient.dio.get(
        option.endpoint,
        queryParameters: queryParams,
        options: Options(responseType: ResponseType.bytes),
      );

      final timestamp =
          DateTime.now().millisecondsSinceEpoch;
      final fileName = 'POS_${option.fileName}_$timestamp.csv';
      String savePath;

      if (Platform.isAndroid) {
        final androidInfo = await _getAndroidSdkVersion();
        if (androidInfo < 33) {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            _showError('Storage permission denied');
            return;
          }
        }
        savePath = '/storage/emulated/0/Download/$fileName';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        savePath = '${dir.path}/$fileName';
      }

      final file = File(savePath);
      await file.writeAsBytes(List<int>.from(response.data as List));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved to Downloads: POS_${option.fileName}.csv',
              style: const TextStyle(color: AppColors.primaryFg),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loadingIndices.remove(index));
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<int> _getAndroidSdkVersion() async {
    try {
      final result =
          await Process.run('getprop', ['ro.build.version.sdk']);
      return int.tryParse(result.stdout.toString().trim()) ?? 33;
    } catch (_) {
      return 33;
    }
  }

  @override
  Widget build(BuildContext context) {
    final periods = ['1d', '7d', '30d', '90d'];
    final periodLabels = ['Today', '7 Days', '30 Days', '90 Days'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Export Data',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Date Range',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(periods.length, (i) {
                      final selected = _selectedPeriod == periods[i];
                      return Padding(
                        padding: EdgeInsets.only(
                            right: i < periods.length - 1 ? 8 : 0),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedPeriod = periods[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              periodLabels[i],
                              style: TextStyle(
                                color: selected
                                    ? AppColors.primaryFg
                                    : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.divider),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _exportOptions.length,
              separatorBuilder: (_, __) =>
                  Container(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final option = _exportOptions[index];
                final isLoading = _loadingIndices.contains(index);
                return _ExportListTile(
                  option: option,
                  isLoading: isLoading,
                  onDownload: () => _download(index, option),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportListTile extends StatelessWidget {
  final _ExportOption option;
  final bool isLoading;
  final VoidCallback onDownload;

  const _ExportListTile({
    required this.option,
    required this.isLoading,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(option.icon, color: AppColors.primary, size: 22),
        ),
        title: Text(
          option.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            option.subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        trailing: SizedBox(
          width: 40,
          height: 40,
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : IconButton(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download),
                  color: AppColors.primary,
                  tooltip: 'Download CSV',
                  splashRadius: 20,
                ),
        ),
      ),
    );
  }
}
