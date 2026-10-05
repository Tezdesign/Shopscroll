import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/models/seller_application.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';

import '../../data/providers/seller_application_providers.dart';
import '../../data/providers/user_profile_providers.dart';
import '../activity/list_states.dart';
import '../checkout/checkout_header.dart';
import 'seller_application_logic.dart';

/// Settings, Seller application (spec 0013, AC-8). Reproduces Figma nodes
/// 3001:9520 (empty state) and 3001:9544 (the list with a status chip).
///
/// [userId] is the signed in person, used to read their profile role: only a
/// buyer is offered "Submit a new application", a seller sees a note instead.
/// Null when sign in is not configured, which counts as a buyer.
///
/// Deviations from the Figma frames: the "Got more than one shop ?" heading
/// above the button is left out, because one account has one store for now
/// (the spec's Consequences), so the button only appears when a person has
/// no application under review. The device status bar and the tab bar are
/// drawn by the phone and the app shell. The empty state's second line starts
/// with a capital letter.
class SellerApplicationScreen extends ConsumerWidget {
  const SellerApplicationScreen({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications = ref.watch(sellerApplicationsProvider);
    final id = userId;
    final role = id == null
        ? null
        : ref.watch(userProfileByIdProvider(id)).value?.role;

    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: SafeArea(
        child: Column(
          children: [
            CheckoutHeader(
              title: 'Seller application',
              onClose: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
            ),
            Expanded(
              child: applications.when(
                loading: () => const ListLoading(),
                error: (error, stackTrace) => ListMessage(
                  "Couldn't load your applications.",
                  buttonLabel: 'Try again',
                  onPressed: () => ref.invalidate(sellerApplicationsProvider),
                ),
                data: (list) => RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(sellerApplicationsProvider.future),
                  child: _Body(applications: list, role: role),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.applications, required this.role});

  final List<SellerApplication> applications;
  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    final canSubmit = canSubmitNewApplication(applications, role);
    final isSeller = role == UserRole.seller;

    final submitButton = SizedBox(
      width: double.infinity,
      child: AppButton(
        label: applications.isEmpty
            ? 'Submit an application'
            : 'Submit a new application',
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.small,
        onPressed: () => context.push('/profile/seller-application/new'),
      ),
    );

    // Always scrollable, even when short, so pull to refresh works on the
    // empty state too.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: applications.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _EmptyMessage(),
                      const SizedBox(height: AppSpacing.xl),
                      if (isSeller) const _SellerNote() else submitButton,
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base,
                    AppSpacing.base,
                    AppSpacing.base,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final application in applications)
                        _ApplicationRow(application: application),
                      if (isSeller) ...[
                        const SizedBox(height: AppSpacing.base),
                        const _SellerNote(),
                      ] else if (canSubmit) ...[
                        const SizedBox(height: AppSpacing.xl),
                        submitButton,
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Figma 3001:9540 and 3001:9541: Inter semibold 20 black, then 16 in
        // neutral 500, centred in a 243 wide column.
        const Text(
          'No applications yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeXl,
            height: AppTypography.lineHeightXl,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral1100,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 243),
          child: const Text(
            "You haven't submitted an application yet",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontFamilyBody,
              fontSize: AppTypography.sizeBase,
              height: AppTypography.lineHeightBase,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral500,
            ),
          ),
        ),
      ],
    );
  }
}

class _SellerNote extends StatelessWidget {
  const _SellerNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'You are a seller. Your store was set up from your approved application.',
      textAlign: TextAlign.center,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral700),
    );
  }
}

/// One application: store name and submit date on the left, the status chip
/// on the right (Figma 3001:9562), with the reason under a rejected one.
class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({required this.application});

  final SellerApplication application;

  @override
  Widget build(BuildContext context) {
    final reason = application.rejectionReason;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.storeName,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamilyDisplay,
                        fontSize: AppTypography.sizeBase,
                        height: AppTypography.lineHeightBase,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral1100,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      submittedLabel(application.createdAt),
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamilyBody,
                        fontSize: AppTypography.sizeSm,
                        height: AppTypography.lineHeightSm,
                        fontWeight: FontWeight.w500,
                        color: AppColors.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              _StatusChip(status: application.status),
            ],
          ),
          if (application.status == SellerApplicationStatus.rejected &&
              reason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Reason: $reason',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.neutral700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The Figma "Order-satus" pill (node 3001:9566), the same one
/// `OrderStatusBadge` draws, with this feature's three states.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SellerApplicationStatus status;

  // Figma tracks this label at 0.28, no shared token exists (see
  // OrderStatusBadge).
  static const double _letterSpacing = 0.28;

  ({Color background, Color text, String label}) get _spec => switch (status) {
    SellerApplicationStatus.reviewing => (
      background: AppColors.warning100,
      text: AppColors.warning400,
      label: 'Reviewing',
    ),
    SellerApplicationStatus.approved => (
      background: AppColors.successAlpha10,
      text: AppColors.success400,
      label: 'Approved',
    ),
    SellerApplicationStatus.rejected => (
      background: AppColors.error100,
      text: AppColors.error400,
      label: 'Rejected',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: spec.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        spec.label,
        maxLines: 1,
        style: TextStyle(
          fontFamily: AppTypography.fontFamilyBody,
          fontSize: AppTypography.sizeSm,
          height: AppTypography.lineHeightSm,
          fontWeight: FontWeight.w600,
          letterSpacing: _letterSpacing,
          color: spec.text,
        ),
      ),
    );
  }
}
