import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/cashier_session/screens/open_session_screen.dart';
import '../../features/cashier_session/providers/session_provider.dart';
import '../../features/pos/screens/pos_screen.dart';
import '../../features/dashboard/screens/cashier_dashboard.dart';
import '../../features/dashboard/screens/manager_dashboard.dart';
import '../../features/dashboard/screens/super_admin_dashboard.dart';
import '../../features/dashboard/screens/reseller_dashboard.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/orders/screens/receipt_screen.dart';
import '../../features/customers/screens/customers_screen.dart';
import '../../features/customers/screens/customer_detail_screen.dart';
import '../../features/customers/screens/customer_form_screen.dart';
import '../../features/customers/screens/customer_ledger_screen.dart';
import '../../features/customers/screens/customer_payments_screen.dart';
import '../../features/customers/screens/customer_statement_screen.dart';
import '../../features/customers/screens/customer_sale_form_screen.dart';
import '../../models/customer_model.dart';
import '../../features/products/screens/products_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/users/screens/users_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/business_settings_screen.dart';
import '../../features/settings/screens/receipt_settings_screen.dart';
import '../../features/settings/screens/tax_settings_screen.dart';
import '../../features/settings/screens/preferences_screen.dart';
import '../../features/procurement/screens/procurement_screen.dart';
import '../../features/procurement/screens/procurement_form_screen.dart';
import '../../features/procurement/screens/suppliers_screen.dart';
import '../../features/procurement/screens/supplier_form_screen.dart';
import '../../features/procurement/screens/supplier_detail_screen.dart';
import '../../models/purchase_order_model.dart';
import '../../features/admin/screens/tenants_screen.dart';
import '../../features/admin/screens/admin_users_screen.dart';
import '../../features/admin/screens/resellers_screen.dart';
import '../../features/admin/screens/plans_screen.dart';
import '../../features/admin/screens/subscriptions_screen.dart';
import '../../features/admin/screens/devices_screen.dart';
import '../../features/admin/screens/audit_screen.dart';
import '../../features/reseller/screens/reseller_dashboard_screen.dart';
import '../../features/reseller/screens/wallet_screen.dart';
import '../../features/reseller/screens/referrals_screen.dart';
import '../../features/reseller/screens/commissions_screen.dart';
import '../../features/subscription/screens/subscription_screen.dart';
import '../../features/products/screens/brands_screen.dart';
import '../../features/products/screens/categories_screen.dart';
import '../../features/reseller/screens/reseller_businesses_screen.dart';
import '../../features/reseller/screens/reseller_analytics_screen.dart';
import '../../features/admin/screens/payment_methods_screen.dart';
import '../../features/admin/screens/admin_business_detail_screen.dart';
import '../../features/admin/screens/admin_reseller_detail_screen.dart';
import '../../features/admin/screens/admin_reseller_finance_screen.dart';
import '../../features/admin/screens/admin_plan_detail_screen.dart';
import '../../features/admin/screens/admin_plan_form_screen.dart';
import '../../features/admin/screens/admin_user_detail_screen.dart';
import '../../features/cashier_session/screens/close_session_screen.dart';
import '../../features/procurement/screens/goods_receipt_list_screen.dart';
import '../../features/procurement/screens/goods_receipt_detail_screen.dart';
import '../../features/procurement/screens/supplier_payables_screen.dart';
import '../../features/procurement/screens/procurement_detail_screen.dart';
import '../../features/settings/screens/branches_screen.dart';
import '../../features/settings/screens/branch_form_screen.dart';
import '../../features/analytics/screens/analytics_export_screen.dart';
import '../../features/reseller/screens/reseller_customers_screen.dart';
import '../../features/reseller/screens/reseller_inventory_screen.dart';
import '../../features/reseller/screens/reseller_procurement_screen.dart';
import '../../features/notifications/screens/notification_preferences_screen.dart';
import '../../features/onboarding/screens/onboarding_wizard_screen.dart';
import '../../features/onboarding/providers/onboarding_provider.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/subscription/screens/pricing_screen.dart';
import '../../features/subscription/screens/subscription_purchase_screen.dart';
import '../../features/reseller/screens/reseller_business_detail_screen.dart';
import '../../features/reseller/screens/reseller_subscription_screen.dart';
import '../../features/reseller/screens/reseller_profile_screen.dart';
import '../../features/reseller/screens/reseller_notifications_screen.dart';
import '../../features/reseller/screens/reseller_plans_screen.dart';
import '../../features/superadmin/screens/platform_notifications_screen.dart';
import '../../features/settings/screens/profile_settings_screen.dart';
import '../../features/subscription/screens/trial_expired_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_shell.dart';
import '../../models/user_model.dart';
import '../api/api_client.dart' show subscriptionExpiredNotifier;

final _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthListenable(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable:
        Listenable.merge([authListenable, subscriptionExpiredNotifier]),
    initialLocation: '/login',
    redirect: (context, state) async {
      final authState = ref.read(authProvider);
      final sessionState = ref.read(sessionProvider);
      final isLoggedIn = authState.isAuthenticated;
      final loc = state.matchedLocation;

      if (!isLoggedIn) {
        if (loc == '/login' || loc == '/forgot-password' || loc == '/register' || loc == '/pricing' || loc.startsWith('/reset-password')) return null;
        return '/login';
      }
      if (loc == '/login') {
        return _homeRoute(authState.user!.role);
      }

      // Subscription expired / suspended intercept for business owners
      if (subscriptionExpiredNotifier.value &&
          (authState.user!.isBusinessOwner ||
              authState.user!.role == UserRole.manager) &&
          loc != '/trial-expired' &&
          loc != '/subscription' &&
          loc != '/pricing' &&
          !loc.startsWith('/subscribe')) {
        return '/trial-expired';
      }

      // RBAC guard: only SUPER_ADMIN may access /admin/* routes.
      if (loc.startsWith('/admin') &&
          authState.user!.role != UserRole.superAdmin) {
        return _homeRoute(authState.user!.role);
      }

      // Onboarding check: redirect business owners who haven't completed onboarding
      if (authState.user!.isBusinessOwner && loc != '/onboarding') {
        final onboardingCompleted =
            await ref.read(onboardingCompletedProvider.future);
        if (!onboardingCompleted) {
          final tenantId = authState.user!.tenantId ?? '';
          return '/onboarding?tenantId=$tenantId';
        }
      }

      final isCashierHomeRoute =
          loc == '/pos' || loc == '/dashboard/cashier';
      if (authState.user!.isCashier && isCashierHomeRoute) {
        // Attempt to restore any existing open session before deciding where
        // to send the cashier.  Only fetch if we don't already have state.
        if (!sessionState.hasOpenSession && !sessionState.isLoading) {
          await ref.read(sessionProvider.notifier).loadOpenSession();
        }
        // Re-read updated session state after the async fetch above.
        final refreshedSession = ref.read(sessionProvider);
        if (!refreshedSession.hasOpenSession) return '/session/open';
      }

      return null;
    },
    routes: [
      // Full-screen routes (no navigation shell)
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/pricing',
        builder: (_, __) => const PricingScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return ResetPasswordScreen(token: token);
        },
      ),
      GoRoute(
        path: '/subscribe',
        builder: (_, state) {
          final planId = state.uri.queryParameters['plan_id'] ?? '';
          return SubscriptionPurchaseScreen(planId: planId);
        },
      ),
      GoRoute(
        path: '/trial-expired',
        builder: (_, __) => const TrialExpiredScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/pos',
        builder: (_, __) => const PosScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/session/open',
        builder: (_, __) => const OpenSessionScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/session/close',
        builder: (_, __) => const CloseSessionScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/receipt/:orderId',
        builder: (_, state) =>
            ReceiptScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/orders/:orderId',
        builder: (_, state) =>
            OrderDetailScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/onboarding',
        builder: (_, state) {
          final tenantId = state.uri.queryParameters['tenantId'] ?? '';
          return OnboardingWizardScreen(tenantId: tenantId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/procurement/:id',
        builder: (_, state) => ProcurementDetailScreen(
            orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/procurement/receipts',
        builder: (_, state) {
          final poId = state.uri.queryParameters['poId'] ?? '';
          return GoodsReceiptListScreen(poId: poId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/procurement/receipts/:receiptId',
        builder: (_, state) => GoodsReceiptDetailScreen(
          receiptId: state.pathParameters['receiptId']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/procurement/payables',
        builder: (_, __) => const SupplierPayablesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/analytics/export',
        builder: (_, __) => const AnalyticsExportScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/notifications/preferences',
        builder: (_, __) => const NotificationPreferencesScreen(),
      ),

      // Shell routes (with navigation bar)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) =>
            AppShell(child: child),
        routes: [
          // Dashboards
          GoRoute(
            path: '/dashboard/cashier',
            builder: (_, __) => const CashierDashboard(),
          ),
          GoRoute(
            path: '/dashboard/manager',
            builder: (_, __) => const ManagerDashboard(),
          ),
          GoRoute(
            path: '/dashboard/admin',
            builder: (_, __) => const SuperAdminDashboard(),
          ),
          GoRoute(
            path: '/dashboard/reseller',
            builder: (_, __) => const ResellerDashboard(),
          ),
          // Feature routes
          GoRoute(
            path: '/orders',
            builder: (_, __) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (_, __) => const CustomersScreen(),
          ),
          GoRoute(
            path: '/customers/new',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const CustomerFormScreen(),
          ),
          GoRoute(
            path: '/customers/:id',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, state) => CustomerDetailScreen(
              customerId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/customers/:id/ledger',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, state) => CustomerLedgerScreen(
              customerId: state.pathParameters['id']!,
              customerName: state.uri.queryParameters['name'] ?? '',
            ),
          ),
          GoRoute(
            path: '/customers/:id/payments',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, state) {
              final customer = state.extra as CustomerModel?;
              if (customer != null) {
                return CustomerPaymentsScreen(customer: customer);
              }
              return CustomerDetailScreen(customerId: state.pathParameters['id']!);
            },
          ),
          GoRoute(
            path: '/customers/:id/statement',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, state) {
              final customer = state.extra as CustomerModel?;
              if (customer != null) {
                return CustomerStatementScreen(customer: customer);
              }
              return CustomerDetailScreen(customerId: state.pathParameters['id']!);
            },
          ),
          GoRoute(
            path: '/customers/:id/new-sale',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, state) {
              final customer = state.extra as CustomerModel?;
              if (customer != null) {
                return CustomerSaleFormScreen(customer: customer);
              }
              return CustomerDetailScreen(customerId: state.pathParameters['id']!);
            },
          ),
          GoRoute(
            path: '/products',
            builder: (_, __) => const ProductsScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (_, __) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (_, __) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/procurement',
            builder: (_, __) => const ProcurementScreen(),
          ),
          GoRoute(
            path: '/procurement/new',
            builder: (_, state) {
              final supplierId = state.uri.queryParameters['supplier_id'];
              return ProcurementFormScreen(initialSupplierId: supplierId);
            },
          ),
          GoRoute(
            path: '/suppliers',
            builder: (_, __) => const SuppliersScreen(),
          ),
          GoRoute(
            path: '/suppliers/new',
            builder: (_, __) => const SupplierFormScreen(),
          ),
          GoRoute(
            path: '/suppliers/:id',
            builder: (_, state) {
              final supplier = state.extra as SupplierModel?;
              if (supplier != null) {
                return SupplierDetailScreen(supplier: supplier);
              }
              // Fallback: should not happen in normal flow
              return const SuppliersScreen();
            },
          ),
          GoRoute(
            path: '/users',
            builder: (_, __) => const UsersScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/profile',
            builder: (_, __) => const ProfileSettingsScreen(),
          ),
          GoRoute(
            path: '/settings/business',
            builder: (_, __) => const BusinessSettingsScreen(),
          ),
          GoRoute(
            path: '/settings/receipt',
            builder: (_, __) => const ReceiptSettingsScreen(),
          ),
          GoRoute(
            path: '/settings/tax',
            builder: (_, __) => const TaxSettingsScreen(),
          ),
          GoRoute(
            path: '/settings/preferences',
            builder: (_, __) => const PreferencesScreen(),
          ),
          GoRoute(
            path: '/settings/branches',
            builder: (_, state) {
              final tenantId = state.uri.queryParameters['tenantId'] ?? '';
              return BranchesScreen(tenantId: tenantId);
            },
          ),
          GoRoute(
            path: '/settings/branches/new',
            builder: (_, state) {
              final tenantId = state.uri.queryParameters['tenantId'] ?? '';
              return BranchFormScreen(branch: null, tenantId: tenantId);
            },
          ),
          GoRoute(
            path: '/settings/branches/:branchId/edit',
            builder: (_, state) {
              final tenantId = state.uri.queryParameters['tenantId'] ?? '';
              final branch = state.extra as BranchModel?;
              return BranchFormScreen(branch: branch, tenantId: tenantId);
            },
          ),
          // Admin portal
          GoRoute(
            path: '/admin/tenants',
            builder: (_, __) => const TenantsScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (_, __) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/admin/resellers',
            builder: (_, __) => const AdminResellersScreen(),
          ),
          GoRoute(
            path: '/admin/plans',
            builder: (_, __) => const PlansScreen(),
          ),
          GoRoute(
            path: '/admin/subscriptions',
            builder: (_, __) => const AdminSubscriptionsScreen(),
          ),
          GoRoute(
            path: '/admin/devices',
            builder: (_, __) => const DevicesScreen(),
          ),
          GoRoute(
            path: '/admin/audit',
            builder: (_, __) => const AuditScreen(),
          ),
          // Reseller portal
          GoRoute(
            path: '/reseller/dashboard',
            builder: (_, __) => const ResellerDashboardScreen(),
          ),
          GoRoute(
            path: '/reseller/wallet',
            builder: (_, __) => const WalletScreen(),
          ),
          GoRoute(
            path: '/reseller/referrals',
            builder: (_, __) => const ReferralsScreen(),
          ),
          GoRoute(
            path: '/reseller/commissions',
            builder: (_, __) => const CommissionsScreen(),
          ),
          GoRoute(
            path: '/reseller/businesses',
            builder: (_, __) => const ResellerBusinessesScreen(),
          ),
          GoRoute(
            path: '/reseller/analytics',
            builder: (_, __) => const ResellerAnalyticsScreen(),
          ),
          GoRoute(
            path: '/reseller/customers',
            builder: (_, __) => const ResellerCustomersScreen(),
          ),
          GoRoute(
            path: '/reseller/inventory',
            builder: (_, __) => const ResellerInventoryScreen(),
          ),
          GoRoute(
            path: '/reseller/procurement',
            builder: (_, __) => const ResellerProcurementScreen(),
          ),
          GoRoute(
            path: '/reseller/businesses/:id',
            builder: (_, state) {
              final tenantId = state.pathParameters['id'] ?? '';
              return ResellerBusinessDetailScreen(tenantId: tenantId);
            },
          ),
          GoRoute(
            path: '/reseller/businesses/:id/subscription',
            builder: (_, state) {
              final tenantId = state.pathParameters['id'] ?? '';
              return ResellerSubscriptionScreen(tenantId: tenantId);
            },
          ),
          GoRoute(
            path: '/reseller/profile',
            builder: (_, __) => const ResellerProfileScreen(),
          ),
          GoRoute(
            path: '/reseller/notifications',
            builder: (_, __) => const ResellerNotificationsScreen(),
          ),
          GoRoute(
            path: '/reseller/plans',
            builder: (_, __) => const ResellerPlansScreen(),
          ),
          GoRoute(
            path: '/admin/notifications',
            builder: (_, __) => const PlatformNotificationsScreen(),
          ),
          GoRoute(
            path: '/subscription',
            builder: (_, __) => const SubscriptionScreen(),
          ),
          GoRoute(
            path: '/brands',
            builder: (_, __) => const BrandsScreen(),
          ),
          GoRoute(
            path: '/categories',
            builder: (_, __) => const CategoriesScreen(),
          ),
          GoRoute(
            path: '/admin/payment-methods',
            builder: (_, __) => const PaymentMethodsScreen(),
          ),
          GoRoute(
            path: '/admin/businesses/:id',
            builder: (_, state) {
              final tenantId = state.pathParameters['id']!;
              return AdminBusinessDetailScreen(tenantId: tenantId);
            },
          ),
          GoRoute(
            path: '/admin/resellers-detail/:id',
            builder: (_, state) {
              final resellerId = state.pathParameters['id']!;
              return AdminResellerDetailScreen(resellerId: resellerId);
            },
          ),
          GoRoute(
            path: '/admin/reseller-finance',
            builder: (_, __) => const AdminResellerFinanceScreen(),
          ),
          GoRoute(
            path: '/admin/plans/new',
            builder: (_, __) => const AdminPlanFormScreen(planId: null),
          ),
          GoRoute(
            path: '/admin/plans/:id/edit',
            builder: (_, state) {
              final planId = state.pathParameters['id']!;
              return AdminPlanFormScreen(planId: planId);
            },
          ),
          GoRoute(
            path: '/admin/plans/:id',
            builder: (_, state) {
              final planId = state.pathParameters['id']!;
              return AdminPlanDetailScreen(planId: planId);
            },
          ),
          GoRoute(
            path: '/admin/users/:id',
            builder: (_, state) {
              final userId = state.pathParameters['id']!;
              return AdminUserDetailScreen(userId: userId);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

String _homeRoute(String role) {
  switch (role) {
    case UserRole.superAdmin:
      return '/dashboard/admin';
    case UserRole.reseller:
      return '/reseller/dashboard';
    case UserRole.businessOwner:
    case UserRole.manager:
      return '/dashboard/manager';
    case UserRole.cashier:
      return '/dashboard/cashier';
    case UserRole.inventoryStaff:
      return '/inventory';
    default:
      return '/dashboard/manager';
  }
}

class _AuthListenable extends ChangeNotifier {
  final Ref _ref;
  _AuthListenable(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
    _ref.listen(sessionProvider, (_, __) => notifyListeners());
  }
}

// CloseSessionScreen is imported from:
// ../../features/cashier_session/screens/close_session_screen.dart
