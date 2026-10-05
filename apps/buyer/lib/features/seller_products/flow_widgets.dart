import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';

import '../../data/repositories/supabase/row_mappers.dart';

/// Building blocks shared by the add or edit product screens (spec 0015).
/// Figma frames: `product-creation-*` in file toOakybJ0DaJmU7vcEC0AW.

const flowTitleStyle = TextStyle(
  fontFamily: AppTypography.fontFamilyDisplay,
  fontSize: AppTypography.sizeXl,
  height: AppTypography.lineHeightXl,
  fontWeight: FontWeight.w600,
  color: AppColors.neutral1100,
);

const flowSectionStyle = TextStyle(
  fontFamily: AppTypography.fontFamilyDisplay,
  fontSize: AppTypography.sizeLg,
  height: AppTypography.lineHeightLg,
  fontWeight: FontWeight.w600,
  color: AppColors.neutral1100,
);

const flowLabelStyle = TextStyle(
  fontFamily: AppTypography.fontFamilyBody,
  fontSize: AppTypography.sizeSm,
  height: AppTypography.lineHeightSm,
  fontWeight: FontWeight.w600,
  color: AppColors.neutral1100,
);

const flowBodyStyle = TextStyle(
  fontFamily: AppTypography.fontFamilyBody,
  fontSize: AppTypography.sizeSm,
  height: AppTypography.lineHeightBase,
  fontWeight: FontWeight.w400,
  color: AppColors.neutral900,
);

const flowHelperStyle = TextStyle(
  fontFamily: AppTypography.fontFamilyBody,
  fontSize: AppTypography.sizeXs,
  height: AppTypography.lineHeightXs,
  fontWeight: FontWeight.w400,
  color: AppColors.neutral900,
);

const flowErrorStyle = TextStyle(
  fontFamily: AppTypography.fontFamilyBody,
  fontSize: AppTypography.sizeXs,
  height: AppTypography.lineHeightXs,
  fontWeight: FontWeight.w500,
  color: AppColors.error500,
);

/// The title bar: a back arrow, the title and "Save draft" (Figma: top of
/// every `product-creation-*` frame). Both actions have a 48 pixel tap area.
class FlowHeader extends StatelessWidget {
  const FlowHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.onSaveDraft,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onSaveDraft;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.neutral1100),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamilyBody,
                  fontSize: AppTypography.sizeBase,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral1100,
                ),
              ),
            ),
          ),
          if (onSaveDraft != null)
            TextButton(
              onPressed: onSaveDraft,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text(
                'Save draft',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamilyBody,
                  fontSize: AppTypography.sizeSm,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Three bars with the step names under them. The current and earlier steps
/// are filled. Tapping a name goes to an earlier step only.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.step,
    required this.labels,
    this.onTapStep,
  });

  final int step;
  final List<String> labels;
  final ValueChanged<int>? onTapStep;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $step of ${labels.length}: ${labels[step - 1]}',
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTapStep != null && i + 1 < step
                    ? () => onTapStep!(i + 1)
                    : null,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == labels.length - 1 ? 0 : AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: i + 1 <= step
                              ? AppColors.primary400
                              : AppColors.primary100,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamilyBody,
                          fontSize: AppTypography.sizeXs,
                          height: AppTypography.lineHeightXs,
                          fontWeight: i + 1 == step
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: i + 1 == step
                              ? AppColors.primary400
                              : AppColors.neutral700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The Back and Continue (or Publish) bar at the bottom. Neither button is
/// ever disabled for a missing field: a tap says what is missing instead
/// (spec 0015, deviation from the frames). [busy] only blocks a second tap.
class FlowBottomBar extends StatelessWidget {
  const FlowBottomBar({
    super.key,
    required this.backLabel,
    required this.onBack,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String backLabel;
  final VoidCallback? onBack;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white100,
        border: Border(top: BorderSide(color: AppColors.neutral200)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.sm,
            AppSpacing.base,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              AppButton(
                label: backLabel,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: onBack,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: primaryLabel,
                  onPressed: onPrimary,
                  enabled: onPrimary != null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A label above a field, with a star for required fields.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = false, this.trailing});

  final String text;
  final bool required;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(required ? '$text *' : text, style: flowLabelStyle)),
          if (trailing != null) Text(trailing!, style: flowHelperStyle),
        ],
      ),
    );
  }
}

/// A rounded option the person can pick: a category, a size, a fit.
class OptionChip extends StatelessWidget {
  const OptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onRemove,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// When set, a small x removes the option.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? AppColors.primary50 : AppColors.white100,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: selected ? AppColors.primary400 : AppColors.neutral300,
              ),
            ),
            // widthFactor 1 keeps the chip as wide as its text; the minimum
            // height of 44 pixels then centers the text in a good tap area.
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamilyBody,
                        fontSize: AppTypography.sizeSm,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? AppColors.primary500
                            : AppColors.neutral1000,
                      ),
                    ),
                    if (onRemove != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      GestureDetector(
                        onTap: onRemove,
                        child: Semantics(
                          button: true,
                          label: 'Remove $label',
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: AppColors.neutral700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A short message in a tinted box: blue for information, red for a problem.
class FlowNotice extends StatelessWidget {
  const FlowNotice({
    super.key,
    required this.title,
    this.message,
    this.error = false,
    this.actions = const [],
    this.children = const [],
  });

  final String title;
  final String? message;
  final bool error;
  final List<Widget> actions;

  /// Extra rows under the text, inside the same box.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: error ? AppColors.errorAlpha10 : AppColors.primaryAlpha10,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeSm,
                height: AppTypography.lineHeightSm,
                fontWeight: FontWeight.w600,
                color: error ? AppColors.error500 : AppColors.primary500,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                style: flowBodyStyle.copyWith(color: AppColors.neutral1000),
              ),
            ],
            ...children,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(spacing: AppSpacing.base, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

/// A blue text link with a 44 pixel tap area.
class FlowLink extends StatelessWidget {
  const FlowLink(this.label, {super.key, required this.onTap, this.color});

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.fontFamilyBody,
          fontSize: AppTypography.sizeSm,
          fontWeight: FontWeight.w600,
          color: color ?? AppColors.primary400,
        ),
      ),
    );
  }
}

/// A small number or text box for a table cell. The full 48 pixel field of the
/// form is too tall for a table row, this one keeps a 44 pixel tap area.
class CellField extends StatelessWidget {
  const CellField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.decimal = false,
    this.error = false,
    this.semanticLabel,
    this.width = 84,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool decimal;
  final bool error;
  final String? semanticLabel;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 44,
      child: Semantics(
        label: semanticLabel,
        textField: true,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
            ),
          ],
          textAlign: TextAlign.end,
          style: flowLabelStyle.copyWith(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.white100,
            hintText: hint,
            hintStyle: flowBodyStyle.copyWith(color: AppColors.neutral500),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: error ? AppColors.error400 : AppColors.neutral300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: error ? AppColors.error400 : AppColors.primary400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A product photo: the bytes still in memory while the phone has them, the
/// stored picture otherwise, and a plain grey box when neither loads.
class PhotoImage extends StatelessWidget {
  const PhotoImage({super.key, this.bytes, this.path, this.fit = BoxFit.cover});

  final Uint8List? bytes;

  /// A storage path without the bucket name.
  final String? path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return Image.memory(bytes!, fit: fit, gaplessPlayback: true);
    }
    final url = path == null
        ? null
        : storageUrlFromColumn('product-images/$path');
    if (url == null || !url.startsWith('http')) return const _PhotoPlaceholder();
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (context, _) => const _PhotoPlaceholder(),
      errorWidget: (context, url, error) => const _PhotoPlaceholder(),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.neutral200,
    child: Center(
      child: Icon(Icons.image_outlined, color: AppColors.neutral500),
    ),
  );
}
