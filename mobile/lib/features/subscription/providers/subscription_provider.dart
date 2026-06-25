import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../data/subscription_repository.dart';

class SubscriptionState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? statusData;
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> billingHistory;
  final List<Map<String, dynamic>> paymentProofs;
  final bool proofsLoading;
  final int tab;

  const SubscriptionState({
    this.isLoading = false,
    this.error,
    this.statusData,
    this.plans = const [],
    this.billingHistory = const [],
    this.paymentProofs = const [],
    this.proofsLoading = false,
    this.tab = 0,
  });

  SubscriptionState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? statusData,
    List<Map<String, dynamic>>? plans,
    List<Map<String, dynamic>>? billingHistory,
    List<Map<String, dynamic>>? paymentProofs,
    bool? proofsLoading,
    int? tab,
    bool clearError = false,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      statusData: statusData ?? this.statusData,
      plans: plans ?? this.plans,
      billingHistory: billingHistory ?? this.billingHistory,
      paymentProofs: paymentProofs ?? this.paymentProofs,
      proofsLoading: proofsLoading ?? this.proofsLoading,
      tab: tab ?? this.tab,
    );
  }
}

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() => const SubscriptionState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final results = await Future.wait([
        repo.getStatus(),
        repo.getPlans(),
      ]);

      state = state.copyWith(
        isLoading: false,
        statusData: results[0] as Map<String, dynamic>,
        plans: results[1] as List<Map<String, dynamic>>,
      );
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadBillingHistory() async {
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final history = await repo.getBillingHistory();
      state = state.copyWith(billingHistory: history);
    } on AppException catch (e) {
      state = state.copyWith(error: e.message);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadPaymentProofs() async {
    state = state.copyWith(proofsLoading: true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final proofs = await repo.getPaymentProofs();
      state = state.copyWith(paymentProofs: proofs, proofsLoading: false);
    } catch (e) {
      state = state.copyWith(proofsLoading: false, error: e.toString());
    }
  }

  void setTab(int tab) {
    state = state.copyWith(tab: tab);
    if (tab == 1 && state.paymentProofs.isEmpty) {
      loadPaymentProofs();
    }
    if (tab == 2 && state.billingHistory.isEmpty) {
      loadBillingHistory();
    }
  }

  // H-38: downgrade notifier method
  Future<void> requestDowngrade(String planId) async {
    try {
      await ref.read(subscriptionRepositoryProvider).requestDowngrade(planId);
      await load();
    } on AppException catch (e) {
      state = state.copyWith(error: e.message);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
        SubscriptionNotifier.new);
