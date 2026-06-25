class ApiEndpoints {
  // Auth
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String changePassword = '/auth/change-password';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Users
  static const String users = '/users';
  static String user(String id) => '/users/$id';

  // Devices
  static const String devices = '/devices';
  static String device(String id) => '/devices/$id';
  static String deviceHeartbeat(String id) => '/devices/$id/heartbeat';

  // Products
  static const String products = '/products';
  static String product(String id) => '/products/$id';
  static String productVariants(String id) => '/products/$id/variants';

  // Categories
  static const String categories = '/categories';

  // Brands
  static const String brands = '/brands';

  // Inventory
  static const String stockLevels = '/inventory/stock-levels';
  static const String stockMovements = '/inventory/movements';
  static const String inventoryAdjustments = '/inventory/adjustments';
  static const String openingStockAdjustment = '/inventory/adjustments';

  // Customers
  static const String customers = '/customers';
  static String customer(String id) => '/customers/$id';
  static const String customerSearch = '/customers/search';
  static String customerLedger(String id) => '/customers/$id/ledger';
  static String customerPayments(String id) => '/customers/$id/payments';

  // Cashier Sessions
  static const String cashierSessions = '/cashier-sessions';
  static String cashierSession(String id) => '/cashier-sessions/$id';
  static String closeSession(String id) => '/cashier-sessions/$id/close';

  // Sales / Cart
  static const String carts = '/sales/carts';
  static String cart(String id) => '/sales/carts/$id';
  static String cartItems(String id) => '/sales/carts/$id/items';
  static String cartItem(String cartId, String itemId) =>
      '/sales/carts/$cartId/items/$itemId';
  static const String checkout = '/sales/checkout';

  // Orders
  static const String orders = '/sales/orders';
  static String order(String id) => '/sales/orders/$id';
  static String voidOrder(String id) => '/sales/orders/$id/void';

  // Payments / Refunds
  static const String payments = '/payments';
  static String refund(String orderId) => '/payments/$orderId/refund';
  static const String refunds = '/payments/refunds';

  // Receipts
  static const String receipts = '/receipts';
  static String receiptByOrder(String orderId) => '/receipts/order/$orderId';

  // Sync
  static const String syncPush = '/sync/push';
  static const String syncPull = '/sync/pull';

  // Analytics
  static const String analyticsDashboard = '/analytics/dashboard';
  static const String analyticsSalesSummary = '/analytics/sales/summary';
  static const String analyticsTopProducts = '/analytics/sales/top-products';
  static const String analyticsInventorySummary = '/analytics/inventory/summary';
  static const String analyticsCustomersSummary = '/analytics/customers/summary';
  static const String analyticsFinancialSummary = '/analytics/financial/summary';
  static const String analyticsStaffSummary = '/analytics/staff/summary';
  static const String analyticsDeadStock = '/analytics/inventory/dead-stock';
  static const String analyticsInventoryValuation = '/analytics/inventory/valuation';
  static const String analyticsInventoryLowStock = '/analytics/inventory/low-stock';
  static const String analyticsSalesTrend = '/analytics/sales/trend';

  // Analytics export endpoints
  static const String analyticsExportOrders = '/analytics/export/orders';
  static const String analyticsExportSalesRefunds = '/analytics/export/sales-refunds';
  static const String analyticsExportTopProducts = '/analytics/export/top-products';
  static const String analyticsExportSalesByCategory = '/analytics/export/sales-by-category';
  static const String analyticsExportSalesByCashier = '/analytics/export/sales-by-cashier';
  static const String analyticsExportInventoryStocks = '/analytics/export/inventory-stocks';
  static const String analyticsExportLowStock = '/analytics/export/low-stock';
  static const String analyticsExportPaymentMethods = '/analytics/export/payment-methods';
  static const String analyticsExportProfitReport = '/analytics/export/profit-report';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationUnreadCount = '/notifications/unread-count';
  static String markNotificationRead(String id) => '/notifications/$id/read';
  static const String markAllRead = '/notifications/read-all';
  static const String notificationPreferences = '/notifications/preferences';

  // Subscription purchase
  static const String publicPlans = '/subscriptions/plans';
  static const String paymentProofs = '/subscriptions/payment-proofs';
  static const String uploadPaymentProof = '/subscriptions/payment-proofs/upload';

  // Subscriptions
  static const String subscriptionStatus = '/subscriptions/status';
  static const String subscriptionBillingHistory = '/subscriptions/billing-history';
  static const String subscriptionDowngrade = '/subscriptions/downgrade';

  // Tenants
  static const String tenants = '/tenants';
  static String tenant(String id) => '/tenants/$id';
  static String tenantSettings(String id) => '/tenants/$id/settings';
  static String tenantSubscriptionToggleRenewal(String id) => '/tenants/$id/subscription/toggle-renewal';

  // Procurement
  static const String purchaseOrders = '/procurement/purchase-orders';
  static const String goodsReceipts = '/procurement/receipts';
  static const String payables = '/procurement/payables';

  // GRN
  static const String goodsReceiptsList = '/procurement/receipts';
  static String goodsReceiptDetail(String id) => '/procurement/receipts/$id';
  static String confirmGoodsReceipt(String id) => '/procurement/receipts/$id/confirm';

  // Payables
  static const String payablesList = '/procurement/payables';
  static String payableDetail(String id) => '/procurement/payables/$id';
  static String recordPayablePayment(String id) => '/procurement/payables/$id/payments';

  // Suppliers
  static const String suppliers = '/suppliers';

  // Branches
  static String branches(String tenantId) => '/tenants/$tenantId/branches';
  static const String adminBranches = '/admin/branches';

  // Resellers (admin view)
  static const String resellers = '/resellers';
  static String reseller(String id) => '/resellers/$id';

  // Reseller cross-business
  static const String resellerMeBusinesses = '/resellers/me/businesses';

  // Reseller portal (own data)
  static const String resellerDashboard = '/reseller/dashboard';
  static const String resellerWallet = '/reseller/wallet';
  static const String resellerCommissions = '/reseller/commissions';
  static const String resellerReferrals = '/reseller/referrals';
  static const String resellerPayouts = '/reseller/payouts';
  static String resellerPayoutCancel(String id) => '/reseller/payouts/$id/cancel';
  static String resellerPayoutCancelPath(String id) => '/reseller/payouts/$id';
  static const String resellerRequestPayout = '/reseller/request-payout';
  static const String resellerReferralCodes = '/reseller/referral-codes';
  static const String resellerReferralStats = '/reseller/referrals/stats';
  static String resellerReferralCodeLink(String codeId) => '/reseller/referral-codes/$codeId/link';
  static const String resellerWalletTransactions = '/reseller/wallet/transactions';
  static String resellerTenantProofs(String tenantId) =>
      '/reseller/tenants/$tenantId/payment-proofs';
  static String resellerTenantProofUpload(String tenantId) =>
      '/reseller/tenants/$tenantId/payment-proofs/upload';
  static String resellerTenantLatestProof(String tenantId) =>
      '/reseller/tenants/$tenantId/payment-proofs/latest';

  // Reseller business detail
  static const String resellerMeBranches = '/resellers/me/branches';
  static const String resellerMePermissions = '/resellers/me/permissions';
  static String resellerTenantSubscription(String tenantId) => '/reseller/tenants/$tenantId/subscription';

  // Subscription plans
  static const String subscriptionPlans = '/subscriptions/plans';
  static const String adminSubscriptions = '/admin/subscriptions';

  // Admin users
  static const String adminUsersInvite = '/admin/users/invite';
  static String adminUserStatus(String id) => '/users/$id/status';
  static String adminUserResetPassword(String id) => '/users/$id/reset-password';

  // Platform notifications (admin)
  static const String adminNotifications = '/admin/notifications';

  // Admin overview
  static const String adminOverview = '/subscriptions/admin/overview';
  static const String adminCreateTenant = '/admin/tenants';
  static String adminResellerWallet(String id) => '/admin/reseller-finance/wallets/$id';
  static String adminResellerReferrals(String id) => '/admin/reseller-finance/referrals?reseller_id=$id';
  static String adminResellerTransactions(String id) => '/admin/reseller-finance/transactions?reseller_id=$id';

  // Audit logs
  static const String auditLogs = '/audit';

  // Stock levels (parameterized)
  static String stockLevelsByBranch(String branchId) =>
      '/inventory/stock-levels?branch_id=$branchId';
}
