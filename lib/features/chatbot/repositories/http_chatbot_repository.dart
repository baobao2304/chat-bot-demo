
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'chatbot_repository.dart';

class HttpChatbotRepository implements ChatbotRepository {
  HttpChatbotRepository({
    required this.baseUrl,
    http.Client? client,
    this.path = '/chat/messages',
    this.timeout = const Duration(seconds: 30),
    this.headers = const <String, String>{},
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String path;
  final Duration timeout;
  final Map<String, String> headers;
  final http.Client _client;

  @override
  Future<ChatbotReply> sendMessage({
    required String message,
    String? conversationId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final uri = _buildUri();
      final response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...headers,
            },
            body: jsonEncode(<String, dynamic>{
              'message': message,
              'conversationId': ?conversationId,
              'metadata': <String, dynamic>{
                'platform': 'flutter',
                ...?metadata,
              },
            }),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ChatbotException(
          _extractErrorMessage(response.body) ??
              'Backend đang lỗi (${response.statusCode}). Vui lòng thử lại.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ChatbotException('Response backend không đúng định dạng.');
      }

      final reply = decoded['reply'];
      if (reply is! String || reply.trim().isEmpty) {
        throw const ChatbotException(
          'Response backend thiếu trường reply hoặc reply rỗng.',
        );
      }

      final nextConversationId = decoded['conversationId'];
      return ChatbotReply(
        reply: reply,
        conversationId:
            nextConversationId is String && nextConversationId.isNotEmpty
            ? nextConversationId
            : conversationId,
      );
    } on ChatbotException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ChatbotException(
        'Backend phản hồi quá lâu. Vui lòng thử lại.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw ChatbotException(
        'Không đọc được response từ backend.',
        cause: error,
      );
    } on Object catch (error) {
      throw ChatbotException(
        'Không kết nối được backend. Kiểm tra mạng hoặc baseUrl.',
        cause: error,
      );
    }
  }

  Uri _buildUri() {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  String? _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } on Object {
      return null;
    }
    return null;
  }
}
