import 'dart:async';

import 'chatbot_repository.dart';

class MockChatbotRepository implements ChatbotRepository {
  const MockChatbotRepository({this.delay = const Duration(milliseconds: 700)});

  final Duration delay;

  @override
  Future<ChatbotReply> sendMessage({
    required String message,
    String? conversationId,
    Map<String, dynamic>? metadata,
  }) async {
    await Future<void>.delayed(delay);

    final normalized = message.trim().toLowerCase();
    final reply = switch (normalized) {
      '' => 'Bạn nhập nội dung cần hỏi nhé.',
      String text when text.contains('hello') || text.contains('xin chào') =>
        'Xin chào 👋 Mình là chatbot demo. Bạn có thể thay MockChatbotRepository bằng HttpChatbotRepository để gọi backend thật.',
      String text
          when text.contains('tích hợp') || text.contains('integrate') =>
        'Để tích hợp app khác: copy thư mục lib/features/chatbot, rồi truyền repository backend của bạn vào ChatbotScreen hoặc ChatbotView.',
      String text when text.contains('api') || text.contains('backend') =>
        'Backend mẫu dùng POST /chat/messages với body gồm message, conversationId và metadata; response trả reply và conversationId.',
      _ =>
        'Mình đã nhận: "$message". Đây là phản hồi mock để bạn demo UI trước khi nối backend thật.',
    };

    return ChatbotReply(
      reply: reply,
      conversationId: conversationId ?? 'demo-conversation',
    );
  }
}
