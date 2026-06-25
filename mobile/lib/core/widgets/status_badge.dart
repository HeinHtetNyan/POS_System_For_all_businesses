import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const StatusBadge({super.key, required this.status, this.label});

  Color get _textColor {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'OPEN':
      case 'COMPLETED':
      case 'PAID':
      case 'RECEIVED':
      case 'APPROVED':
      case 'IN_STOCK':
      case 'SUCCESS':
        return AppColors.success;
      case 'ORDERED':
      case 'PROCESSING':
      case 'INFO':
      case 'REVIEW':
        return AppColors.info;
      case 'PENDING':
      case 'DRAFT':
      case 'PARTIAL':
      case 'TRIAL':
      case 'REFUNDED':
      case 'LOW_STOCK':
      case 'SUSPENDED':
        return AppColors.warning;
      case 'INACTIVE':
      case 'VOIDED':
      case 'CANCELLED':
      case 'EXPIRED':
      case 'REJECTED':
      case 'OUT_OF_STOCK':
      case 'FAILED':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Color get _bgColor {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'OPEN':
      case 'COMPLETED':
      case 'PAID':
      case 'RECEIVED':
      case 'APPROVED':
      case 'IN_STOCK':
      case 'SUCCESS':
        return AppColors.successLight;
      case 'ORDERED':
      case 'PROCESSING':
      case 'INFO':
      case 'REVIEW':
        return AppColors.infoLight;
      case 'PENDING':
      case 'DRAFT':
      case 'PARTIAL':
      case 'TRIAL':
      case 'REFUNDED':
      case 'LOW_STOCK':
      case 'SUSPENDED':
        return AppColors.warningLight;
      case 'INACTIVE':
      case 'VOIDED':
      case 'CANCELLED':
      case 'EXPIRED':
      case 'REJECTED':
      case 'OUT_OF_STOCK':
      case 'FAILED':
        return AppColors.errorLight;
      default:
        return AppColors.surfaceVariant;
    }
  }

  String get _displayLabel {
    final text = label ?? status;
    if (text.isEmpty) return text;
    return text[0].toUpperCase() +
        text.substring(1).toLowerCase().replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _textColor.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        _displayLabel,
        style: TextStyle(
          color: _textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
