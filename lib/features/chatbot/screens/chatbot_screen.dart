import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/logging/app_logger.dart';
import '../repositories/chatbot_repository.dart';
import '../widgets/chatbot_view.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({
    super.key,
    required this.repository,
    this.title = 'Chatbot Demo',
    this.conversationId,
    this.metadata = const <String, dynamic>{},
    this.disposeRepository = false,
  });

  final ChatbotRepository repository;
  final String title;
  final String? conversationId;
  final Map<String, dynamic> metadata;
  final bool disposeRepository;

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  @override
  void initState() {
    super.initState();
    AppLogger.info('ChatbotScreen', 'initState', <String, Object?>{
      'title': widget.title,
      'conversationId': widget.conversationId,
      'metadata': widget.metadata,
      'disposeRepository': widget.disposeRepository,
      'repositoryType': widget.repository.runtimeType.toString(),
    });
  }

  @override
  void dispose() {
    AppLogger.info('ChatbotScreen', 'dispose', <String, Object?>{
      'disposeRepository': widget.disposeRepository,
      'repositoryType': widget.repository.runtimeType.toString(),
    });
    if (widget.disposeRepository &&
        widget.repository is DisposableChatbotRepository) {
      AppLogger.info('ChatbotScreen', 'disposing owned repository');
      unawaited((widget.repository as DisposableChatbotRepository).dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.trace('ChatbotScreen', 'build', <String, Object?>{
      'title': widget.title,
      'conversationId': widget.conversationId,
      'metadata': widget.metadata,
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: Icon(
                Icons.circle,
                size: 10,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: const Text('Online'),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: ChatbotView(
        repository: widget.repository,
        conversationId: widget.conversationId,
        metadata: widget.metadata,
      ),
    );
  }
}
