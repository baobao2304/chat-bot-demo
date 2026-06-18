import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';
import 'features/chatbot/chatbot.dart';
import 'features/home/screens/home_screen.dart';

void main() {
  final appConfig = AppConfig.current;
  AppLogger.info('App', 'bootstrap', <String, Object?>{
    'verboseLogsEnabled': AppLogger.enabled,
    'environmentName': appConfig.environmentName,
    'baseUrl': appConfig.baseUrl,
    'chatbotWebViewUrl': appConfig.chatbotWebViewUrl,
    'startChatEndpoint': appConfig.startChatEndpoint,
    'connectInstanceId': appConfig.connectInstanceId,
    'contactFlowId': appConfig.contactFlowId,
    'awsRegion': appConfig.awsRegion,
    'customerName': appConfig.customerName,
    'connectDisableCsm': appConfig.connectDisableCsm,
    'connectReceiptsEnabled': appConfig.connectReceiptsEnabled,
    'connectReceiptThrottleSeconds': appConfig.connectReceiptThrottleSeconds,
    'connectDeliveredThrottleSeconds':
        appConfig.connectDeliveredThrottleSeconds,
  });

  runApp(ChatbotDemoApp(appConfig: appConfig));
}

class ChatbotDemoApp extends StatelessWidget {
  const ChatbotDemoApp({super.key, required this.appConfig});

  final AppConfig appConfig;

  @override
  Widget build(BuildContext context) {
    AppLogger.trace('App', 'ChatbotDemoApp build');
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
      home: HomeScreen(
        appConfig: appConfig,
        createChatbotRepository: _buildRepository,
      ),
    );
  }

  ChatbotRepository _buildRepository() {
    AppLogger.info('App', 'build chatbot repository', <String, Object?>{
      'kIsWeb': kIsWeb,
      'defaultTargetPlatform': defaultTargetPlatform.name,
      'hasAmazonConnectConfig': appConfig.hasAmazonConnectConfig,
      'hasChatbotWebViewConfig': appConfig.hasChatbotWebViewConfig,
    });
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      AppLogger.info('App', 'using AmazonConnectChatbotRepository');
      return AmazonConnectChatbotRepository(
        startChatEndpoint: appConfig.startChatEndpoint,
        connectInstanceId: appConfig.connectInstanceId,
        contactFlowId: appConfig.contactFlowId,
        awsRegion: appConfig.awsRegion,
        customerName: appConfig.customerName,
        disableCsm: appConfig.connectDisableCsm,
        receiptsEnabled: appConfig.connectReceiptsEnabled,
        receiptThrottleSeconds: appConfig.connectReceiptThrottleSeconds,
        deliveredThrottleSeconds: appConfig.connectDeliveredThrottleSeconds,
      );
    }

    AppLogger.info('App', 'using HttpChatbotRepository fallback');
    return HttpChatbotRepository(baseUrl: appConfig.baseUrl);
  }
}
