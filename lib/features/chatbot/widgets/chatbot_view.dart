import 'package:flutter/material.dart';

import '../../../core/logging/app_logger.dart';
import '../models/chat_message.dart';
import '../repositories/chatbot_repository.dart';
import 'chat_bubble.dart';
import 'chat_input_bar.dart';
import 'typing_indicator.dart';

class ChatbotView extends StatefulWidget {
  const ChatbotView({
    super.key,
    required this.repository,
    this.initialMessages = const <ChatMessage>[],
    this.conversationId,
    this.metadata = const <String, dynamic>{},
    this.welcomeMessage =
        'Xin chào 👋 Mình là chatbot demo. Hãy hỏi mình bất cứ điều gì nhé.',
  });

  final ChatbotRepository repository;
  final List<ChatMessage> initialMessages;
  final String? conversationId;
  final Map<String, dynamic> metadata;
  final String? welcomeMessage;

  @override
  State<ChatbotView> createState() => _ChatbotViewState();
}

class _ChatbotViewState extends State<ChatbotView> {
  final _scrollController = ScrollController();
  late final List<ChatMessage> _messages;
  String? _conversationId;
  bool _isBotTyping = false;
  int _messageSequence = 0;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _messages = <ChatMessage>[
      if (widget.welcomeMessage != null)
        ChatMessage(
          id: _newId('welcome'),
          text: widget.welcomeMessage!,
          role: ChatRole.assistant,
          createdAt: DateTime.now(),
        ),
      ...widget.initialMessages,
    ];
    AppLogger.info('ChatbotView', 'initState', <String, Object?>{
      'conversationId': _conversationId,
      'metadata': widget.metadata,
      'initialMessages': widget.initialMessages
          .map(_messageLogData)
          .toList(growable: false),
      'welcomeMessage': widget.welcomeMessage,
      'messageCount': _messages.length,
    });
  }

  @override
  void dispose() {
    AppLogger.info('ChatbotView', 'dispose', <String, Object?>{
      'conversationId': _conversationId,
      'messageCount': _messages.length,
      'isBotTyping': _isBotTyping,
    });
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    AppLogger.start('ChatbotView', 'UI send message flow', <String, Object?>{
      'text': text,
      'conversationId': _conversationId,
      'metadata': widget.metadata,
      'messageCountBefore': _messages.length,
    });
    final userMessage = ChatMessage(
      id: _newId('user'),
      text: text,
      role: ChatRole.user,
      createdAt: DateTime.now(),
      status: ChatStatus.sending,
    );

    setState(() {
      _messages.add(userMessage);
      _isBotTyping = true;
    });
    AppLogger.step(
      'ChatbotView',
      'append user message to UI',
      <String, Object?>{
        'message': _messageLogData(userMessage),
        'messageCount': _messages.length,
        'isBotTyping': _isBotTyping,
      },
    );
    _scrollToBottom();

    try {
      final response = await widget.repository.sendMessage(
        message: text,
        conversationId: _conversationId,
        metadata: widget.metadata,
      );

      if (!mounted) {
        AppLogger.warning(
          'ChatbotView',
          'sendMessage completed after widget unmounted',
          data: <String, Object?>{'response': _replyLogData(response)},
        );
        return;
      }

      setState(() {
        _conversationId = response.conversationId ?? _conversationId;
        _replaceMessage(
          userMessage.id,
          userMessage.copyWith(status: ChatStatus.sent, clearError: true),
        );
        _messages.add(
          ChatMessage(
            id: _newId('bot'),
            text: response.reply,
            role: ChatRole.assistant,
            createdAt: DateTime.now(),
          ),
        );
        _isBotTyping = false;
      });
      AppLogger.success(
        'ChatbotView',
        'UI send message flow completed',
        <String, Object?>{
          'response': _replyLogData(response),
          'conversationId': _conversationId,
          'messageCount': _messages.length,
        },
      );
      _scrollToBottom();
    } on ChatbotException catch (error, stackTrace) {
      AppLogger.warning(
        'ChatbotView',
        'sendMessage chatbot exception',
        data: <String, Object?>{
          'message': _messageLogData(userMessage),
          'errorMessage': error.message,
          'cause': error.cause?.toString(),
        },
        error: error,
        stackTrace: stackTrace,
      );
      _markFailed(userMessage, error.message);
    } on Object catch (error, stackTrace) {
      AppLogger.failure(
        'ChatbotView',
        'UI send message flow failed: unexpected exception',
        data: <String, Object?>{'message': _messageLogData(userMessage)},
        error: error,
        stackTrace: stackTrace,
      );
      _markFailed(userMessage, 'Có lỗi xảy ra. Vui lòng thử lại.');
    }
  }

  Future<void> _retryMessage(ChatMessage failedMessage) async {
    AppLogger.start('ChatbotView', 'UI retry message flow', <String, Object?>{
      'message': _messageLogData(failedMessage),
      'conversationId': _conversationId,
      'metadata': widget.metadata,
    });
    setState(() {
      _replaceMessage(
        failedMessage.id,
        failedMessage.copyWith(status: ChatStatus.sending, clearError: true),
      );
      _isBotTyping = true;
    });
    AppLogger.step('ChatbotView', 'retry state updated', <String, Object?>{
      'message': _messageLogData(failedMessage),
      'isBotTyping': _isBotTyping,
    });
    _scrollToBottom();

    try {
      final response = await widget.repository.sendMessage(
        message: failedMessage.text,
        conversationId: _conversationId,
        metadata: widget.metadata,
      );

      if (!mounted) {
        AppLogger.warning(
          'ChatbotView',
          'retry completed after widget unmounted',
          data: <String, Object?>{'response': _replyLogData(response)},
        );
        return;
      }

      setState(() {
        _conversationId = response.conversationId ?? _conversationId;
        _replaceMessage(
          failedMessage.id,
          failedMessage.copyWith(status: ChatStatus.sent, clearError: true),
        );
        _messages.add(
          ChatMessage(
            id: _newId('bot'),
            text: response.reply,
            role: ChatRole.assistant,
            createdAt: DateTime.now(),
          ),
        );
        _isBotTyping = false;
      });
      AppLogger.success(
        'ChatbotView',
        'UI retry message flow completed',
        <String, Object?>{
          'response': _replyLogData(response),
          'conversationId': _conversationId,
          'messageCount': _messages.length,
        },
      );
      _scrollToBottom();
    } on ChatbotException catch (error, stackTrace) {
      AppLogger.warning(
        'ChatbotView',
        'retry chatbot exception',
        data: <String, Object?>{
          'message': _messageLogData(failedMessage),
          'errorMessage': error.message,
          'cause': error.cause?.toString(),
        },
        error: error,
        stackTrace: stackTrace,
      );
      _markFailed(failedMessage, error.message);
    } on Object catch (error, stackTrace) {
      AppLogger.failure(
        'ChatbotView',
        'UI retry message flow failed: unexpected exception',
        data: <String, Object?>{'message': _messageLogData(failedMessage)},
        error: error,
        stackTrace: stackTrace,
      );
      _markFailed(failedMessage, 'Có lỗi xảy ra. Vui lòng thử lại.');
    }
  }

  void _markFailed(ChatMessage message, String errorMessage) {
    if (!mounted) {
      AppLogger.warning('ChatbotView', 'markFailed skipped after unmount');
      return;
    }
    setState(() {
      _replaceMessage(
        message.id,
        message.copyWith(status: ChatStatus.failed, errorMessage: errorMessage),
      );
      _isBotTyping = false;
    });
    AppLogger.warning(
      'ChatbotView',
      'message marked failed',
      data: <String, Object?>{
        'message': _messageLogData(message),
        'errorMessage': errorMessage,
        'isBotTyping': _isBotTyping,
      },
    );
    _scrollToBottom();
  }

  void _replaceMessage(String id, ChatMessage nextMessage) {
    final index = _messages.indexWhere((message) => message.id == id);
    if (index == -1) {
      AppLogger.warning(
        'ChatbotView',
        'replaceMessage target missing',
        data: {'id': id, 'nextMessage': _messageLogData(nextMessage)},
      );
      return;
    }
    AppLogger.trace('ChatbotView', 'replaceMessage', <String, Object?>{
      'id': id,
      'previousMessage': _messageLogData(_messages[index]),
      'nextMessage': _messageLogData(nextMessage),
    });
    _messages[index] = nextMessage;
  }

  void _scrollToBottom() {
    AppLogger.trace('ChatbotView', 'schedule scroll to bottom');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        AppLogger.trace('ChatbotView', 'scroll skipped; no clients');
        return;
      }
      AppLogger.trace('ChatbotView', 'scroll to bottom', <String, Object?>{
        'maxScrollExtent': _scrollController.position.maxScrollExtent,
      });
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_messageSequence++}';

  @override
  Widget build(BuildContext context) {
    AppLogger.trace('ChatbotView', 'build', <String, Object?>{
      'conversationId': _conversationId,
      'messageCount': _messages.length,
      'isBotTyping': _isBotTyping,
    });
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: colorScheme.surface,
            child: ListView.builder(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _messages.length + (_isBotTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const TypingIndicator();
                }

                final message = _messages[index];
                return ChatBubble(
                  message: message,
                  onRetry: message.isFailed
                      ? () => _retryMessage(message)
                      : null,
                );
              },
            ),
          ),
        ),
        ChatInputBar(enabled: !_isBotTyping, onSend: _sendMessage),
      ],
    );
  }

  Map<String, Object?> _messageLogData(ChatMessage message) {
    return <String, Object?>{
      'id': message.id,
      'text': message.text,
      'role': message.role.name,
      'status': message.status.name,
      'errorMessage': message.errorMessage,
      'createdAt': message.createdAt.toIso8601String(),
    };
  }

  Map<String, Object?> _replyLogData(ChatbotReply reply) {
    return <String, Object?>{
      'reply': reply.reply,
      'conversationId': reply.conversationId,
    };
  }
}
