import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';

// Model

class NotificationPreferences {
  final bool lowStockAlerts;
  final bool newOrder;
  final bool paymentReceived;
  final bool sessionSummary;
  final bool systemAnnouncements;
  final bool subscriptionAlerts;
  final bool procurementAlerts;
  final bool customerAlerts;
  final bool securityAlerts;

  const NotificationPreferences({
    required this.lowStockAlerts,
    required this.newOrder,
    required this.paymentReceived,
    required this.sessionSummary,
    required this.systemAnnouncements,
    required this.subscriptionAlerts,
    required this.procurementAlerts,
    required this.customerAlerts,
    required this.securityAlerts,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      lowStockAlerts: (json['low_stock_alerts'] ?? json['inventory_enabled']) as bool? ?? true,
      newOrder: json['new_order'] as bool? ?? true,
      paymentReceived: json['payment_received'] as bool? ?? true,
      sessionSummary: json['session_summary'] as bool? ?? true,
      systemAnnouncements: json['system_announcements'] as bool? ?? true,
      subscriptionAlerts: (json['subscription_alerts'] ?? json['subscription_enabled']) as bool? ?? true,
      procurementAlerts: (json['procurement_alerts'] ?? json['procurement_enabled']) as bool? ?? true,
      customerAlerts: (json['customer_alerts'] ?? json['customer_enabled']) as bool? ?? true,
      securityAlerts: (json['security_alerts'] ?? json['security_enabled']) as bool? ?? true,
    );
  }

  NotificationPreferences copyWith({
    bool? lowStockAlerts,
    bool? newOrder,
    bool? paymentReceived,
    bool? sessionSummary,
    bool? systemAnnouncements,
    bool? subscriptionAlerts,
    bool? procurementAlerts,
    bool? customerAlerts,
    bool? securityAlerts,
  }) {
    return NotificationPreferences(
      lowStockAlerts: lowStockAlerts ?? this.lowStockAlerts,
      newOrder: newOrder ?? this.newOrder,
      paymentReceived: paymentReceived ?? this.paymentReceived,
      sessionSummary: sessionSummary ?? this.sessionSummary,
      systemAnnouncements: systemAnnouncements ?? this.systemAnnouncements,
      subscriptionAlerts: subscriptionAlerts ?? this.subscriptionAlerts,
      procurementAlerts: procurementAlerts ?? this.procurementAlerts,
      customerAlerts: customerAlerts ?? this.customerAlerts,
      securityAlerts: securityAlerts ?? this.securityAlerts,
    );
  }
}

// State

class _PrefsState {
  final NotificationPreferences? prefs;
  final bool isLoading;
  final String? error;
  final bool isSaving;
  final bool savedOk;

  const _PrefsState({
    this.prefs,
    this.isLoading = false,
    this.error,
    this.isSaving = false,
    this.savedOk = false,
  });

  _PrefsState copyWith({
    NotificationPreferences? prefs,
    bool? isLoading,
    String? error,
    bool? isSaving,
    bool? savedOk,
    bool clearError = false,
  }) {
    return _PrefsState(
      prefs: prefs ?? this.prefs,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSaving: isSaving ?? this.isSaving,
      savedOk: savedOk ?? this.savedOk,
    );
  }
}

// Notifier

class _PrefsNotifier extends StateNotifier<_PrefsState> {
  _PrefsNotifier() : super(const _PrefsState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response =
          await apiClient.dio.get(ApiEndpoints.notificationPreferences);
      final prefs = NotificationPreferences.fromJson(
          response.data as Map<String, dynamic>);
      state = state.copyWith(prefs: prefs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggle(Map<String, dynamic> patch) async {
    if (state.prefs == null) return;
    state = state.copyWith(isSaving: true, savedOk: false, clearError: true);
    try {
      final response = await apiClient.dio
          .patch(ApiEndpoints.notificationPreferences, data: patch);
      final updated = NotificationPreferences.fromJson(
          response.data as Map<String, dynamic>);
      state = state.copyWith(prefs: updated, isSaving: false, savedOk: true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) state = state.copyWith(savedOk: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }
}

final _prefsProvider =
    StateNotifierProvider.autoDispose<_PrefsNotifier, _PrefsState>(
        (_) => _PrefsNotifier());

// Screen

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(_prefsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_prefsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Notification Preferences',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (state.isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else if (state.savedOk)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Icon(Icons.check_circle,
                    color: AppColors.success, size: 20),
              ),
            ),
        ],
      ),
      body: state.isLoading
          ? const _PrefsShimmer()
          : state.error != null && state.prefs == null
              ? ErrorView(
                  message: state.error!,
                  onRetry: () => ref.read(_prefsProvider.notifier).load(),
                )
              : state.prefs == null
                  ? const SizedBox.shrink()
                  : _PrefsBody(prefs: state.prefs!),
    );
  }
}

// Body

class _PrefsBody extends ConsumerWidget {
  final NotificationPreferences prefs;

  const _PrefsBody({required this.prefs});

  void _patch(WidgetRef ref, Map<String, dynamic> data) {
    ref.read(_prefsProvider.notifier).toggle(data);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        _SectionHeader(label: 'SALES'),
        _PrefTile(
          title: 'New Order',
          subtitle: 'Get notified when a new sale order is placed',
          value: prefs.newOrder,
          onChanged: (v) => _patch(ref, {'new_order': v}),
        ),
        _Divider(),
        _PrefTile(
          title: 'Payment Received',
          subtitle: 'Alerts when a payment is successfully collected',
          value: prefs.paymentReceived,
          onChanged: (v) => _patch(ref, {'payment_received': v}),
        ),
        _SectionHeader(label: 'INVENTORY'),
        _PrefTile(
          title: 'Low Stock Alerts',
          subtitle: 'Notify when a product drops below its reorder threshold',
          value: prefs.lowStockAlerts,
          onChanged: (v) => _patch(ref, {'low_stock_alerts': v}),
        ),
        _SectionHeader(label: 'PROCUREMENT'),
        _PrefTile(
          title: 'Procurement Alerts',
          subtitle: 'Purchase orders, goods receipts, and payable updates',
          value: prefs.procurementAlerts,
          onChanged: (v) => _patch(ref, {'procurement_alerts': v}),
        ),
        _SectionHeader(label: 'CUSTOMERS'),
        _PrefTile(
          title: 'Customer Alerts',
          subtitle: 'New customers, credit changes, and overdue balances',
          value: prefs.customerAlerts,
          onChanged: (v) => _patch(ref, {'customer_alerts': v}),
        ),
        _SectionHeader(label: 'SESSIONS'),
        _PrefTile(
          title: 'Session Summary',
          subtitle: 'Receive a daily summary when a cashier session is closed',
          value: prefs.sessionSummary,
          onChanged: (v) => _patch(ref, {'session_summary': v}),
        ),
        _SectionHeader(label: 'SYSTEM'),
        _PrefTile(
          title: 'System Announcements',
          subtitle: 'Platform updates, maintenance notices, and changelogs',
          value: prefs.systemAnnouncements,
          onChanged: (v) => _patch(ref, {'system_announcements': v}),
        ),
        _Divider(),
        _PrefTile(
          title: 'Subscription Alerts',
          subtitle: 'Reminders for trial expiry, renewals, and plan changes',
          value: prefs.subscriptionAlerts,
          onChanged: (v) => _patch(ref, {'subscription_alerts': v}),
        ),
        _Divider(),
        _PrefTile(
          title: 'Security Alerts',
          subtitle: 'Login from new device, password changes, and access events',
          value: prefs.securityAlerts,
          onChanged: (v) => _patch(ref, {'security_alerts': v}),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// Section Header

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// Divider

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.divider,
    );
  }
}

// Pref Tile

class _PrefTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primaryFg,
        activeTrackColor: AppColors.primary,
        inactiveThumbColor: AppColors.textSecondary,
        inactiveTrackColor: AppColors.surfaceVariant,
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.divider;
        }),
      ),
    );
  }
}

// Shimmer

class _PrefsShimmer extends StatelessWidget {
  const _PrefsShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.divider,
      child: ListView(
        children: [
          _shimmerHeader(),
          _shimmerTile(),
          _shimmerTile(),
          _shimmerHeader(),
          _shimmerTile(),
          _shimmerHeader(),
          _shimmerTile(),
          _shimmerHeader(),
          _shimmerTile(),
          _shimmerTile(),
        ],
      ),
    );
  }

  Widget _shimmerHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      height: 12,
      width: 80,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _shimmerTile() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 11,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}
