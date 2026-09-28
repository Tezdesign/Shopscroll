import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/conversation.dart';
import '../../data/providers/saved_providers.dart';
import 'activity_logic.dart';
import 'list_states.dart';

/// The Messages tab (spec 0008, AC-11, AC-13): the buyer's conversations
/// with stores, newest first. Tapping a row opens the chat coming soon page.
/// On the Supabase backend the list is always empty until a chat feature
/// designs a table.
class MessagesTab extends ConsumerWidget {
  const MessagesTab({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(conversationsProvider)
        .when(
          loading: () => const ListLoading(),
          error: (error, stackTrace) => ListMessage(
            "Couldn't load your messages.",
            buttonLabel: 'Try again',
            onPressed: () => ref.invalidate(conversationsProvider),
          ),
          data: (conversations) {
            if (conversations.isEmpty) {
              return const ListMessage('No messages yet');
            }
            final shown = filterConversations(
              newestConversationsFirst(conversations),
              query,
            );
            if (shown.isEmpty) return ListMessage.noResults(query);
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.base),
              itemCount: shown.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.base),
              itemBuilder: (context, index) =>
                  _ConversationRow(conversation: shown[index]),
            );
          },
        );
  }
}

/// Figma node 874:5784: a round store avatar, the store name over the last
/// message, and the time on the right. An unread row is all in the darker
/// text colour, a read one has a lighter message and time.
class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation});

  final Conversation conversation;

  static const double _avatar = 48;

  @override
  Widget build(BuildContext context) {
    final unread = conversation.isUnread;
    final detailColor = unread ? AppColors.neutral1100 : AppColors.neutral600;
    final time = messageTimeLabel(conversation.sentAt, DateTime.now());

    TextStyle style(Color color, {FontWeight weight = FontWeight.w500}) =>
        TextStyle(
          fontFamily: AppTypography.fontFamilyBody,
          fontSize: AppTypography.sizeSm,
          height: AppTypography.lineHeightSm,
          fontWeight: weight,
          color: color,
        );

    return Semantics(
      button: true,
      label:
          '${conversation.storeName}, ${conversation.lastMessage}, $time'
          '${unread ? ', unread' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.push('/activity/chat/${conversation.id}'),
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: SizedBox(
                  width: _avatar,
                  height: _avatar,
                  child: conversation.storeAvatarUrl == null
                      ? const ColoredBox(color: AppColors.neutral200)
                      : CachedNetworkImage(
                          imageUrl: conversation.storeAvatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const ColoredBox(color: AppColors.neutral200),
                          errorWidget: (context, url, error) =>
                              const ColoredBox(color: AppColors.neutral200),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.storeName,
                      style: style(
                        AppColors.neutral1100,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      conversation.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style(detailColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(time, style: style(detailColor)),
            ],
          ),
        ),
      ),
    );
  }
}
