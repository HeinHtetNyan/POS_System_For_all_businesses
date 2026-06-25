class ResellerWalletModel {
  final double availableBalance;
  final double lockedBalance;
  final double totalEarned;
  final double totalPaidOut;
  final double commissionRatePct;
  final double minPayoutAmount;
  final String currencyCode;
  final List<WalletTransactionModel> transactions;

  const ResellerWalletModel({
    required this.availableBalance,
    required this.lockedBalance,
    required this.totalEarned,
    required this.totalPaidOut,
    required this.commissionRatePct,
    required this.minPayoutAmount,
    required this.currencyCode,
    required this.transactions,
  });

  factory ResellerWalletModel.fromJson(Map<String, dynamic> json) {
    final rawTx = json['transactions'] as List<dynamic>? ?? [];
    return ResellerWalletModel(
      availableBalance: (json['available_balance'] as num?)?.toDouble() ?? 0.0,
      lockedBalance: (json['locked_balance'] as num?)?.toDouble() ?? 0.0,
      totalEarned: (json['total_earned'] as num?)?.toDouble() ?? 0.0,
      totalPaidOut: (json['total_paid_out'] as num?)?.toDouble() ?? 0.0,
      commissionRatePct: (json['commission_rate_pct'] as num?)?.toDouble() ?? 0.0,
      minPayoutAmount: (json['min_payout_amount'] as num?)?.toDouble() ?? 0.0,
      currencyCode: json['currency_code'] as String? ?? 'MMK',
      transactions: rawTx
          .map((e) =>
              WalletTransactionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WalletTransactionModel {
  final String id;
  final String transactionType;
  final String? status;
  final double amount;
  final String? description;
  final DateTime createdAt;

  const WalletTransactionModel({
    required this.id,
    required this.transactionType,
    this.status,
    required this.amount,
    this.description,
    required this.createdAt,
  });

  bool get isPendingPayout =>
      transactionType == 'PAYOUT_LOCKED' && (status == 'PENDING' || status == null);

  bool get isCredit =>
      transactionType == 'COMMISSION_EARNED' ||
      transactionType == 'PAYOUT_REJECTED' ||
      transactionType == 'BONUS' ||
      transactionType == 'CREDIT' ||
      transactionType == 'COMMISSION';

  bool get isDebit =>
      transactionType == 'PAYOUT_LOCKED' ||
      transactionType == 'PAYOUT_COMPLETED' ||
      transactionType == 'COMMISSION_REVERSAL' ||
      transactionType == 'PENALTY' ||
      transactionType == 'DEBIT' ||
      transactionType == 'PAYOUT';

  String get displayLabel {
    switch (transactionType) {
      case 'COMMISSION_EARNED':
        return 'Commission';
      case 'COMMISSION_REVERSAL':
        return 'Commission Reversal';
      case 'PAYOUT_LOCKED':
        return 'Payout Reserved';
      case 'PAYOUT_REJECTED':
        return 'Payout Released';
      case 'PAYOUT_COMPLETED':
        return 'Payout Paid';
      case 'MANUAL_ADJUSTMENT':
        return 'Adjustment';
      case 'BONUS':
        return 'Bonus';
      case 'PENALTY':
        return 'Penalty';
      default:
        return transactionType;
    }
  }

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as String,
      transactionType: json['transaction_type'] as String? ?? 'COMMISSION_EARNED',
      status: json['status'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class CommissionModel {
  final String id;
  final String tenantName;
  final double amount;
  final String status;
  final DateTime earnedAt;

  const CommissionModel({
    required this.id,
    required this.tenantName,
    required this.amount,
    required this.status,
    required this.earnedAt,
  });

  factory CommissionModel.fromJson(Map<String, dynamic> json) {
    return CommissionModel(
      id: json['id'] as String,
      tenantName: json['tenant_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'PENDING',
      earnedAt: DateTime.parse(json['earned_at'] as String? ?? json['created_at'] as String),
    );
  }
}

class ReferralModel {
  final String id;
  final String businessName;
  final String status;
  final String subscriptionStatus;
  final DateTime joinedAt;
  final double totalCommissionsEarned;

  const ReferralModel({
    required this.id,
    required this.businessName,
    required this.status,
    required this.subscriptionStatus,
    required this.joinedAt,
    required this.totalCommissionsEarned,
  });

  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      id: (json['id'] ?? json['tenant_id'])?.toString() ?? '',
      businessName: json['tenant_name'] as String? ?? json['business_name'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      subscriptionStatus: json['subscription_status'] as String? ?? 'ACTIVE',
      joinedAt: DateTime.parse(
          json['referred_at'] as String? ??
          json['joined_at'] as String? ??
          json['created_at'] as String),
      totalCommissionsEarned:
          (json['total_commissions'] as num?)?.toDouble() ??
          (json['total_commissions_earned'] as num?)?.toDouble() ??
          0.0,
    );
  }
}
