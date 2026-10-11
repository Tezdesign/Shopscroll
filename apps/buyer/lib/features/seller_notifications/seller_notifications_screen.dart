import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';

import '../../data/models/store_notification.dart';
import '../../data/providers/store_notification_providers.dart';
import '../store/seller_gate.dart';

/// The seller's Notifications screen at `/store/notifications`.
///
/// Figma node: Notifications-seller 3016:9501. Deviations (design fixes,
/// audit Oct-2026):
/// - Chat messages are excluded entirely — they belong in the future Messages
///   feature. Only system events (orders, reports, stock alerts) appear here.
/// - Two tabs replace the flat list: **All** (every system event) and
///   **Alerts** (reports + stock alerts that need action).
/// - Unread rows show a 2 px [AppColors.primary400] left bar and bold title.
/// - "Mark all as read" is shown only when at least one row is unread.
class SellerNotificationsScreen extends ConsumerStatefulWidget {
  const SellerNotificationsScreen({super.key});

  @override
  ConsumerState<SellerNotificationsScreen> createState() =>
      _SellerNotificationsScreenState();
}

class _SellerNotificationsScreenState
    extends ConsumerState<SellerNotificationsScreen> {
  int _tab = 0; // 0 = All, 1 = Alerts

  Future<void> _markAllRead() async {
    await ref.read(markAllNotificationsReadProvider)();
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(storeNotificationsProvider);
    final alertsAsync = ref.watch(storeAlertsProvider);
    final currentAsync = _tab == 0 ? allAsync : alertsAsync;
    final hasUnread = currentAsync.value?.rows.any((n) => !n.isRead) ?? false;

    return SellerGate(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.neutral100,
          body: Column(
            children: [
              _Header(
                hasUnread: hasUnread,
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/store'),
                onMarkAllRead: _markAllRead,
              ),
              _TabRow(
                active: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              Expanded(
                child: _tab == 0
                    ? _NotificationList(
                        asyncState: allAsync,
                        onRetry: () =>
                            ref.invalidate(storeNotificationsProvider),
                        onLoadMore: () => ref
                            .read(storeNotificationsProvider.notifier)
                            .loadMore(),
                      )
                    : _NotificationList(
                        asyncState: alertsAsync,
                        onRetry: () => ref.invalidate(storeAlertsProvider),
                        onLoadMore: null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.hasUnread,
    required this.onBack,
    required this.onMarkAllRead,
  });

  final bool hasUnread;
  final VoidCallback onBack;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.neutral1000,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, AppSpacing.base, AppSpacing.base),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Back',
                child: GestureDetector(
                  onTap: onBack,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: AppIcon(AppIconGlyph.back, color: AppColors.neutral100),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Notifications',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamilyDisplay,
                    fontSize: AppTypography.sizeLg,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral100,
                  ),
                ),
              ),
              if (hasUnread)
                Semantics(
                  button: true,
                  label: 'Mark all as read',
                  child: GestureDetector(
                    onTap: onMarkAllRead,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        'Mark all read',
                        style: TextStyle(
                          fontSize: AppTypography.sizeXs,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary400,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────────

const _tabs = ['All', 'Alerts'];

class _TabRow extends StatelessWidget {
  const _TabRow({required this.active, required this.onChanged});

  final int active;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.neutral1000,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Semantics(
                button: true,
                selected: i == active,
                label: _tabs[i],
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(right: AppSpacing.base),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: i == active
                              ? AppColors.neutral100
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      _tabs[i],
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamilyDisplay,
                        fontSize: AppTypography.sizeSm,
                        fontWeight: FontWeight.w600,
                        color: i == active
                            ? AppColors.neutral100
                            : AppColors.neutral500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Notification list ─────────────────────────────────────────────────────────

class _NotificationList extends ConsumerWidget {
  const _NotificationList({
    required this.asyncState,
    required this.onRetry,
    required this.onLoadMore,
  });

  final AsyncValue<StoreNotificationsState> asyncState;
  final VoidCallback onRetry;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Couldn't load notifications."),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
      data: (state) {
        if (state.rows.isEmpty) {
          return const Center(
            child: Text(
              'Nothing here yet.',
              style: TextStyle(color: AppColors.neutral500),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => onRetry(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: state.rows.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: AppSpacing.base,
              endIndent: AppSpacing.base,
            ),
            itemBuilder: (context, index) {
              if (index == state.rows.length) {
                return state.loadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.base),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : TextButton(
                        onPressed: onLoadMore,
                        child: const Text('Load more'),
                      );
              }
              return _NotificationRow(notification: state.rows[index]);
            },
          ),
        );
      },
    );
  }
}

// ── Row ───────────────────────────────────────────────────────────────────────

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification});

  final StoreNotification notification;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            // Space for the unread bar.
            AppSpacing.base + 2,
            AppSpacing.md,
            AppSpacing.base,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeIcon(type: notification.type),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamilyDisplay,
                        fontSize: AppTypography.sizeSm,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        color: AppColors.neutral1100,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: AppTypography.sizeXs,
                        color: AppColors.neutral700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _agoLabel(notification.createdAt),
                      style: const TextStyle(
                        fontSize: AppTypography.sizeXs,
                        color: AppColors.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 2 px accent bar on the left for unread rows.
        if (unread)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: AppColors.primary400,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
      ],
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});

  final StoreNotificationType type;

  @override
  Widget build(BuildContext context) {
    final (glyph, bg) = switch (type) {
      StoreNotificationType.newOrder => (
        AppIconGlyph.delivery,
        AppColors.primaryAlpha10,
      ),
      StoreNotificationType.newReport => (
        AppIconGlyph.report,
        AppColors.errorAlpha10,
      ),
      StoreNotificationType.stockAlert => (
        AppIconGlyph.timer,
        AppColors.warningAlpha10,
      ),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Center(
        child: AppIcon(
          glyph,
          size: 18,
          color: switch (type) {
            StoreNotificationType.newOrder => AppColors.primary400,
            StoreNotificationType.newReport => AppColors.error400,
            StoreNotificationType.stockAlert => AppColors.warning400,
          },
        ),
      ),
    );
  }
}

String _agoLabel(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  final days = diff.inDays;
  return days == 1 ? '1 day ago' : '$days days ago';
}
