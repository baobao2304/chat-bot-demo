import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/logging_http_client.dart';
import 'chatbot_repository.dart';

class HttpChatbotRepository
    implements ChatbotRepository, DisposableChatbotRepository {
  HttpChatbotRepository({
    required this.baseUrl,
    http.Client? client,
    this.path = '/chat/messages',
    this.timeout = const Duration(seconds: 30),
    this.headers = const <String, String>{},
  }) : _client =
           client ??
           LoggingHttpClient(http.Client(), tag: 'HttpChatbotRepository'),
       _ownsClient = client == null {
    AppLogger.info('HttpChatbotRepository', 'created', <String, Object?>{
      'baseUrl': baseUrl,
      'path': path,
      'timeoutMs': timeout.inMilliseconds,
      'headers': headers,
      'ownsClient': _ownsClient,
    });
  }

  final String baseUrl;
  final String path;
  final Duration timeout;
  final Map<String, String> headers;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<ChatbotReply> sendMessage({
    required String message,
    String? conversationId,
    Map<String, dynamic>? metadata,
  }) async {
    AppLogger.start(
      'HttpChatbotRepository',
      'repository sendMessage flow',
      <String, Object?>{
        'message': message,
        'conversationId': conversationId,
        'metadata': metadata,
      },
    );

    try {
      final uri = _buildUri();
      final requestBody = <String, dynamic>{
        'message': message,
        'conversationId': ?conversationId,
        'metadata': <String, dynamic>{'platform': 'flutter', ...?metadata},
      };

      AppLogger.step(
        'HttpChatbotRepository',
        'request prepared',
        <String, Object?>{'uri': uri.toString(), 'body': requestBody},
      );

      final response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...headers,
            },
            body: jsonEncode(requestBody),
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
        AppLogger.warning(
          'HttpChatbotRepository',
          'invalid backend response shape',
          data: <String, Object?>{'decoded': decoded},
        );
        throw const ChatbotException('Response backend không đúng định dạng.');
      }

      final reply = decoded['reply'];
      if (reply is! String || reply.trim().isEmpty) {
        AppLogger.warning(
          'HttpChatbotRepository',
          'backend response missing reply',
          data: decoded,
        );
        throw const ChatbotException(
          'Response backend thiếu trường reply hoặc reply rỗng.',
        );
      }

      final nextConversationId = decoded['conversationId'];
      final chatbotReply = ChatbotReply(
        reply: reply,
        conversationId:
            nextConversationId is String && nextConversationId.isNotEmpty
            ? nextConversationId
            : conversationId,
      );
      AppLogger.success(
        'HttpChatbotRepository',
        'repository sendMessage flow completed',
        <String, Object?>{
          'reply': chatbotReply.reply,
          'conversationId': chatbotReply.conversationId,
        },
      );
      return chatbotReply;
    } on ChatbotException {
      AppLogger.warning(
        'HttpChatbotRepository',
        'repository sendMessage flow failed: chatbot exception',
      );
      rethrow;
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.failure(
        'HttpChatbotRepository',
        'repository sendMessage flow failed: timeout',
        data: <String, Object?>{'timeoutMs': timeout.inMilliseconds},
        error: error,
        stackTrace: stackTrace,
      );
      throw ChatbotException(
        'Backend phản hồi quá lâu. Vui lòng thử lại.',
        cause: error,
      );
    } on FormatException catch (error, stackTrace) {
      AppLogger.failure(
        'HttpChatbotRepository',
        'repository sendMessage flow failed: format exception',
        error: error,
        stackTrace: stackTrace,
      );
      throw ChatbotException(
        'Không đọc được response từ backend.',
        cause: error,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.failure(
        'HttpChatbotRepository',
        'repository sendMessage flow failed: unexpected error',
        data: <String, Object?>{'baseUrl': baseUrl, 'path': path},
        error: error,
        stackTrace: stackTrace,
      );
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
    final uri = Uri.parse('$normalizedBase$normalizedPath');
    AppLogger.debug('HttpChatbotRepository', 'built uri', uri.toString());
    return uri;
  }

  @override
  Future<void> dispose() async {
    AppLogger.info('HttpChatbotRepository', 'dispose', <String, Object?>{
      'ownsClient': _ownsClient,
    });
    if (_ownsClient) {
      _client.close();
    }
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
