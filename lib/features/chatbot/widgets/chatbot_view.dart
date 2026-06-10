import 'package:flutter/material.dart';

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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
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
    _scrollToBottom();

    try {
      final response = await widget.repository.sendMessage(
        message: text,
        conversationId: _conversationId,
        metadata: widget.metadata,
      );

      if (!mounted) {
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
      _scrollToBottom();
    } on ChatbotException catch (error) {
      _markFailed(userMessage, error.message);
    } on Object {
      _markFailed(userMessage, 'Có lỗi xảy ra. Vui lòng thử lại.');
    }
  }

  Future<void> _retryMessage(ChatMessage failedMessage) async {
    setState(() {
      _replaceMessage(
        failedMessage.id,
        failedMessage.copyWith(status: ChatStatus.sending, clearError: true),
      );
      _isBotTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await widget.repository.sendMessage(
        message: failedMessage.text,
        conversationId: _conversationId,
        metadata: widget.metadata,
      );

      if (!mounted) {
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
      _scrollToBottom();
    } on ChatbotException catch (error) {
      _markFailed(failedMessage, error.message);
    } on Object {
      _markFailed(failedMessage, 'Có lỗi xảy ra. Vui lòng thử lại.');
    }
  }

  void _markFailed(ChatMessage message, String errorMessage) {
    if (!mounted) {
      return;
    }
    setState(() {
      _replaceMessage(
        message.id,
        message.copyWith(status: ChatStatus.failed, errorMessage: errorMessage),
      );
      _isBotTyping = false;
    });
    _scrollToBottom();
  }

  void _replaceMessage(String id, ChatMessage nextMessage) {
    final index = _messages.indexWhere((message) => message.id == id);
    if (index == -1) {
      return;
    }
    _messages[index] = nextMessage;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
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
}
