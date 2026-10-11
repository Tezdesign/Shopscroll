import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';

import '../../data/models/store_order.dart';
import '../../data/providers/store_activity_providers.dart';
import 'activity_message.dart';

const _tapSize = 44.0;

/// The Earnings tab of the seller's Activity area (spec 0018, AC-6, AC-7,
/// AC-14): a period selector, one hero KPI card with a sparkline, and the 4
/// latest sales. It ignores the search field.
///
/// Figma node 3001:11790. Design fixes (audit Oct-2026):
/// - Period selector (Today / This week / All time) replaces the four always-on
///   cards so the seller focuses on one number at a time.
/// - A 4-bar sparkline from `StoreEarnings.recent` replaces the static frame.
/// - `Money.format` now adds thousands separators (`478,458.000 TND`).
class EarningsTab extends ConsumerWidget {
  const EarningsTab({super.key, required this.onSeeOrders});

  final VoidCallback onSeeOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(storeEarningsProvider);

    return earnings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => ActivityMessage(
        text: "Couldn't load your earnings.",
        onRetry: () => ref.invalidate(storeEarningsProvider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () => ref.refresh(storeEarningsProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.base,
            AppSpacing.base,
            96,
          ),
          children: [
            _Cards(data: data),
            const SizedBox(height: AppSpacing.xl),
            _RecentSales(data: data, onSeeOrders: onSeeOrders),
          ],
        ),
      ),
    );
  }
}

// ── Period selector + KPI card ────────────────────────────────────────────────

enum _Period { today, week, allTime }

const _periodLabels = ['Today', 'This Week', 'All time'];

class _Cards extends StatefulWidget {
  const _Cards({required this.data});

  final StoreEarnings data;

  @override
  State<_Cards> createState() => _CardsState();
}

class _CardsState extends State<_Cards> {
  _Period _period = _Period.today;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PeriodSelector(
          active: _period,
          onChanged: (p) => setState(() => _period = p),
        ),
        const SizedBox(height: AppSpacing.base),
        _HeroCard(period: _period, data: widget.data),
        const SizedBox(height: AppSpacing.base),
        _SecondaryRow(period: _period, data: widget.data),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.active, required this.onChanged});

  final _Period active;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 44 high so each tab is a 44 point tap area (spec 0018, AC-16).
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.neutral200,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: [
          for (final period in _Period.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: period == active,
                label: _periodLabels[period.index],
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onChanged(period),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: period == active
                          ? AppColors.neutral100
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      boxShadow: period == active
                          ? [
                              BoxShadow(
                                color: AppColors.neutral1000.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        _periodLabels[period.index],
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamilyDisplay,
                          fontSize: AppTypography.sizeSm,
                          fontWeight: period == active
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: period == active
                              ? AppColors.neutral1100
                              : AppColors.neutral600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.period, required this.data});

  final _Period period;
  final StoreEarnings data;

  @override
  Widget build(BuildContext context) {
    final (label, amount, note) = switch (period) {
      _Period.today => (
        "Today's Sales",
        Money.format(data.todaySales, data.currency),
        '${data.todayOrders} orders today',
      ),
      _Period.week => (
        'This Week',
        Money.format(data.weekSales, data.currency),
        _weekNote(data.weekChangePercent),
      ),
      _Period.allTime => (
        'Total Sales',
        Money.format(data.totalSales, data.currency),
        '${data.customers} customers total',
      ),
    };

    return Semantics(
      container: true,
      label: '$label, $amount${note == null ? '' : ', $note'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          border: Border.all(color: AppColors.primary400),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamilyDisplay,
                fontSize: AppTypography.sizeBase,
                fontWeight: FontWeight.w500,
                color: AppColors.primary400,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamilyDisplay,
                  fontSize: AppTypography.sizeXl,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral1100,
                ),
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(
                note,
                style: const TextStyle(
                  fontSize: AppTypography.sizeXs,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success400,
                ),
              ),
            ],
            if (data.recent.isNotEmpty && period != _Period.allTime) ...[
              const SizedBox(height: AppSpacing.base),
              SizedBox(height: 40, child: _Sparkline(sales: data.recent)),
            ],
          ],
        ),
      ),
    );
  }

  String? _weekNote(int? percent) {
    if (percent == null) return null;
    return '${percent.abs()}% ${percent < 0 ? 'less' : 'more'} than last week';
  }
}

class _SecondaryRow extends StatelessWidget {
  const _SecondaryRow({required this.period, required this.data});

  final _Period period;
  final StoreEarnings data;

  @override
  Widget build(BuildContext context) {
    final (leftLabel, leftValue, rightLabel, rightValue) = switch (period) {
      _Period.today => (
        'Orders today',
        '${data.todayOrders}',
        'New customers',
        '${data.newCustomersToday}',
      ),
      _Period.week => (
        // Last week up to the same weekday and time, the figure the percent
        // above compares with. The API has no order count for the week, so none
        // is shown.
        'Same span last week',
        Money.format(data.prevWeekSameSpanSales, data.currency),
        'Customers',
        '${data.customers}',
      ),
      _Period.allTime => (
        'Customers',
        '${data.customers}',
        'New today',
        '${data.newCustomersToday}',
      ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SmallCard(label: leftLabel, value: leftValue),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: _SmallCard(label: rightLabel, value: rightValue),
          ),
        ],
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  const _SmallCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTypography.sizeXs,
              fontWeight: FontWeight.w500,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontSize: AppTypography.sizeLg,
              fontWeight: FontWeight.w700,
              color: AppColors.neutral1100,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sparkline ─────────────────────────────────────────────────────────────────

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.sales});

  final List<StoreRecentSale> sales;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(sales: sales),
      size: const Size(double.infinity, 40),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.sales});

  final List<StoreRecentSale> sales;

  @override
  void paint(Canvas canvas, Size size) {
    if (sales.isEmpty) return;
    final maxAmount = sales.map((s) => s.amount).reduce(math.max);
    if (maxAmount == 0) return;

    final barWidth = (size.width - (sales.length - 1) * 4) / sales.length;
    final paint = Paint()
      ..color = AppColors.primary400.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final activePaint = Paint()
      ..color = AppColors.primary400
      ..style = PaintingStyle.fill;

    for (var i = 0; i < sales.length; i++) {
      final x = i * (barWidth + 4);
      final ratio = sales[i].amount / maxAmount;
      final barH = math.max(4.0, size.height * ratio);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barH, barWidth, barH),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, i == 0 ? activePaint : paint);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.sales != sales;
}

// ── Recent sales ──────────────────────────────────────────────────────────────

class _RecentSales extends StatelessWidget {
  const _RecentSales({required this.data, required this.onSeeOrders});

  final StoreEarnings data;
  final VoidCallback onSeeOrders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent sales',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamilyDisplay,
                  fontSize: AppTypography.sizeXl,
                  height: AppTypography.lineHeightXl,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral1100,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'See all orders',
              excludeSemantics: true,
              onTap: onSeeOrders,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSeeOrders,
                child: const SizedBox(
                  width: _tapSize,
                  height: _tapSize,
                  child: Center(child: AppIcon(AppIconGlyph.forward)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (data.recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                'No sales yet',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamilyBody,
                  fontSize: AppTypography.sizeSm,
                  height: AppTypography.lineHeightSm,
                  color: AppColors.neutral600,
                ),
              ),
            ),
          )
        else
          for (final sale in data.recent) ...[
            _SaleRow(sale: sale, currency: data.currency),
            if (sale != data.recent.last)
              const SizedBox(height: AppSpacing.base),
          ],
      ],
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale, required this.currency});

  final StoreRecentSale sale;
  final String currency;

  static const _small = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w600,
  );
  static const _large = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1100,
  );

  @override
  Widget build(BuildContext context) {
    final number = sale.orderNumber.toString().padLeft(6, '0');
    final name = sale.customerName ?? 'Customer';
    final amount = Money.format(sale.amount, currency);

    return Semantics(
      container: true,
      label:
          'Order $number, $name'
          '${sale.place.isEmpty ? '' : ', ${sale.place}'}, $amount',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order#$number',
                  style: _small.copyWith(color: AppColors.neutral600),
                ),
                Text(name, style: _large),
                if (sale.place.isNotEmpty)
                  Row(
                    children: [
                      const AppIcon(AppIconGlyph.location),
                      const SizedBox(width: AppSpacing.xs / 2),
                      Expanded(
                        child: Text(
                          sale.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _small.copyWith(color: AppColors.neutral1100),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(amount, style: _small.copyWith(color: AppColors.success400)),
        ],
      ),
    );
  }
}
