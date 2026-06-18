import 'package:chatbotdemo/core/config/app_config.dart';
import 'package:chatbotdemo/features/chatbot/chatbot.dart';
import 'package:chatbotdemo/features/home/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home shows both chatbot entry points', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          appConfig: AppConfig.current,
          createChatbotRepository: () =>
              const MockChatbotRepository(delay: Duration.zero),
        ),
      ),
    );

    expect(find.text('WebView Chatbot'), findsOneWidget);
    expect(find.text('Native Chatbot'), findsOneWidget);
  });

  testWidgets('home opens native chatbot with a new repository', (
    tester,
  ) async {
    var createdRepositories = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          appConfig: AppConfig.current,
          createChatbotRepository: () {
            createdRepositories += 1;
            return const MockChatbotRepository(delay: Duration.zero);
          },
        ),
      ),
    );

    await tester.tap(find.text('Native Chatbot'));
    await tester.pumpAndSettle();

    expect(createdRepositories, 1);
    expect(find.byType(ChatbotScreen), findsOneWidget);
  });

  testWidgets('webview chatbot reports missing url config', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatbotWebViewScreen(url: '')),
    );

    expect(find.text('WebView Chatbot'), findsOneWidget);
    expect(
      find.text('Thiếu cấu hình CHATBOT_WEBVIEW_URL hoặc URL không hợp lệ.'),
      findsOneWidget,
    );
  });

  testWidgets('chatbot screen disposes owned repository', (tester) async {
    final repository = _DisposableRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ChatbotScreen(repository: repository, disposeRepository: true),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(repository.disposed, isTrue);
  });
}

class _DisposableRepository
    implements ChatbotRepository, DisposableChatbotRepository {
  bool disposed = false;

  @override
  Future<ChatbotReply> sendMessage({
    required String message,
    String? conversationId,
    Map<String, dynamic>? metadata,
  }) async {
    return ChatbotReply(reply: message, conversationId: conversationId);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
