import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shopscroll_shared/models/chat_message.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

import '../activity/activity_logic.dart';

/// A round store avatar, the 40 pixel one of Figma node 874:5937.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, this.url, this.size = 40});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? const ColoredBox(color: AppColors.neutral200)
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const ColoredBox(color: AppColors.neutral200),
                errorWidget: (context, url, error) =>
                    const ColoredBox(color: AppColors.neutral200),
              ),
      ),
    );
  }
}

/// One message in the thread, in the pill style of Figma node 874:5937: blue
/// on the right for the person's own, grey on the left (with the store's
/// avatar, shown only on the first of a run) for the store's. A message that
/// is not stored yet is a little faded, and a failed one says "Not sent. Tap
/// to retry" under it; long pressing a failed one offers Remove (AC-19).
///
/// Deviations from the frame: no avatar beside the person's own bubbles (the
/// thread has no buyer photo to show), and the sending and failed states are
/// not drawn in Figma.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.otherName,
    this.otherAvatarUrl,
    this.showAvatar = true,
    this.onRetry,
    this.onRemove,
  });

  final ChatMessage message;
  final bool mine;
  final String otherName;
  final String? otherAvatarUrl;
  final bool showAvatar;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final failed = message.status == ChatMessageStatus.failed;
    final sending = message.status == ChatMessageStatus.sending;
    final text = message.body ?? '';
    final time = messageTimeLabel(message.createdAt, DateTime.now());

    final bubble = Opacity(
      opacity: sending ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary400 : AppColors.neutral600,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeSm,
            height: AppTypography.lineHeightSm,
            color: AppColors.neutral100,
          ),
        ),
      ),
    );

    final column = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.7,
          ),
          child: bubble,
        ),
        if (failed)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Not sent. Tap to retry',
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeXs,
                height: AppTypography.lineHeightXs,
                color: AppColors.error500,
              ),
            ),
          ),
      ],
    );

    return Semantics(
      label: '${mine ? 'You' : otherName} said $text, $time'
          '${failed ? ', not sent, tap to retry' : ''}',
      button: failed,
      excludeSemantics: true,
      onTap: failed ? onRetry : null,
      onLongPress: failed ? onRemove : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: failed ? onRetry : null,
        onLongPress: failed ? onRemove : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.xs,
          ),
          child: mine
              ? Align(alignment: Alignment.centerRight, child: column)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      child: showAvatar
                          ? ChatAvatar(url: otherAvatarUrl)
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(child: column),
                  ],
                ),
        ),
      ),
    );
  }
}
