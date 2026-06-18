import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logging/app_logger.dart';
import '../../chatbot/chatbot.dart';

typedef ChatbotRepositoryFactory = ChatbotRepository Function();

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.appConfig,
    required this.createChatbotRepository,
  });

  final AppConfig appConfig;
  final ChatbotRepositoryFactory createChatbotRepository;

  @override
  Widget build(BuildContext context) {
    AppLogger.trace('HomeScreen', 'build', <String, Object?>{
      'environmentName': appConfig.environmentName,
      'hasAmazonConnectConfig': appConfig.hasAmazonConnectConfig,
      'hasChatbotWebViewConfig': appConfig.hasChatbotWebViewConfig,
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Chatbot Demo'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HomeDestinationTile(
            icon: Icons.web_asset_outlined,
            title: 'WebView Chatbot',
            subtitle: 'Mở chatbot web trong app',
            onTap: () => _openWebViewChatbot(context),
          ),
          const SizedBox(height: 12),
          _HomeDestinationTile(
            icon: Icons.chat_bubble_outline,
            title: 'Native Chatbot',
            subtitle: 'Mở chatbot native hiện tại',
            onTap: () => _openNativeChatbot(context),
          ),
        ],
      ),
    );
  }

  void _openWebViewChatbot(BuildContext context) {
    AppLogger.info('HomeScreen', 'open WebView chatbot', <String, Object?>{
      'url': appConfig.chatbotWebViewUrl,
    });
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatbotWebViewScreen(url: appConfig.chatbotWebViewUrl),
      ),
    );
  }

  void _openNativeChatbot(BuildContext context) {
    const metadata = <String, dynamic>{
      'app': 'chatbotdemo',
      'domain': 'banking-demo',
    };
    AppLogger.info('HomeScreen', 'open native chatbot', <String, Object?>{
      'metadata': metadata,
    });
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatbotScreen(
          repository: createChatbotRepository(),
          disposeRepository: true,
          metadata: metadata,
        ),
      ),
    );
  }
}

class _HomeDestinationTile extends StatelessWidget {
  const _HomeDestinationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
