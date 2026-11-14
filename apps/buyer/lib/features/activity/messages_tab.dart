import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/models/conversation.dart';
import '../../data/providers/chat_providers.dart';
import '../../data/repositories/chat_repository.dart';
import 'activity_logic.dart';
import 'list_states.dart';

/// The Messages tab (spec 0008, AC-11, AC-13; spec 0011, AC-2): the buyer's
/// conversations with stores, newest first, 20 at a time, with pull to
/// refresh. Tapping a row opens the thread. The search field filters the rows
/// that are loaded.
///
/// With [role] `store` it is the seller's inbox (spec 0020, AC-1): the same
/// list of the customers who wrote to the store, opening
/// `/store/messages/:id`. A row with no photo shows the first letter of the
/// name.
class MessagesTab extends ConsumerWidget {
  const MessagesTab({
    super.key,
    required this.query,
    this.role = ChatRole.buyer,
  });

  final String query;
  final ChatRole role;

  AsyncNotifierProvider<ChatInboxNotifier, ChatInboxState> get _provider =>
      role == ChatRole.store ? storeInboxProvider : chatInboxProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_provider)
        .when(
          loading: () => const ListLoading(),
          error: (error, stackTrace) => ListMessage(
            "Couldn't load your messages.",
            buttonLabel: 'Try again',
            onPressed: () => ref.invalidate(_provider),
          ),
          data: (inbox) {
            if (inbox.conversations.isEmpty) {
              return role == ChatRole.store
                  ? const _EmptySellerInbox()
                  : const ListMessage('No messages yet');
            }
            final shown = filterConversations(
              newestConversationsFirst(inbox.conversations),
              query,
            );
            // With a search typed and nothing matching, the next page may
            // hold the match, so the footer stays.
            if (shown.isEmpty && !inbox.hasMore) {
              return ListMessage.noResults(query);
            }
            final footer = inbox.hasMore ? 1 : 0;
            return RefreshIndicator(
              onRefresh: () => ref.refresh(_provider.future),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.base),
                itemCount: shown.length + footer,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.base),
                itemBuilder: (context, index) {
                  if (index < shown.length) {
                    return _ConversationRow(
                      conversation: shown[index],
                      route: role == ChatRole.store
                          ? '/store/messages/${shown[index].id}'
                          : '/activity/chat/${shown[index].id}',
                    );
                  }
                  return _Footer(state: inbox, provider: _provider);
                },
              ),
            );
          },
        );
  }
}

/// The end of the list: a spinner while the next page loads, or a retry when
/// that load failed. The next page starts as soon as this row is built, which
/// happens only when the list has scrolled near its end.
class _Footer extends ConsumerWidget {
  const _Footer({required this.state, required this.provider});

  final ChatInboxState state;
  final AsyncNotifierProvider<ChatInboxNotifier, ChatInboxState> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loadMoreFailed) {
      return Center(
        child: TextButton(
          onPressed: () => ref.read(provider.notifier).loadMore(),
          child: const Text('Try again'),
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(provider.notifier).loadMore(),
    );
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.base),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Figma node 874:5784: a round store avatar, the store name over the last
/// message, and the time on the right. An unread row is all in the darker
/// text colour, a read one has a lighter message and time.
class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.route});

  final Conversation conversation;
  final String route;

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
        onTap: () => context.push(route),
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
                      ? ColoredBox(
                          color: AppColors.neutral200,
                          child: Center(
                            child: Text(
                              conversation.storeName.isEmpty
                                  ? ''
                                  : conversation.storeName
                                        .substring(0, 1)
                                        .toUpperCase(),
                              style: style(
                                AppColors.neutral700,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
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

/// The seller's inbox with no threads yet (spec 0020, AC-9).
class _EmptySellerInbox extends StatelessWidget {
  const _EmptySellerInbox();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No messages yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyDisplay,
                fontSize: AppTypography.sizeLg,
                height: AppTypography.lineHeightSm,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral1100,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'When a customer writes to your store,\nit shows up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeSm,
                height: AppTypography.lineHeightSm,
                color: AppColors.neutral500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
