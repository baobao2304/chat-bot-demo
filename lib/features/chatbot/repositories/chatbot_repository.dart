class ChatbotReply {
  const ChatbotReply({required this.reply, this.conversationId});

  final String reply;
  final String? conversationId;
}

class ChatbotException implements Exception {
  const ChatbotException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract class ChatbotRepository {
  Future<ChatbotReply> sendMessage({
    required String message,
    String? conversationId,
    Map<String, dynamic>? metadata,
  });
}
