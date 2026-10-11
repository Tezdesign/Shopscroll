import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';
import 'package:shopscroll_shared/widgets/search_field.dart';

import '../../core/area/app_area.dart';
import '../../data/providers/store_activity_providers.dart';
import '../../data/providers/user_profile_providers.dart';
import '../store/seller_gate.dart';
import 'earnings_tab.dart';
import 'orders_tab.dart';
import 'reports_tab.dart';

/// The seller's Activity area at `/store/activity` (spec 0018, AC-1): the store
/// header, one search field, the tabs Orders, Earnings and Reports, and the
/// "+" button that opens the new product flow. Only a seller stays
/// ([SellerGate]).
///
/// Figma nodes: Activity-orders-seller 3001:11659 (this screen with the Orders
/// tab), Activity-earnings-seller 3001:11790, Activity-reports-seller
/// 3001:11908. Deviations from the frames:
/// - The status bar and the bottom tab bar belong to the seller shell, which
///   has no spec yet (spec 0018, feature 30), so they are not drawn.
/// - The chat and bell icons are drawn but do nothing yet.
/// - The header fill is [AppColors.neutral1000], the nearest token to the
///   frame's `#222` (variable `Surface/Inverse header`, which has no token).
/// - The search field is the shared [SearchField] (bordered, no microphone).
class SellerActivityScreen extends ConsumerStatefulWidget {
  const SellerActivityScreen({super.key});

  @override
  ConsumerState<SellerActivityScreen> createState() =>
      _SellerActivityScreenState();
}

const _tabs = ['Orders', 'Earnings', 'Reports'];
const _searchDelay = Duration(milliseconds: 400);
const _tapSize = 44.0;

class _SellerActivityScreenState extends ConsumerState<SellerActivityScreen> {
  int _tab = 0;
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// The search applies once typing pauses, so the server is not asked for
  /// every letter.
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(_searchDelay, () {
      ref.read(storeActivitySearchProvider.notifier).state = text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SellerGate(
      // The header is dark, so the clock and the signal icons turn light.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.neutral100,
          floatingActionButton: _AddProductButton(
            onPressed: () => context.push('/store/products/new'),
          ),
          body: Column(
            children: [
              _Header(controller: _search, onChanged: _onSearchChanged),
              _TabRow(active: _tab, onChanged: (i) => setState(() => _tab = i)),
              Expanded(
                child: switch (_tab) {
                  0 => const OrdersTab(),
                  1 => EarningsTab(onSeeOrders: () => setState(() => _tab = 0)),
                  _ => const ReportsTab(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

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
            AppSpacing.base,
            AppSpacing.base,
          ),
          child: Column(
            children: [
              Row(
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
                  _HeaderIcon(
                    glyph: AppIconGlyph.bell,
                    label: 'Notifications',
                    onTap: () => context.push('/store/notifications'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SearchField(
                controller: controller,
                hintText: 'Search',
                onChanged: onChanged,
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
  const _HeaderIcon({required this.glyph, required this.label, this.onTap});

  final AppIconGlyph glyph;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox(
      width: _tapSize,
      height: _tapSize,
      child: Center(child: AppIcon(glyph, color: AppColors.neutral100)),
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: onTap != null ? GestureDetector(onTap: onTap, child: icon) : icon,
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.active, required this.onChanged});

  final int active;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  constraints: const BoxConstraints(
                    minWidth: _tapSize,
                    minHeight: _tapSize,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == active
                            ? AppColors.neutral1100
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    _tabs[i],
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamilyDisplay,
                      fontSize: AppTypography.sizeSm,
                      height: AppTypography.lineHeightSm,
                      fontWeight: FontWeight.w600,
                      color: i == active
                          ? AppColors.neutral1100
                          : AppColors.neutral500,
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

/// The "+" button (Figma Fab Button, node 728:3780).
class _AddProductButton extends StatelessWidget {
  const _AddProductButton({required this.onPressed});

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
