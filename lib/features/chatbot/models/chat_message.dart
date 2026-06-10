enum ChatRole { user, assistant, system }

enum ChatStatus { sending, sent, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    required this.createdAt,
    this.status = ChatStatus.sent,
    this.errorMessage,
  });

  final String id;
  final String text;
  final ChatRole role;
  final DateTime createdAt;
  final ChatStatus status;
  final String? errorMessage;

  bool get isUser => role == ChatRole.user;
  bool get isAssistant => role == ChatRole.assistant;
  bool get isFailed => status == ChatStatus.failed;

  ChatMessage copyWith({
    String? id,
    String? text,
    ChatRole? role,
    DateTime? createdAt,
    ChatStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
