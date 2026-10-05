import 'package:flutter/material.dart';
import 'package:shopscroll_shared/models/product_draft.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';
import 'package:shopscroll_shared/widgets/app_text_field.dart';

import 'flow_widgets.dart';
import 'photo_picker.dart';
import 'product_flow_controller.dart';
import 'product_messages.dart';

/// Step 1, "Start with the basics": photos, title, category and description
/// (Figma nodes 5523:27381 filled, 5523:28160 empty, 5523:28361 upload error).
///
/// Deviations from the frames (spec 0015): no Store dropdown (one account is
/// one store), and the empty state shows what is missing after a tap on
/// Continue instead of a disabled button.
class BasicsStep extends StatefulWidget {
  const BasicsStep({
    super.key,
    required this.controller,
    required this.categories,
    required this.onPickPhotos,
    this.onFillFromPhotos,
    this.filling = false,
  });

  final ProductFlowController controller;

  /// The category names, or null while they load.
  final List<String>? categories;

  /// Asks the screen to open the camera or the library for photos.
  final ValueChanged<PhotoSourceChoice> onPickPhotos;

  /// "Fill from photos" (AC-13). Null hides the button.
  final VoidCallback? onFillFromPhotos;
  final bool filling;

  @override
  State<BasicsStep> createState() => _BasicsStepState();
}

class _BasicsStepState extends State<BasicsStep> {
  late final TextEditingController _title;
  late final TextEditingController _description;

  late int _seenRevision;

  ProductFlowController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: c.data.title);
    _description = TextEditingController(text: c.data.description);
    _seenRevision = c.fieldRevision;
  }

  @override
  void didUpdateWidget(BasicsStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An accepted suggestion changed the text from outside.
    if (_seenRevision != c.fieldRevision) {
      _seenRevision = c.fieldRevision;
      _title.text = c.data.title;
      _description.text = c.data.description;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _issue(String code) {
    if (!c.attempted(1)) return null;
    final match = c.issuesFor(1).where((i) => i.code == code);
    return match.isEmpty ? null : issueMessage(match.first);
  }

  void _showPhotoActions(PhotoItem item, int index) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white100,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.status == PhotoStatus.done && index != 0)
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Set as cover'),
                onTap: () {
                  Navigator.pop(sheet);
                  c.setCover(index);
                },
              ),
            if (item.status == PhotoStatus.done && index > 0)
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('Move left'),
                onTap: () {
                  Navigator.pop(sheet);
                  c.movePhoto(index, index - 1);
                },
              ),
            if (item.status == PhotoStatus.done && index < c.photos.length - 1)
              ListTile(
                leading: const Icon(Icons.arrow_forward),
                title: const Text('Move right'),
                onTap: () {
                  Navigator.pop(sheet);
                  c.movePhoto(index, index + 1);
                },
              ),
            if (item.status == PhotoStatus.failed)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Retry upload'),
                onTap: () {
                  Navigator.pop(sheet);
                  c.retryPhoto(item.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error500),
              title: const Text(
                'Remove',
                style: TextStyle(color: AppColors.error500),
              ),
              onTap: () {
                Navigator.pop(sheet);
                c.removePhoto(item.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white100,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheet);
                widget.onPickPhotos(PhotoSourceChoice.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () {
                Navigator.pop(sheet);
                widget.onPickPhotos(PhotoSourceChoice.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = c.photos;
    final failed = photos.where((p) => p.status == PhotoStatus.failed).toList();
    final photoIssue = _issue('no_photo') ?? _issue('too_many_photos');
    final categories = widget.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(
          'Photos',
          required: true,
          trailing: '${photos.length} of ${ProductDraftData.maxPhotos}',
        ),
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _PhotoTile(
                    item: photos[i],
                    isCover: i == 0,
                    onTap: () => _showPhotoActions(photos[i], i),
                  ),
                ),
              if (photos.length < ProductDraftData.maxPhotos)
                _AddPhotoTile(onTap: _showSourceSheet),
            ],
          ),
        ),
        if (widget.onFillFromPhotos != null && photos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: widget.filling ? 'Reading your photos...' : 'Fill from photos',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              leadingIcon: Icons.auto_awesome,
              enabled: !widget.filling,
              onPressed: widget.filling ? null : widget.onFillFromPhotos,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          photos.isEmpty
              ? 'Add at least one photo. Choose a cover after uploading, it appears first to shoppers.'
              : 'The cover appears first to shoppers. Tap a photo to change it.',
          style: flowHelperStyle,
        ),
        if (photoIssue != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(photoIssue, style: flowErrorStyle),
        ],
        for (final item in failed) ...[
          const SizedBox(height: AppSpacing.md),
          FlowNotice(
            error: true,
            title: "Photo couldn't upload",
            message:
                'Check your connection. Your other photos and details are safe.',
            actions: [
              FlowLink('Retry upload', onTap: () => c.retryPhoto(item.id)),
              FlowLink(
                'Remove file',
                color: AppColors.error500,
                onTap: () => c.removePhoto(item.id),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.base),
        const FieldLabel('Product title', required: true),
        AppTextField(
          controller: _title,
          hintText: 'e.g. Long-sleeve wrap dress',
          errorText: _issue('bad_title'),
          onChanged: c.setTitle,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.xs),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _title,
          builder: (context, value, _) => Text(
            '${value.text.characters.length} / 100 characters. Use a clear name shoppers can search for.',
            style: flowHelperStyle,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        const FieldLabel('Category', required: true),
        if (categories == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: LinearProgressIndicator(),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final name in categories)
                OptionChip(
                  label: name,
                  selected: c.data.category == name,
                  onTap: () => c.setCategory(name),
                ),
            ],
          ),
        if (_issue('bad_category') != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(_issue('bad_category')!, style: flowErrorStyle),
        ],
        const SizedBox(height: AppSpacing.base),
        const FieldLabel('Description'),
        AppTextField(
          controller: _description,
          hintText: 'Describe the fabric, design and what makes it special.',
          maxLines: 4,
          onChanged: c.setDescription,
          errorText: _issue('bad_description'),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Add useful details. Material and care come next.',
          style: flowHelperStyle,
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.item,
    required this.isCover,
    required this.onTap,
  });

  final PhotoItem item;
  final bool isCover;
  final VoidCallback onTap;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    final failed = item.status == PhotoStatus.failed;
    return Semantics(
      button: true,
      label: isCover ? 'Cover photo. Tap for options.' : 'Photo. Tap for options.',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: failed
                  ? AppColors.error400
                  : isCover
                  ? AppColors.primary400
                  : AppColors.neutral200,
              width: isCover || failed ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PhotoImage(bytes: item.bytes, path: item.path),
              if (item.status == PhotoStatus.uploading)
                const ColoredBox(
                  color: AppColors.blackAlpha20,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              if (failed)
                const ColoredBox(
                  color: AppColors.errorAlpha50,
                  child: Center(
                    child: Icon(Icons.error_outline, color: AppColors.white100),
                  ),
                ),
              if (isCover && !failed)
                Positioned(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary400,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      'Cover',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamilyBody,
                        fontSize: AppTypography.sizeXs,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white100,
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

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add photos',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.white100,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.neutral300),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, color: AppColors.primary400),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Add photos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamilyBody,
                  fontSize: AppTypography.sizeXs,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
