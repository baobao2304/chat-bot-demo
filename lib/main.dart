import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'features/chatbot/chatbot.dart';

void main() {
  final appConfig = AppConfig.current;

  runApp(ChatbotDemoApp(chatbotApiBaseUrl: appConfig.baseUrl));
}

class ChatbotDemoApp extends StatelessWidget {
  const ChatbotDemoApp({super.key, required this.chatbotApiBaseUrl});

  final String chatbotApiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chatbot Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
        ),
      ),
      home: ChatbotScreen(
        repository: HttpChatbotRepository(baseUrl: chatbotApiBaseUrl),
        metadata: const <String, dynamic>{
          'app': 'chatbotdemo',
          'domain': 'banking-demo',
        },
      ),
    );
  }
}
