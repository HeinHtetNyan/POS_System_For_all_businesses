class CustomerModel {
  final String id;
  final String customerCode;
  final String name;
  final String? phone;
  final String? email;
  final double creditLimit;
  final double currentBalance;
  final bool isActive;
  final String? notes;
  final String? address;
  final int totalOrders;
  final double totalSpent;
  final DateTime? createdAt;
  final DateTime? lastPurchaseAt;

  const CustomerModel({
    required this.id,
    required this.customerCode,
    required this.name,
    this.phone,
    this.email,
    required this.creditLimit,
    required this.currentBalance,
    required this.isActive,
    this.notes,
    this.address,
    this.totalOrders = 0,
    this.totalSpent = 0.0,
    this.createdAt,
    this.lastPurchaseAt,
  });

  bool get hasCredit => creditLimit > 0;
  double get availableCredit => creditLimit - currentBalance;

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      customerCode: json['customer_code'] as String? ?? '',
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      currentBalance:
          (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      address: json['address'] as String?,
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      lastPurchaseAt: json['last_purchase_at'] != null
          ? DateTime.tryParse(json['last_purchase_at'] as String)
          : null,
    );
  }
}
