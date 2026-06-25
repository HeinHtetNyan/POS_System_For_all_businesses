import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../data/reseller_repository.dart';
import '../providers/reseller_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/reseller_wallet_model.dart';

// Providers

final _referralCodesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(resellerRepositoryProvider).getReferralCodes();
});

// Screen

class ReferralsScreen extends ConsumerStatefulWidget {
  const ReferralsScreen({super.key});

  @override
  ConsumerState<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends ConsumerState<ReferralsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(resellerReferralsProvider.notifier).load());
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(resellerReferralsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resellerReferralsProvider);
    final codesAsync = ref.watch(_referralCodesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'My Clients',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () {
          ref.invalidate(_referralCodesProvider);
          return ref
              .read(resellerReferralsProvider.notifier)
              .load(refresh: true);
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Referral code card
            codesAsync.when(
              loading: () => const SizedBox(height: 80),
              error: (_, __) => const SizedBox.shrink(),
              data: (codes) {
                final active = codes.firstWhere(
                  (c) => c['is_active'] == true,
                  orElse: () => codes.isNotEmpty ? codes.first : {},
                );
                if (active.isEmpty) return _NoCodeCard();
                return _ReferralCodeCard(code: active);
              },
            ),
            const SizedBox(height: 16),

            // Clients list
            if (state.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (state.error != null)
              ErrorView(
                message: state.error!,
                onRetry: () =>
                    ref.read(resellerReferralsProvider.notifier).load(refresh: true),
              )
            else if (state.items.isEmpty)
              const EmptyView(
                icon: Icons.business_outlined,
                title: 'No clients yet',
                subtitle: 'Share your referral code to onboard clients',
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'CLIENTS (${state.items.length})',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              ...List.generate(
                state.items.length + (state.isLoadingMore ? 1 : 0),
                (i) {
                  if (i >= state.items.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    );
                  }
                  return _ReferralCard(referral: state.items[i]);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Referral code card

class _NoCodeCard extends ConsumerStatefulWidget {
  const _NoCodeCard();

  @override
  ConsumerState<_NoCodeCard> createState() => _NoCodeCardState();
}

class _NoCodeCardState extends ConsumerState<_NoCodeCard> {
  bool _loading = false;

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      await ref.read(resellerRepositoryProvider).generateReferralCode();
      ref.invalidate(_referralCodesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.link_outlined, color: AppColors.textDisabled, size: 32),
          const SizedBox(height: 12),
          const Text('No referral code yet', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Create your unique referral code to start earning commissions', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryFg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _loading ? null : _generate,
              icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryFg))
                : const Icon(Icons.add_link, size: 18),
              label: Text(_loading ? 'Generating...' : 'Generate Referral Code', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralCodeCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> code;

  const _ReferralCodeCard({required this.code});

  @override
  ConsumerState<_ReferralCodeCard> createState() => _ReferralCodeCardState();
}

class _ReferralCodeCardState extends ConsumerState<_ReferralCodeCard> {
  bool _linkVisible = false;
  bool _loadingLink = false;
  String? _link;
  bool _linkFetched = false;

  Future<void> _fetchAndShowLink() async {
    if (_linkFetched) {
      setState(() => _linkVisible = !_linkVisible);
      return;
    }

    setState(() {
      _loadingLink = true;
      _linkVisible = true;
    });

    final codeId = widget.code['id'] as String? ?? '';
    final url =
        await ref.read(resellerRepositoryProvider).getReferralCodeLink(codeId);

    if (mounted) {
      setState(() {
        _link = url;
        _loadingLink = false;
        _linkFetched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeStr = widget.code['code'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header label
          Row(
            children: [
              const Icon(Icons.discount_outlined,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              const Text(
                'YOUR REFERRAL CODE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Code + copy button
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    codeStr,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CopyButton(text: codeStr),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Share this code with businesses to earn commissions when they subscribe.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 12),

          // Show Link button
          GestureDetector(
            onTap: _loadingLink ? null : _fetchAndShowLink,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_loadingLink)
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.8, color: AppColors.primary),
                    )
                  else
                    Icon(
                      _linkVisible
                          ? Icons.link_off_outlined
                          : Icons.link_outlined,
                      color: AppColors.primary,
                      size: 14,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    _loadingLink
                        ? 'Fetching link…'
                        : (_linkVisible ? 'Hide Link' : 'Show Link'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Link section (revealed)
          if (_linkVisible) ...[
            const SizedBox(height: 10),
            _LinkDisplaySection(link: _loadingLink ? null : _link),
          ],
        ],
      ),
    );
  }
}

// Link display section

class _LinkDisplaySection extends StatelessWidget {
  final String? link;

  const _LinkDisplaySection({required this.link});

  @override
  Widget build(BuildContext context) {
    final hasLink = link != null && link!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.open_in_new_outlined,
                  color: AppColors.textSecondary, size: 12),
              SizedBox(width: 5),
              Text(
                'REGISTRATION LINK',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: hasLink
                      ? SelectableText(
                          link!,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            height: 1.45,
                          ),
                        )
                      : const Text(
                          'Link not available',
                          style: TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                ),
              ),
              if (hasLink) ...[
                const SizedBox(width: 8),
                _CopyButton(text: link!, small: true),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// Copy button

class _CopyButton extends StatefulWidget {
  final String text;
  final bool small;
  const _CopyButton({required this.text, this.small = false});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.small
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    final iconSize = widget.small ? 16.0 : 20.0;

    return GestureDetector(
      onTap: _copy,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: padding,
        decoration: BoxDecoration(
          color: _copied ? AppColors.success : AppColors.primary,
          borderRadius: BorderRadius.circular(widget.small ? 7 : 10),
        ),
        child: Icon(
          _copied ? Icons.check : Icons.copy_outlined,
          color: _copied ? Colors.white : AppColors.primaryFg,
          size: iconSize,
        ),
      ),
    );
  }
}

// Referral card

class _ReferralCard extends ConsumerWidget {
  final ReferralModel referral;
  const _ReferralCard({required this.referral});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showManageSheet(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                radius: 22,
                child: Text(
                  referral.businessName.isNotEmpty
                      ? referral.businessName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      referral.businessName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StatusBadge(status: referral.status),
                        const SizedBox(width: 6),
                        StatusBadge(
                          status: referral.subscriptionStatus,
                          label: referral.subscriptionStatus,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(referral.totalCommissionsEarned),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.success,
                    ),
                  ),
                  const Text(
                    'earned',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showManageSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ManageBusinessSheet(referral: referral),
    );
  }
}

// Manage business sheet with proof upload

class _ManageBusinessSheet extends ConsumerStatefulWidget {
  final ReferralModel referral;

  const _ManageBusinessSheet({required this.referral});

  @override
  ConsumerState<_ManageBusinessSheet> createState() =>
      _ManageBusinessSheetState();
}

class _ManageBusinessSheetState
    extends ConsumerState<_ManageBusinessSheet> {
  Map<String, dynamic>? _latestProof;
  bool _loadingProof = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadProof();
  }

  Future<void> _loadProof() async {
    setState(() => _loadingProof = true);
    final proof = await ref
        .read(resellerRepositoryProvider)
        .getTenantLatestProof(widget.referral.id);
    if (mounted) {
      setState(() {
        _latestProof = proof;
        _loadingProof = false;
      });
    }
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      await ref
          .read(resellerRepositoryProvider)
          .uploadTenantPaymentProof(
              widget.referral.id, File(picked.path), 'UPGRADE');
      await _loadProof();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment proof uploaded successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final proofStatus =
        _latestProof?['status'] as String?;
    final proofDate =
        _latestProof?['created_at'] as String?;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.12),
                  radius: 18,
                  child: Text(
                    widget.referral.businessName.isNotEmpty
                        ? widget.referral.businessName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.referral.businessName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          StatusBadge(
                              status: widget.referral.subscriptionStatus),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commissions row
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on_outlined,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Commissions earned:',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        CurrencyFormatter.format(
                            widget.referral.totalCommissionsEarned),
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Payment proof section
                const Text(
                  'PAYMENT PROOF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),

                if (_loadingProof)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    ),
                  )
                else if (_latestProof != null) ...[
                  _ProofStatusCard(
                    status: proofStatus ?? 'PENDING',
                    date: proofDate,
                    reviewNotes: _latestProof?['review_notes'] as String?,
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            color: AppColors.textDisabled, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'No payment proof submitted yet',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Upload button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _uploading ? null : _pickAndUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryFg,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryFg),
                          )
                        : const Icon(Icons.upload_outlined, size: 18),
                    label: Text(
                      _uploading
                          ? 'Uploading…'
                          : (_latestProof != null
                              ? 'Upload New Proof'
                              : 'Upload Payment Proof'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
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

// Proof status card

class _ProofStatusCard extends StatelessWidget {
  final String status;
  final String? date;
  final String? reviewNotes;

  const _ProofStatusCard(
      {required this.status, this.date, this.reviewNotes});

  (Color, Color, IconData) get _meta {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return (AppColors.successLight, AppColors.success,
            Icons.check_circle_outline);
      case 'REJECTED':
        return (AppColors.errorLight, AppColors.error, Icons.cancel_outlined);
      default:
        return (AppColors.warningLight, AppColors.warning,
            Icons.hourglass_empty_outlined);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = _meta;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 16),
              const SizedBox(width: 6),
              Text(
                status,
                style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
              if (date != null) ...[
                const Spacer(),
                Text(
                  date!.length > 10 ? date!.substring(0, 10) : date!,
                  style: TextStyle(color: fg.withValues(alpha: 0.7),
                      fontSize: 11),
                ),
              ],
            ],
          ),
          if (reviewNotes != null && reviewNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reviewNotes!,
              style: TextStyle(
                  color: fg.withValues(alpha: 0.8), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
