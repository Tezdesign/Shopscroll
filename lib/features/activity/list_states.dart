import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';

/// The centred message the Activity tabs show for an empty list, a failed
/// load and a search with no match (spec 0008, AC-2, AC-12). [buttonLabel]
/// and [onPressed] add the "Try again" button.
class ListMessage extends StatelessWidget {
  const ListMessage(this.text, {super.key, this.buttonLabel, this.onPressed});

  /// "No results found for “text”", the message for a search with no match.
  ListMessage.noResults(String query, {Key? key})
    : this('No results found for “${query.trim()}”', key: key);

  final String text;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamilyDisplay,
                fontSize: AppTypography.sizeLg,
                height: AppTypography.lineHeightSm,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral700,
              ),
            ),
            if (buttonLabel != null) ...[
              const SizedBox(height: AppSpacing.base),
              AppButton(label: buttonLabel!, onPressed: onPressed),
            ],
          ],
        ),
      ),
    );
  }
}

/// The spinner every Activity list shows while it loads (AC-12).
class ListLoading extends StatelessWidget {
  const ListLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
