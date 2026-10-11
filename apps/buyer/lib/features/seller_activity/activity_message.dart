import 'package:flutter/material.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';

/// A centered message for a tab of the seller's Activity area (spec 0018,
/// AC-14): an empty or no result text, or a failure with a "Try again" button
/// when [onRetry] is given. With [onRefresh] pulling down still refreshes the
/// tab, so an empty list can be reloaded.
class ActivityMessage extends StatelessWidget {
  const ActivityMessage({
    super.key,
    required this.text,
    this.onRetry,
    this.onRefresh,
  });

  final String text;
  final VoidCallback? onRetry;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeSm,
            height: AppTypography.lineHeightSm,
            color: AppColors.neutral600,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.base),
          RetryButton(onPressed: onRetry!),
        ],
      ],
    );
    if (onRefresh == null) return Center(child: body);
    return RefreshIndicator(
      onRefresh: onRefresh!,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(height: constraints.maxHeight, child: body),
        ),
      ),
    );
  }
}

/// The "Try again" button of the Activity tabs. [AppButton] hugs its content
/// and is about 42 high, so this lifts it to the 44 touch size (spec 0018,
/// AC-16).
class RetryButton extends StatelessWidget {
  const RetryButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
      child: AppButton(
        label: 'Try again',
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.small,
        onPressed: onPressed,
      ),
    );
  }
}
