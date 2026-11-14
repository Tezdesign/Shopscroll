import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/models/chat_message.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';

import '../../core/area/app_area.dart';
import '../../data/providers/chat_providers.dart';
import '../../data/repositories/chat_repository.dart';
import '../activity/list_states.dart';
import '../store/store_page_screen.dart' show abbreviatedFollowerCount;
import 'chat_bubble.dart';
import 'chat_composer.dart';
import 'chat_logic.dart';

/// The chat thread with one store (spec 0011, AC-1, AC-3, AC-4, AC-19, AC-20),
/// or, as [ChatRole.store], with one customer (spec 0020, AC-3, AC-5). Open it
/// by [conversationId] from the Messages tab, by [storeId] from "Chat now" and
/// "Message", or by [orderId] from "Message customer" on an order, where the
/// thread may not exist yet. Nothing is stored until the first message is
/// sent.
///
/// Figma nodes 874:5806 (empty) and 874:5937 (with messages): a back arrow, the
/// store avatar and name (a tap opens the Store Page), the messages and the
/// composer. Deviations from the frames: no phone icon (there are no calls),
/// and the screen adds a log in prompt, a failure state and the retry line for
/// a message that was not sent, none of which the frames draw.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({
    super.key,
    this.conversationId,
    this.storeId,
    this.orderId,
    this.role = ChatRole.buyer,
  }) : assert(
         (conversationId != null ? 1 : 0) +
                 (storeId != null ? 1 : 0) +
                 (orderId != null ? 1 : 0) ==
             1,
         'Name a thread, a store or an order, exactly one.',
       );

  final String? conversationId;
  final String? storeId;
  final String? orderId;
  final ChatRole role;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _scroll = ScrollController();

  ChatTarget get _target => (
    conversationId: widget.conversationId,
    storeId: widget.storeId,
    orderId: widget.orderId,
    role: widget.role,
  );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        ref.read(chatThreadProvider(_target).notifier).loadOlder();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _report(Future<ChatFailure?> sent) async {
    final failure = await sent;
    if (!mounted || failure == null || failure == ChatFailure.failed) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_failureText(failure))));
  }

  /// A store's refusal to start is worded for a store (spec 0020, AC-6).
  String _failureText(ChatFailure failure) =>
      widget.role == ChatRole.store && failure == ChatFailure.notAllowed
      ? "You can't start new conversations"
      : chatFailureText(failure);

  @override
  Widget build(BuildContext context) {
    final visitor = ref.watch(chatVisitorProvider);
    final thread = visitor ? null : ref.watch(chatThreadProvider(_target));
    final data = thread?.value;

    return Scaffold(
      backgroundColor: AppColors.white100,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              name: data?.info.otherName ?? '',
              avatarUrl: data?.info.otherAvatarUrl,
              storeId: data?.info.otherId,
              backTo: widget.role == ChatRole.store
                  ? '/store/messages'
                  : '/activity',
            ),
            Expanded(
              child: visitor
                  ? const _LogInPrompt()
                  : thread!.when(
                      loading: () => const ListLoading(),
                      error: (error, stackTrace) => _failure(error),
                      data: (state) => _messages(state),
                    ),
            ),
            if (data != null)
              ChatComposer(
                onSend: (text) => _report(
                  ref.read(chatThreadProvider(_target).notifier).send(text),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _failure(Object error) {
    if (error is ChatException && error.reason == ChatFailure.notAllowed) {
      return ListMessage(_failureText(ChatFailure.notAllowed));
    }
    return ListMessage(
      "Couldn't load this chat.",
      buttonLabel: 'Try again',
      onPressed: () => ref.invalidate(chatThreadProvider(_target)),
    );
  }

  Widget _messages(ChatThreadState state) {
    final all = state.all;
    if (all.isEmpty) return _EmptyThread(state: state, role: widget.role);

    final info = state.info;
    final notifier = ref.read(chatThreadProvider(_target).notifier);
    final newestFirst = all.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: newestFirst.length + (state.loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == newestFirst.length) return const ListLoading();
        final message = newestFirst[index];
        final mine = notifier.isMine(message);
        // The list is newest first, so the message before this one in time is
        // the next index.
        final earlier = index + 1 < newestFirst.length
            ? newestFirst[index + 1]
            : null;
        final startsRun = earlier == null || notifier.isMine(earlier) != mine;
        return ChatBubble(
          key: ValueKey(message.id),
          message: message,
          mine: mine,
          otherName: info.otherName,
          otherAvatarUrl: info.otherAvatarUrl,
          showAvatar: startsRun,
          onRetry: message.status == ChatMessageStatus.failed
              ? () => _report(notifier.retry(message.id))
              : null,
          onRemove: message.status == ChatMessageStatus.failed
              ? () => _confirmRemove(notifier, message.id)
              : null,
        );
      },
    );
  }

  Future<void> _confirmRemove(ChatThreadNotifier notifier, String id) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Remove'),
          onTap: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (remove == true) notifier.remove(id);
  }
}

/// The back arrow, the store avatar and the name (Figma node 874:5948). The
/// avatar and name open the Store Page once the store is known.
class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    this.avatarUrl,
    this.storeId,
    required this.backTo,
  });

  final String name;
  final String? avatarUrl;
  final String? storeId;

  /// Where Back goes when there is nothing to pop.
  final String backTo;

  @override
  Widget build(BuildContext context) {
    final open = storeId == null
        ? null
        : () => context.push('/store/$storeId');
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  context.canPop() ? context.pop() : context.go(backTo),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.chevron_left, size: 28),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              button: open != null,
              label: name.isEmpty ? null : '$name, open store page',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: open,
                child: Row(
                  children: [
                    ChatAvatar(url: avatarUrl, size: 30),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamilyDisplay,
                          fontSize: AppTypography.sizeLg,
                          height: AppTypography.lineHeightLg,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral1100,
                        ),
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

/// The thread with nothing in it yet (Figma node 874:5806): the store avatar,
/// name, abbreviated follower count and "Ask NAME about anything you want"
/// (AC-3).
class _EmptyThread extends StatelessWidget {
  const _EmptyThread({required this.state, required this.role});

  final ChatThreadState state;
  final ChatRole role;

  @override
  Widget build(BuildContext context) {
    final info = state.info;
    final followers = info.otherFollowerCount;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatAvatar(url: info.otherAvatarUrl, size: 80),
            const SizedBox(height: AppSpacing.md),
            Text(
              info.otherName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamilyDisplay,
                fontSize: AppTypography.sizeXl,
                height: AppTypography.lineHeightXl,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral1100,
              ),
            ),
            if (followers != null)
              Text(
                '${abbreviatedFollowerCount(followers)} followers',
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamilyBody,
                  fontSize: AppTypography.sizeSm,
                  height: AppTypography.lineHeightSm,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral700,
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              role == ChatRole.store
                  ? 'Say hello to ${info.otherName}'
                  : 'Ask ${info.otherName} about anything you want',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamilyDisplay,
                fontSize: AppTypography.sizeLg,
                height: AppTypography.lineHeightLg,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral1100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a visitor sees instead of the thread: a Log in button that comes back
/// to this same page afterwards (AC-1).
class _LogInPrompt extends ConsumerWidget {
  const _LogInPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Log in to message this store',
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.neutral1100,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Log in',
              onPressed: () {
                ref.read(loginReturnPathProvider.notifier).state = GoRouterState
                    .of(context)
                    .uri
                    .toString();
                context.push('/welcome');
              },
            ),
          ],
        ),
      ),
    );
  }
}
