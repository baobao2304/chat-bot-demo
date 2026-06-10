import 'package:flutter/material.dart';

import '../repositories/chatbot_repository.dart';
import '../widgets/chatbot_view.dart';

class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({
    super.key,
    required this.repository,
    this.title = 'Chatbot Demo',
    this.conversationId,
    this.metadata = const <String, dynamic>{},
  });

  final ChatbotRepository repository;
  final String title;
  final String? conversationId;
  final Map<String, dynamic> metadata;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
        repository: repository,
        conversationId: conversationId,
        metadata: metadata,
      ),
    );
  }
}
