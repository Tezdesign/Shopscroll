import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

import 'chat_logic.dart';

/// The message field of Figma nodes 874:5806 and 874:5937: a pill with the
/// hint "Type your message" and the send button at its right end. The send
/// button is on only when the trimmed text is not empty, and the field stops
/// at 2000 characters (AC-4).
///
/// Deviations from the frame: the emoji icon is the send button, and the mic
/// is left out (there are no voice notes; the photo button arrives with
/// photos).
class ChatComposer extends StatefulWidget {
  const ChatComposer({super.key, required this.onSend});

  final void Function(String text) onSend;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (!canSendChat(text)) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white100,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.sm,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.only(left: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              border: Border.all(color: AppColors.neutral300),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(maxChatBody),
                    ],
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamilyBody,
                      fontSize: AppTypography.sizeSm,
                      height: AppTypography.lineHeightSm,
                      color: AppColors.neutral1100,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Type your message',
                      hintStyle: TextStyle(
                        fontFamily: AppTypography.fontFamilyBody,
                        fontSize: AppTypography.sizeSm,
                        height: AppTypography.lineHeightSm,
                        color: AppColors.neutral700,
                      ),
                      // The app's input theme fills fields grey, but the pill
                      // around this one is the field (Figma 874:5806).
                      filled: false,
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final on = canSendChat(value.text);
                    return Semantics(
                      button: true,
                      enabled: on,
                      label: 'Send message',
                      excludeSemantics: true,
                      child: IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        onPressed: on ? _send : null,
                        icon: Icon(
                          Icons.send_rounded,
                          size: 24,
                          color: on
                              ? AppColors.primary400
                              : AppColors.neutral600,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
