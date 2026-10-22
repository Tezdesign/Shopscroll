import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';

import '../../core/area/app_area.dart';
import '../../data/models/store_order.dart';
import '../../data/models/store_report.dart';
import '../../data/providers/store_activity_providers.dart';
import '../../data/providers/user_profile_providers.dart';
import 'seller_gate.dart';

/// The seller's home dashboard at `/store` (spec 0014, AC-5).
///
/// Figma node: Home-seller 3001:12309. Deviations:
/// - The status bar is not drawn. The bottom tab bar is the store shell's
///   (`AppShell` with the seller variant, feature 30), not this screen's. The
///   Buyer | Seller switch is in the Profile tab, as in the buyer area, so the
///   header has no switch (the frame draws none).
/// - "Out of stock" KPI tile removed: no dedicated count endpoint exists; the
///   Products screen at `/store/products` shows the Out of Stock tab.
/// - "Last chats" replaced with a Quick Actions row: the Messages feature has
///   no spec yet.
/// - "This Week" tile shows [StoreEarnings.weekChangePercent] as a delta chip
///   vs the same span last week.
class StoreAreaScreen extends ConsumerWidget {
  const StoreAreaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SellerGate(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.neutral100,
          floatingActionButton: _AddFab(
            onPressed: () => context.push('/store/products/new'),
          ),
          body: Column(
            children: [
              _DashHeader(),
              Expanded(child: _DashBody()),
            ],
          ),
        ),
      ),
    );
  }
}

const _tapSize = 44.0;

// ── Header ───────────────────────────────────────────────────────────────────

class _DashHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(signedInUserIdProvider);
    final profile = id == null
        ? null
        : ref.watch(userProfileByIdProvider(id)).value;

    return Container(
      color: AppColors.neutral1000,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.md,
            0,
            AppSpacing.base,
          ),
          child: Row(
            children: [
              _StoreLogo(url: profile?.avatarUrl),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  profile?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamilyDisplay,
                    fontSize: AppTypography.sizeLg,
                    height: AppTypography.lineHeightLg,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral100,
                  ),
                ),
              ),
              const _HeaderIcon(glyph: AppIconGlyph.chat, label: 'Chat'),
              _HeaderIconButton(
                glyph: AppIconGlyph.bell,
                label: 'Notifications',
                onTap: () => context.push('/store/notifications'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreLogo extends StatelessWidget {
  const _StoreLogo({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const size = 24.0;
    return Semantics(
      label: 'Store logo',
      image: true,
      excludeSemantics: true,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: url == null
              ? const ColoredBox(color: AppColors.neutral700)
              : CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) =>
                      const ColoredBox(color: AppColors.neutral700),
                ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.glyph, required this.label});

  final AppIconGlyph glyph;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: _tapSize,
        height: _tapSize,
        child: Center(child: AppIcon(glyph, color: AppColors.neutral100)),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final AppIconGlyph glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: _tapSize,
          height: _tapSize,
          child: Center(child: AppIcon(glyph, color: AppColors.neutral100)),
        ),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _DashBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(storeEarningsProvider);
    final reportsAsync = ref.watch(storeReportsSummaryProvider);

    if (earningsAsync.isLoading || reportsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (earningsAsync.hasError || reportsAsync.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Couldn't load your dashboard."),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () {
                ref.invalidate(storeEarningsProvider);
                ref.invalidate(storeReportsSummaryProvider);
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    final earnings = earningsAsync.value!;
    final reports = reportsAsync.value!;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(storeEarningsProvider);
        ref.invalidate(storeReportsSummaryProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.xl,
          AppSpacing.base,
          // Clears the FAB.
          100,
        ),
        children: [
          _KpiGrid(earnings: earnings, reports: reports),
          const SizedBox(height: AppSpacing.xl),
          _QuickActions(
            onAddProduct: () => context.push('/store/products/new'),
            onOrders: () => context.go('/store/activity'),
            onProducts: () => context.push('/store/products'),
            onReports: () => context.go('/store/activity'),
          ),
          const SizedBox(height: AppSpacing.xl),
          _RecentSales(
            sales: earnings.recent,
            currency: earnings.currency,
            onSeeAll: () => context.go('/store/activity'),
          ),
        ],
      ),
    );
  }
}

// ── KPI grid ─────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.earnings, required this.reports});

  final StoreEarnings earnings;
  final StoreReportsSummary reports;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      // Without this the grid adds the status bar height on top of the
      // list's own padding, a gap of about 85 points under the header.
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.55,
      children: [
        _KpiTile(
          label: "Today's Sale",
          value: Money.format(earnings.todaySales, earnings.currency),
          color: AppColors.primary400,
          fg: AppColors.neutral100,
        ),
        _KpiTile(
          label: 'Orders',
          value: '${earnings.todayOrders}',
          subtitle: 'today',
        ),
        // weekChangePercent compares this week's sales to the same span last
        // week, so the delta chip reflects real trend context.
        _KpiTile(
          label: 'This Week',
          value: Money.format(earnings.weekSales, earnings.currency),
          delta: earnings.weekChangePercent,
        ),
        _KpiTile(
          label: 'Reports',
          value: '${reports.unresolved}',
          subtitle: 'unresolved',
          color: reports.unresolved > 0
              ? AppColors.warning400
              : AppColors.neutral200,
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    this.subtitle,
    this.delta,
    this.color = AppColors.neutral200,
    this.fg = AppColors.neutral1100,
  });

  final String label;
  final String value;
  final String? subtitle;

  /// Week-over-week percent change. Positive = green, negative = red, null =
  /// hidden.
  final int? delta;
  final Color color;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyDisplay,
                fontSize: AppTypography.sizeXs,
                fontWeight: FontWeight.w500,
                color: fg.withValues(alpha: 0.7),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamilyDisplay,
                      fontSize: AppTypography.sizeXl,
                      height: AppTypography.lineHeightXl,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: AppTypography.sizeXs,
                      color: fg.withValues(alpha: 0.6),
                    ),
                  ),
                if (delta != null) _DeltaChip(percent: delta!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small `+X% vs last week` chip.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final up = percent >= 0;
    final color = up ? AppColors.success400 : AppColors.error400;
    final bg = up ? AppColors.successAlpha10 : AppColors.errorAlpha10;
    final sign = up ? '+' : '';
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward : Icons.arrow_downward,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '$sign$percent% vs last week',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

/// Four quick-access buttons replacing the "Last chats" Figma section, which
/// has no spec yet (Messages feature, feature 30).
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAddProduct,
    required this.onOrders,
    required this.onProducts,
    required this.onReports,
  });

  final VoidCallback onAddProduct;
  final VoidCallback onOrders;
  final VoidCallback onProducts;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontFamily: AppTypography.fontFamilyDisplay,
            fontSize: AppTypography.sizeLg,
            fontWeight: FontWeight.w700,
            color: AppColors.neutral1100,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: AppIconGlyph.add,
                label: 'Add Product',
                onTap: onAddProduct,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ActionTile(
                icon: AppIconGlyph.delivery,
                label: 'Orders',
                onTap: onOrders,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ActionTile(
                icon: AppIconGlyph.category,
                label: 'Products',
                onTap: onProducts,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ActionTile(
                icon: AppIconGlyph.report,
                label: 'Reports',
                onTap: onReports,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AppIconGlyph icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.neutral200,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, color: AppColors.neutral900),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTypography.sizeXs,
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutral900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recent sales ─────────────────────────────────────────────────────────────

class _RecentSales extends StatelessWidget {
  const _RecentSales({
    required this.sales,
    required this.currency,
    required this.onSeeAll,
  });

  final List<StoreRecentSale> sales;
  final String currency;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Sales',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamilyDisplay,
                  fontSize: AppTypography.sizeLg,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral1100,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'See all orders',
              child: GestureDetector(
                onTap: onSeeAll,
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: AppIcon(
                    AppIconGlyph.forward,
                    color: AppColors.neutral500,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (sales.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text(
                'No sales yet.',
                style: TextStyle(color: AppColors.neutral500),
              ),
            ),
          )
        else
          for (final sale in sales) _SaleRow(sale: sale, currency: currency),
      ],
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale, required this.currency});

  final StoreRecentSale sale;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.customerName ?? 'Order #${sale.orderNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamilyDisplay,
                    fontSize: AppTypography.sizeSm,
                    fontWeight: FontWeight.w500,
                    color: AppColors.neutral1100,
                  ),
                ),
                if (sale.place.isNotEmpty)
                  Text(
                    sale.place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTypography.sizeXs,
                      color: AppColors.neutral500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            Money.format(sale.amount, currency),
            style: const TextStyle(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontSize: AppTypography.sizeSm,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral1100,
            ),
          ),
        ],
      ),
    );
  }
}

// ── FAB ──────────────────────────────────────────────────────────────────────

class _AddFab extends StatelessWidget {
  const _AddFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add product',
      excludeSemantics: true,
      child: Material(
        color: AppColors.primary400,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 64,
            height: 64,
            child: Center(
              child: AppIcon(
                AppIconGlyph.add,
                size: 32,
                color: AppColors.neutral100,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
