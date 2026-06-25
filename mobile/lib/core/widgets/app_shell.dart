import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../../features/notifications/providers/notifications_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final isWide = Responsive.isWide(context);

    if (user == null) return widget.child;

    final navItems = _navItems(user.role);

    if (isWide) {
      // Tablet / desktop: persistent sidebar
      return Scaffold(
        key: _scaffoldKey,
        body: Row(
          children: [
            SizedBox(
              width: 224,
              child: _Sidebar(
                navItems: navItems,
                user: user,
                location: location,
                unreadCount: unreadCount,
                onLogout: () => ref.read(authProvider.notifier).logout(),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    // Phone: hamburger + drawer
    return Scaffold(
      key: _scaffoldKey,
      appBar: _AppTopBar(
        onMenuTap: _openDrawer,
        user: user,
        unreadCount: unreadCount,
        location: location,
        navItems: navItems,
      ),
      drawer: Drawer(
        width: 260,
        backgroundColor: AppColors.surface,
        child: _Sidebar(
          navItems: navItems,
          user: user,
          location: location,
          unreadCount: unreadCount,
          onClose: () => Navigator.of(context).pop(),
          onLogout: () {
            Navigator.of(context).pop();
            ref.read(authProvider.notifier).logout();
          },
        ),
      ),
      body: widget.child,
    );
  }
}

// Top app bar (phone only)

class _AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenuTap;
  final UserModel user;
  final int unreadCount;
  final String location;
  final List<_NavItem> navItems;

  const _AppTopBar({
    required this.onMenuTap,
    required this.user,
    required this.unreadCount,
    required this.location,
    required this.navItems,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final current = navItems.where((i) => location == i.path ||
        (i.path != '/' && location.startsWith(i.path))).firstOrNull;
    final title = current?.label ?? 'SawYunTech POS';

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, size: 22),
        onPressed: onMenuTap,
        tooltip: 'Menu',
      ),
      title: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text('S',
                  style: TextStyle(
                      color: AppColors.primaryFg,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
      actions: [
        if (unreadCount > 0)
          IconButton(
            icon: Badge(
              label: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(fontSize: 9, color: AppColors.background),
              ),
              backgroundColor: AppColors.error,
              child: const Icon(Icons.notifications_outlined, size: 22),
            ),
            onPressed: () => context.push('/notifications'),
          )
        else
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () => context.push('/notifications'),
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// Sidebar

class _Sidebar extends StatelessWidget {
  final List<_NavItem> navItems;
  final UserModel user;
  final String location;
  final int unreadCount;
  final VoidCallback onLogout;
  final VoidCallback? onClose;

  const _Sidebar({
    required this.navItems,
    required this.user,
    required this.location,
    required this.unreadCount,
    required this.onLogout,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('S',
                        style: TextStyle(
                            color: AppColors.primaryFg,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SawYunTech POS',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(
                      UserRole.displayName(user.role),
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
                if (onClose != null) ...[
                  const Spacer(),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 16,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              children: navItems.map((item) {
                final isActive = location == item.path ||
                    (item.path != '/' && location.startsWith(item.path));
                final isNotif = item.path == '/notifications';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _NavTile(
                    item: item,
                    isActive: isActive,
                    badge: isNotif && unreadCount > 0
                        ? (unreadCount > 9 ? '9+' : '$unreadCount')
                        : null,
                    onTap: () {
                      onClose?.call();
                      context.go(item.path);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // User footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              children: [
                // User info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text(
                            user.firstName.isNotEmpty
                                ? user.firstName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user.email,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Sign out
                InkWell(
                  onTap: onLogout,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 15,
                            color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Sign Out',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.error)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Nav tile

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final String? badge;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? item.selectedIcon : item.icon,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(badge!,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.background)),
              ),
          ],
        ),
      ),
    );
  }
}

// Nav item model

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });
}

List<_NavItem> _navItems(String role) {
  switch (role) {
    case UserRole.superAdmin:
      return const [
        _NavItem(label: 'Dashboard',    icon: Icons.space_dashboard_outlined,  selectedIcon: Icons.space_dashboard,  path: '/dashboard/admin'),
        _NavItem(label: 'Businesses',   icon: Icons.business_outlined,          selectedIcon: Icons.business,          path: '/admin/tenants'),
        _NavItem(label: 'Users',        icon: Icons.people_outline,             selectedIcon: Icons.people,            path: '/admin/users'),
        _NavItem(label: 'Resellers',    icon: Icons.handshake_outlined,         selectedIcon: Icons.handshake,         path: '/admin/resellers'),
        _NavItem(label: 'Res. Finance', icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet, path: '/admin/reseller-finance'),
        _NavItem(label: 'Plans',        icon: Icons.credit_card_outlined,       selectedIcon: Icons.credit_card,       path: '/admin/plans'),
        _NavItem(label: 'Subscriptions',icon: Icons.subscriptions_outlined,     selectedIcon: Icons.subscriptions,     path: '/admin/subscriptions'),
        _NavItem(label: 'Devices',         icon: Icons.devices_outlined,           selectedIcon: Icons.devices,           path: '/admin/devices'),
        _NavItem(label: 'Audit Logs',      icon: Icons.history_outlined,           selectedIcon: Icons.history,           path: '/admin/audit'),
        _NavItem(label: 'Notifs',          icon: Icons.campaign_outlined,          selectedIcon: Icons.campaign,          path: '/admin/notifications'),
        _NavItem(label: 'Payment Methods', icon: Icons.payment_outlined,           selectedIcon: Icons.payment,           path: '/admin/payment-methods'),
        _NavItem(label: 'Notifications',   icon: Icons.notifications_outlined,     selectedIcon: Icons.notifications,     path: '/notifications'),
        _NavItem(label: 'Settings',        icon: Icons.settings_outlined,          selectedIcon: Icons.settings,          path: '/settings'),
      ];
    case UserRole.reseller:
      return const [
        _NavItem(label: 'Dashboard',    icon: Icons.space_dashboard_outlined,        selectedIcon: Icons.space_dashboard,       path: '/reseller/dashboard'),
        _NavItem(label: 'Businesses',   icon: Icons.business_outlined,               selectedIcon: Icons.business,              path: '/reseller/businesses'),
        _NavItem(label: 'Analytics',    icon: Icons.bar_chart_rounded,               selectedIcon: Icons.bar_chart_rounded,     path: '/reseller/analytics'),
        _NavItem(label: 'Plans',        icon: Icons.card_membership_outlined,        selectedIcon: Icons.card_membership,       path: '/reseller/plans'),
        _NavItem(label: 'Customers',    icon: Icons.people_outline,                  selectedIcon: Icons.people,                path: '/reseller/customers'),
        _NavItem(label: 'Inventory',    icon: Icons.inventory_2_outlined,            selectedIcon: Icons.inventory_2,           path: '/reseller/inventory'),
        _NavItem(label: 'Procurement',  icon: Icons.shopping_cart_outlined,          selectedIcon: Icons.shopping_cart,         path: '/reseller/procurement'),
        _NavItem(label: 'Commissions',  icon: Icons.payments_outlined,               selectedIcon: Icons.payments,              path: '/reseller/commissions'),
        _NavItem(label: 'Wallet',       icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet, path: '/reseller/wallet'),
        _NavItem(label: 'Profile',      icon: Icons.person_outlined,                 selectedIcon: Icons.person,                path: '/reseller/profile'),
        _NavItem(label: 'Notifications',icon: Icons.notifications_outlined,          selectedIcon: Icons.notifications,         path: '/reseller/notifications'),
        _NavItem(label: 'Settings',     icon: Icons.settings_outlined,               selectedIcon: Icons.settings,              path: '/settings'),
      ];
    case UserRole.inventoryStaff:
      return const [
        _NavItem(label: 'Inventory',    icon: Icons.warehouse_outlined,         selectedIcon: Icons.warehouse,         path: '/inventory'),
        _NavItem(label: 'Products',     icon: Icons.inventory_2_outlined,       selectedIcon: Icons.inventory_2,       path: '/products'),
        _NavItem(label: 'Brands',       icon: Icons.label_outline,              selectedIcon: Icons.label,             path: '/brands'),
        _NavItem(label: 'Categories',   icon: Icons.category_outlined,          selectedIcon: Icons.category,          path: '/categories'),
        _NavItem(label: 'Procurement',  icon: Icons.local_shipping_outlined,    selectedIcon: Icons.local_shipping,    path: '/procurement'),
        _NavItem(label: 'Notifications',icon: Icons.notifications_outlined,     selectedIcon: Icons.notifications,     path: '/notifications'),
        _NavItem(label: 'Settings',     icon: Icons.settings_outlined,          selectedIcon: Icons.settings,          path: '/settings'),
      ];
    case UserRole.cashier:
      return const [
        _NavItem(label: 'Dashboard',    icon: Icons.space_dashboard_outlined,   selectedIcon: Icons.space_dashboard,       path: '/dashboard/cashier'),
        _NavItem(label: 'Checkout',     icon: Icons.point_of_sale_rounded,      selectedIcon: Icons.point_of_sale_rounded, path: '/pos'),
        _NavItem(label: 'Orders',       icon: Icons.receipt_long_outlined,      selectedIcon: Icons.receipt_long,          path: '/orders'),
        _NavItem(label: 'Products',     icon: Icons.inventory_2_outlined,       selectedIcon: Icons.inventory_2,           path: '/products'),
        _NavItem(label: 'Customers',    icon: Icons.people_outline,             selectedIcon: Icons.people,                path: '/customers'),
        _NavItem(label: 'Notifications',icon: Icons.notifications_outlined,     selectedIcon: Icons.notifications,         path: '/notifications'),
        _NavItem(label: 'Settings',     icon: Icons.settings_outlined,          selectedIcon: Icons.settings,              path: '/settings'),
      ];
    case UserRole.businessOwner:
    case UserRole.manager:
    default:
      return const [
        _NavItem(label: 'Dashboard',    icon: Icons.space_dashboard_outlined,   selectedIcon: Icons.space_dashboard,       path: '/dashboard/manager'),
        _NavItem(label: 'Checkout',     icon: Icons.point_of_sale_rounded,      selectedIcon: Icons.point_of_sale_rounded, path: '/pos'),
        _NavItem(label: 'Orders',       icon: Icons.receipt_long_outlined,      selectedIcon: Icons.receipt_long,          path: '/orders'),
        _NavItem(label: 'Products',     icon: Icons.inventory_2_outlined,       selectedIcon: Icons.inventory_2,           path: '/products'),
        _NavItem(label: 'Brands',       icon: Icons.label_outline,              selectedIcon: Icons.label,                 path: '/brands'),
        _NavItem(label: 'Categories',   icon: Icons.category_outlined,          selectedIcon: Icons.category,              path: '/categories'),
        _NavItem(label: 'Inventory',    icon: Icons.warehouse_outlined,         selectedIcon: Icons.warehouse,             path: '/inventory'),
        _NavItem(label: 'Customers',    icon: Icons.people_outline,             selectedIcon: Icons.people,                path: '/customers'),
        _NavItem(label: 'Procurement',  icon: Icons.local_shipping_outlined,    selectedIcon: Icons.local_shipping,        path: '/procurement'),
        _NavItem(label: 'Suppliers',    icon: Icons.business_center_outlined,   selectedIcon: Icons.business_center,       path: '/suppliers'),
        _NavItem(label: 'Analytics',    icon: Icons.bar_chart_rounded,          selectedIcon: Icons.bar_chart_rounded,     path: '/analytics'),
        _NavItem(label: 'Users',        icon: Icons.manage_accounts_outlined,   selectedIcon: Icons.manage_accounts,       path: '/users'),
        _NavItem(label: 'Subscription', icon: Icons.card_membership_outlined,   selectedIcon: Icons.card_membership,       path: '/subscription'),
        _NavItem(label: 'Notifications',icon: Icons.notifications_outlined,     selectedIcon: Icons.notifications,         path: '/notifications'),
        _NavItem(label: 'Settings',     icon: Icons.settings_outlined,          selectedIcon: Icons.settings,              path: '/settings'),
      ];
  }
}
