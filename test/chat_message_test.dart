import 'package:chatbotdemo/features/chatbot/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copyWith can clear an existing error', () {
    final failedMessage = ChatMessage(
      id: 'message-1',
      text: 'Hello',
      role: ChatRole.user,
      createdAt: DateTime.utc(2026, 6, 17),
      status: ChatStatus.failed,
      errorMessage: 'Failed',
    );

    final retriedMessage = failedMessage.copyWith(
      status: ChatStatus.sending,
      clearError: true,
    );

    expect(retriedMessage.status, ChatStatus.sending);
    expect(retriedMessage.errorMessage, isNull);
  });
}
