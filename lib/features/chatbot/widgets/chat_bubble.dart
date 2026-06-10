import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import 'chat_message_content.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? colorScheme.primary
        : message.isFailed
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerHighest;
    final textColor = isUser
        ? colorScheme.onPrimary
        : message.isFailed
        ? colorScheme.onErrorContainer
        : colorScheme.onSurface;

    final maxBubbleWidth = isUser
        ? 320.0
        : MediaQuery.sizeOf(context).width * 0.88;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isAssistant && !message.isFailed)
                    ChatMessageContent(text: message.text, textColor: textColor)
                  else
                    Text(
                      message.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        height: 1.35,
                      ),
                    ),
                  if (message.status == ChatStatus.sending) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Đang gửi...',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: textColor.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                  if (message.isFailed) ...[
                    const SizedBox(height: 8),
                    Text(
                      message.errorMessage ?? 'Gửi thất bại.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: textColor.withValues(alpha: 0.85),
                      ),
                    ),
                    if (onRetry != null)
                      TextButton.icon(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          foregroundColor: textColor,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Gửi lại'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
