import 'package:flutter/material.dart';
import 'package:shopscroll_shared/models/product_draft.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';
import 'package:shopscroll_shared/widgets/app_text_field.dart';

import 'flow_widgets.dart';
import 'variant_options.dart';

/// What the seller accepted from a suggestion. Nothing is saved before this
/// (spec 0015, AC-13).
class AutofillChoice {
  const AutofillChoice({
    required this.title,
    required this.description,
    required this.category,
    required this.material,
    required this.colors,
  });

  final String title;
  final String description;
  final String category;
  final String material;
  final List<ColorOption> colors;
}

/// The palette colors a suggestion's color names match, by name, ignoring case.
List<ColorOption> matchColors(List<String> names) {
  final out = <ColorOption>[];
  for (final name in names) {
    for (final option in colorPalette) {
      if (option.name.toLowerCase() == name.trim().toLowerCase() &&
          !out.contains(option)) {
        out.add(option);
      }
    }
  }
  return out;
}

/// Shows the suggestion as values the seller can edit and then accept or
/// leave. Returns the choice, or null when the seller leaves it.
Future<AutofillChoice?> showAutofillSheet(
  BuildContext context, {
  required AutofillSuggestion suggestion,
  required List<String> categories,
}) {
  return showModalBottomSheet<AutofillChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white100,
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: _AutofillSheet(suggestion: suggestion, categories: categories),
    ),
  );
}

class _AutofillSheet extends StatefulWidget {
  const _AutofillSheet({required this.suggestion, required this.categories});

  final AutofillSuggestion suggestion;
  final List<String> categories;

  @override
  State<_AutofillSheet> createState() => _AutofillSheetState();
}

class _AutofillSheetState extends State<_AutofillSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _material;
  late String _category;
  late final List<ColorOption> _colors;
  late final Set<int> _pickedColors;

  @override
  void initState() {
    super.initState();
    final s = widget.suggestion;
    _title = TextEditingController(text: s.title);
    _description = TextEditingController(text: s.description);
    _material = TextEditingController(text: s.material ?? '');
    _category = widget.categories.contains(s.category) ? s.category : '';
    _colors = matchColors(s.colors);
    _pickedColors = {for (final c in _colors) c.value};
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _material.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.suggestion.remaining;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Suggested from your photos', style: flowSectionStyle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Check it and change anything. Nothing is saved until you use it.'
              '${remaining == null ? '' : ' $remaining runs left today.'}',
              style: flowHelperStyle,
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Title'),
            AppTextField(controller: _title),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Description'),
            AppTextField(controller: _description, maxLines: 4),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Category'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final name in widget.categories)
                  OptionChip(
                    label: name,
                    selected: _category == name,
                    onTap: () => setState(() => _category = name),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Material'),
            AppTextField(controller: _material, hintText: 'Not sure from the photos'),
            if (_colors.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const FieldLabel('Colors seen'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final color in _colors)
                    OptionChip(
                      label: color.name,
                      selected: _pickedColors.contains(color.value),
                      onTap: () => setState(() {
                        if (!_pickedColors.remove(color.value)) {
                          _pickedColors.add(color.value);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Chosen colors are added as options. Set their stock on the next step.',
                style: flowHelperStyle,
              ),
            ],
            const SizedBox(height: AppSpacing.base),
            AppButton(
              label: 'Use these',
              onPressed: () => Navigator.pop(
                context,
                AutofillChoice(
                  title: _title.text,
                  description: _description.text,
                  category: _category,
                  material: _material.text,
                  colors: [
                    for (final c in _colors)
                      if (_pickedColors.contains(c.value)) c,
                  ],
                ),
              ),
            ),
            FlowLink('Not now', color: AppColors.neutral900, onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
