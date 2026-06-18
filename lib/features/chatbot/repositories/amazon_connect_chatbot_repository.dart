import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:amazon_connect_chat_flutter/amazon_connect_chat_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/logging_http_client.dart';
import 'chatbot_repository.dart';

class AmazonConnectChatbotRepository
    implements ChatbotRepository, DisposableChatbotRepository {
  AmazonConnectChatbotRepository({
    required this.startChatEndpoint,
    required this.connectInstanceId,
    required this.contactFlowId,
    required this.awsRegion,
    required this.customerName,
    this.disableCsm = false,
    this.receiptsEnabled = true,
    this.receiptThrottleSeconds = 5.0,
    this.deliveredThrottleSeconds = 3.0,
    this.supportedMessagingContentTypes = const <String>[
      AmazonConnectContentType.plainText,
      AmazonConnectContentType.richText,
      AmazonConnectContentType.interactiveText,
    ],
    this.replyTimeout = const Duration(seconds: 90),
    AmazonConnectChatClient? client,
    http.Client? httpClient,
  }) : _client = client ?? AmazonConnectChatClient(),
       _httpClient =
           httpClient ??
           LoggingHttpClient(http.Client(), tag: 'AmazonConnectStartChatHttp') {
    AppLogger.info(
      'AmazonConnectChatbotRepository',
      'created',
      <String, Object?>{
        'startChatEndpoint': startChatEndpoint,
        'connectInstanceId': connectInstanceId,
        'contactFlowId': contactFlowId,
        'awsRegion': awsRegion,
        'customerName': customerName,
        'disableCsm': disableCsm,
        'receiptsEnabled': receiptsEnabled,
        'receiptThrottleSeconds': receiptThrottleSeconds,
        'deliveredThrottleSeconds': deliveredThrottleSeconds,
        'supportedMessagingContentTypes': supportedMessagingContentTypes,
        'replyTimeoutMs': replyTimeout.inMilliseconds,
        'ownsHttpClient': httpClient == null,
      },
    );
    _messageSubscription = _client.messages.listen(
      _handleTranscriptItem,
      onError: _handleStreamError,
    );
    _eventSubscription = _client.events.listen(
      _handleSessionEvent,
      onError: _handleStreamError,
    );
  }

  final String startChatEndpoint;
  final String connectInstanceId;
  final String contactFlowId;
  final String awsRegion;
  final String customerName;
  final bool disableCsm;
  final bool receiptsEnabled;
  final double receiptThrottleSeconds;
  final double deliveredThrottleSeconds;
  final List<String> supportedMessagingContentTypes;
  final Duration replyTimeout;
  final AmazonConnectChatClient _client;
  final http.Client _httpClient;

  late final StreamSubscription<AmazonConnectTranscriptItem>
  _messageSubscription;
  late final StreamSubscription<AmazonConnectSessionEvent> _eventSubscription;
  final Queue<Completer<ChatbotReply>> _pendingReplies =
      Queue<Completer<ChatbotReply>>();
  final Set<String> _seenMessageIds = <String>{};

  bool _configured = false;
  bool _disposed = false;
  Future<void>? _connectionFuture;
  String? _contactId;
  String? _participantId;
  String? _participantToken;

  @override
  Future<ChatbotReply> sendMessage({
    required String message,
    String? conversationId,
    Map<String, dynamic>? metadata,
  }) async {
    final trimmedMessage = message.trim();
    AppLogger.start(
      'AmazonConnectChatbotRepository',
      'repository sendMessage flow',
      <String, Object?>{
        'message': message,
        'trimmedMessage': trimmedMessage,
        'conversationId': conversationId,
        'metadata': metadata,
        'hasActiveContactId': _contactId != null,
        'pendingReplies': _pendingReplies.length,
      },
    );

    if (trimmedMessage.isEmpty) {
      AppLogger.warning(
        'AmazonConnectChatbotRepository',
        'sendMessage rejected empty message',
      );
      throw const ChatbotException('Tin nhắn không được để trống.');
    }

    Completer<ChatbotReply>? completer;
    try {
      _ensureNotDisposed();
      await _ensureConnected(
        sourceContactId: conversationId,
        metadata: metadata,
      );

      completer = Completer<ChatbotReply>();
      _pendingReplies.add(completer);
      AppLogger.debug(
        'AmazonConnectChatbotRepository',
        'pending reply queued',
        <String, Object?>{'pendingReplies': _pendingReplies.length},
      );
      AppLogger.step(
        'AmazonConnectChatbotRepository',
        'call native SDK sendMessage',
        <String, Object?>{
          'text': trimmedMessage,
          'contentType': AmazonConnectContentType.plainText,
        },
      );
      await _client.sendMessage(
        trimmedMessage,
        contentType: AmazonConnectContentType.plainText,
      );
      final reply = await completer.future.timeout(replyTimeout);
      AppLogger.success(
        'AmazonConnectChatbotRepository',
        'repository sendMessage flow completed',
        <String, Object?>{
          'reply': reply.reply,
          'conversationId': reply.conversationId,
          'pendingReplies': _pendingReplies.length,
        },
      );
      return reply;
    } on TimeoutException catch (error) {
      _removePendingReply(completer);
      AppLogger.failure(
        'AmazonConnectChatbotRepository',
        'repository sendMessage flow failed: reply timeout',
        data: <String, Object?>{
          'replyTimeoutMs': replyTimeout.inMilliseconds,
          'pendingReplies': _pendingReplies.length,
        },
        error: error,
      );
      throw ChatbotException(
        'Không nhận được phản hồi từ Amazon Connect trong thời gian chờ.',
        cause: error,
      );
    } on AmazonConnectChatException catch (error) {
      _removePendingReply(completer);
      AppLogger.failure(
        'AmazonConnectChatbotRepository',
        'repository sendMessage flow failed: native exception',
        data: <String, Object?>{'code': error.code, 'message': error.message},
        error: error,
      );
      throw ChatbotException(error.message, cause: error);
    } on ChatbotException {
      _removePendingReply(completer);
      AppLogger.warning(
        'AmazonConnectChatbotRepository',
        'sendMessage chatbot exception',
        data: <String, Object?>{'pendingReplies': _pendingReplies.length},
      );
      rethrow;
    } on UnsupportedError catch (error) {
      _removePendingReply(completer);
      AppLogger.failure(
        'AmazonConnectChatbotRepository',
        'repository sendMessage flow failed: unsupported platform',
        error: error,
      );
      throw ChatbotException(
        error.message ?? 'Nền tảng hiện tại không hỗ trợ Amazon Connect Chat.',
        cause: error,
      );
    } on Object catch (error, stackTrace) {
      _removePendingReply(completer);
      AppLogger.failure(
        'AmazonConnectChatbotRepository',
        'repository sendMessage flow failed: unexpected error',
        data: <String, Object?>{
          'pendingReplies': _pendingReplies.length,
          'contactId': _contactId,
          'participantId': _participantId,
        },
        error: error,
        stackTrace: stackTrace,
      );
      throw ChatbotException(
        'Không gửi được tin nhắn qua Amazon Connect.',
        cause: error,
      );
    }
  }

  Future<bool> get isSessionActive => _client.isSessionActive();

  Future<void> disconnect() async {
    AppLogger.start(
      'AmazonConnectChatbotRepository',
      'disconnect requested',
      <String, Object?>{
        'contactId': _contactId,
        'participantId': _participantId,
        'pendingReplies': _pendingReplies.length,
      },
    );
    _resetSessionState();
    _completePendingWithError(
      const ChatbotException('Phiên chat Amazon Connect đã ngắt kết nối.'),
    );
    await _client.disconnect();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      AppLogger.debug('AmazonConnectChatbotRepository', 'dispose ignored');
      return;
    }
    AppLogger.start('AmazonConnectChatbotRepository', 'dispose repository');
    _disposed = true;
    try {
      await disconnect();
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'AmazonConnectChatbotRepository',
        'disconnect during dispose failed',
        error: error,
        stackTrace: stackTrace,
      );
      _resetSessionState();
    }
    await _messageSubscription.cancel();
    await _eventSubscription.cancel();
    _httpClient.close();
    AppLogger.success(
      'AmazonConnectChatbotRepository',
      'dispose repository done',
    );
  }

  Future<void> _ensureConnected({
    String? sourceContactId,
    Map<String, dynamic>? metadata,
  }) async {
    AppLogger.step(
      'AmazonConnectChatbotRepository',
      'ensure native SDK connection',
      <String, Object?>{
        'sourceContactId': sourceContactId,
        'metadata': metadata,
        'configured': _configured,
        'hasParticipantToken': _participantToken != null,
        'connectionInFlight': _connectionFuture != null,
      },
    );
    _validateConfig();
    await _configureOnce();
    final active = await _client.isSessionActive();
    AppLogger.debug(
      'AmazonConnectChatbotRepository',
      'native isSessionActive result',
      active,
    );
    if (active) {
      return;
    }

    final pendingConnection = _connectionFuture;
    if (pendingConnection != null) {
      AppLogger.step(
        'AmazonConnectChatbotRepository',
        'awaiting existing connection future',
      );
      return pendingConnection;
    }

    final connection = _connect(
      sourceContactId: sourceContactId,
      metadata: metadata,
    );
    _connectionFuture = connection;
    try {
      await connection;
    } finally {
      _connectionFuture = null;
    }
  }

  Future<void> _configureOnce() async {
    if (_configured) {
      AppLogger.trace(
        'AmazonConnectChatbotRepository',
        'configure skipped',
        <String, Object?>{'configured': _configured},
      );
      return;
    }
    AppLogger.start(
      'AmazonConnectChatbotRepository',
      'configure native SDK',
      <String, Object?>{
        'region': awsRegion,
        'disableCsm': disableCsm,
        'messageReceipts': <String, Object?>{
          'enabled': receiptsEnabled,
          'throttleTime': receiptThrottleSeconds,
          'deliveredThrottleTime': deliveredThrottleSeconds,
        },
      },
    );
    await _client.configure(
      AmazonConnectChatConfig(
        region: awsRegion,
        disableCsm: disableCsm,
        features: AmazonConnectChatFeatures(
          messageReceipts: AmazonConnectMessageReceiptsConfig(
            shouldSendMessageReceipts: receiptsEnabled,
            throttleTime: receiptThrottleSeconds,
            deliveredThrottleTime: deliveredThrottleSeconds,
          ),
        ),
      ),
    );
    _configured = true;
    AppLogger.success(
      'AmazonConnectChatbotRepository',
      'configure native SDK done',
    );
  }

  Future<void> _connect({
    String? sourceContactId,
    Map<String, dynamic>? metadata,
  }) async {
    if (_participantToken != null) {
      try {
        AppLogger.start(
          'AmazonConnectChatbotRepository',
          'reconnect native SDK with existing token',
          <String, Object?>{
            'contactId': _contactId,
            'participantId': _participantId,
            'participantToken': _participantToken,
          },
        );
        await _client.connect(
          AmazonConnectChatSessionDetails(
            participantToken: _participantToken!,
            contactId: _contactId,
            participantId: _participantId,
          ),
        );
        AppLogger.success(
          'AmazonConnectChatbotRepository',
          'reconnect native SDK done',
        );
        return;
      } on Object catch (error, stackTrace) {
        AppLogger.warning(
          'AmazonConnectChatbotRepository',
          'native reconnect failed; starting new chat',
          data: <String, Object?>{'contactId': _contactId},
          error: error,
          stackTrace: stackTrace,
        );
        _resetSessionState();
      }
    }

    AppLogger.step(
      'AmazonConnectChatbotRepository',
      'start new Amazon Connect chat session',
      <String, Object?>{
        'sourceContactId': sourceContactId,
        'metadata': metadata,
      },
    );
    final details = await _startChat(
      sourceContactId: sourceContactId,
      metadata: metadata,
    );
    _contactId = details.contactId;
    _participantId = details.participantId;
    _participantToken = details.participantToken;
    AppLogger.start(
      'AmazonConnectChatbotRepository',
      'connect native SDK session',
      <String, Object?>{
        'contactId': details.contactId,
        'participantId': details.participantId,
        'participantToken': details.participantToken,
      },
    );
    await _client.connect(details);
    AppLogger.success(
      'AmazonConnectChatbotRepository',
      'connect native SDK session done',
    );
  }

  Future<AmazonConnectChatSessionDetails> _startChat({
    String? sourceContactId,
    Map<String, dynamic>? metadata,
  }) async {
    final uri = Uri.parse(startChatEndpoint);
    final payload = _buildStartChatPayload(
      sourceContactId: sourceContactId,
      metadata: metadata,
    );
    AppLogger.step(
      'AmazonConnectChatbotRepository',
      'StartChatContact backend request prepared',
      <String, Object?>{'uri': uri.toString(), 'payload': payload},
    );
    final response = await _httpClient.post(
      uri,
      headers: const <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.failure(
        'AmazonConnectChatbotRepository',
        'StartChatContact backend failed with non-2xx',
        data: <String, Object?>{
          'statusCode': response.statusCode,
          'body': response.body,
        },
      );
      throw ChatbotException(
        _extractErrorMessage(response.body) ??
            'StartChatContact lỗi (${response.statusCode}).',
      );
    }

    final details = AmazonConnectStartChatResult.fromResponseBody(
      response.body,
    ).toSessionDetails();
    AppLogger.success(
      'AmazonConnectChatbotRepository',
      'StartChatContact parsed',
      <String, Object?>{
        'ContactId': details.contactId,
        'ParticipantId': details.participantId,
        'ParticipantToken': details.participantToken,
      },
    );
    return details;
  }

  Map<String, Object?> _buildStartChatPayload({
    String? sourceContactId,
    Map<String, dynamic>? metadata,
  }) {
    final attributes = _metadataToAttributes(metadata);
    final trimmedSourceContactId = sourceContactId?.trim();

    return <String, Object?>{
      'InstanceId': connectInstanceId,
      'ContactFlowId': contactFlowId,
      'ParticipantDetails': <String, Object?>{
        'DisplayName': customerName.trim().isEmpty ? 'CUSTOMER' : customerName,
      },
      if (attributes.isNotEmpty) 'Attributes': attributes,
      if (trimmedSourceContactId != null && trimmedSourceContactId.isNotEmpty)
        'PersistentChat': <String, Object?>{
          'SourceContactId': trimmedSourceContactId,
          'RehydrationType': 'ENTIRE_PAST_SESSION',
        },
      'SupportedMessagingContentTypes': supportedMessagingContentTypes,
    };
  }

  void _handleTranscriptItem(AmazonConnectTranscriptItem item) {
    AppLogger.debug(
      'AmazonConnectChatbotRepository',
      'SDK transcript item received',
      <String, Object?>{
        'kind': item.kind.name,
        'id': item.id,
        'timestamp': item.timestamp,
        'contentType': item.contentType,
        'persistentId': item.persistentId,
        'raw': item.raw,
      },
    );
    if (item is! AmazonConnectChatMessage) {
      AppLogger.trace(
        'AmazonConnectChatbotRepository',
        'transcript item ignored because it is not a message',
      );
      return;
    }
    final messageKey = _messageKey(item);
    if (!_seenMessageIds.add(messageKey)) {
      AppLogger.debug(
        'AmazonConnectChatbotRepository',
        'duplicate message ignored',
        <String, Object?>{'messageKey': messageKey, 'text': item.text},
      );
      return;
    }
    if (item.text.trim().isEmpty) {
      AppLogger.debug(
        'AmazonConnectChatbotRepository',
        'empty message ignored',
        <String, Object?>{'messageKey': messageKey},
      );
      return;
    }
    if (!_isIncomingMessage(item) || _pendingReplies.isEmpty) {
      AppLogger.debug(
        'AmazonConnectChatbotRepository',
        'message not used for reply',
        <String, Object?>{
          'isIncoming': _isIncomingMessage(item),
          'pendingReplies': _pendingReplies.length,
          'participant': item.participant,
          'messageDirection': item.messageDirection.name,
          'text': item.text,
        },
      );
      return;
    }

    final completer = _pendingReplies.removeFirst();
    if (!completer.isCompleted) {
      AppLogger.success(
        'AmazonConnectChatbotRepository',
        'incoming reply completed pending message',
        <String, Object?>{
          'messageId': item.id,
          'participant': item.participant,
          'displayName': item.displayName,
          'text': item.text,
          'contactId': _contactId,
          'pendingReplies': _pendingReplies.length,
        },
      );
      completer.complete(
        ChatbotReply(reply: item.text, conversationId: _contactId),
      );
    }
  }

  void _handleSessionEvent(AmazonConnectSessionEvent event) {
    AppLogger.step(
      'AmazonConnectChatbotRepository',
      'SDK session event received',
      <String, Object?>{
        'type': event.type,
        'state': event.state,
        'isActive': event.isActive,
        'message': event.message,
        'raw': event.raw,
        'item': event.item?.raw,
      },
    );
    const terminalEvents = <String>{
      'error',
      'deep_heartbeat_failure',
      'auto_disconnection',
      'chat_ended',
    };

    if (terminalEvents.contains(event.type)) {
      _resetSessionState();
      _completePendingWithError(
        ChatbotException(
          event.message ?? 'Phiên chat Amazon Connect đã kết thúc.',
        ),
      );
      return;
    }

    if (event.type == 'session_active_changed' && event.isActive == false) {
      _resetSessionState();
      _completePendingWithError(
        const ChatbotException(
          'Phiên chat Amazon Connect không còn hoạt động.',
        ),
      );
    }
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    AppLogger.failure(
      'AmazonConnectChatbotRepository',
      'SDK stream error',
      error: error,
      stackTrace: stackTrace,
    );
    _completePendingWithError(
      ChatbotException('Amazon Connect stream bị lỗi.', cause: error),
    );
  }

  void _completePendingWithError(ChatbotException error) {
    AppLogger.warning(
      'AmazonConnectChatbotRepository',
      'complete pending replies with error',
      data: <String, Object?>{
        'pendingReplies': _pendingReplies.length,
        'error': error.message,
        'cause': error.cause?.toString(),
      },
    );
    while (_pendingReplies.isNotEmpty) {
      final completer = _pendingReplies.removeFirst();
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
  }

  void _removePendingReply(Completer<ChatbotReply>? completer) {
    if (completer == null) {
      return;
    }
    _pendingReplies.remove(completer);
    AppLogger.debug(
      'AmazonConnectChatbotRepository',
      'pending reply removed',
      <String, Object?>{'pendingReplies': _pendingReplies.length},
    );
  }

  void _resetSessionState() {
    AppLogger.debug(
      'AmazonConnectChatbotRepository',
      'reset session state',
      <String, Object?>{
        'contactId': _contactId,
        'participantId': _participantId,
        'hasParticipantToken': _participantToken != null,
      },
    );
    _contactId = null;
    _participantId = null;
    _participantToken = null;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const ChatbotException('Amazon Connect repository đã bị dispose.');
    }
  }

  String _messageKey(AmazonConnectChatMessage message) {
    if (message.id.isNotEmpty) {
      return message.id;
    }
    if (message.persistentId != null && message.persistentId!.isNotEmpty) {
      return message.persistentId!;
    }
    return '${message.participant}|${message.timestamp}|${message.text}';
  }

  bool _isIncomingMessage(AmazonConnectChatMessage message) {
    if (message.isIncoming) {
      return true;
    }
    if (message.isOutgoing) {
      return false;
    }

    final participant = message.participant.toUpperCase();
    return participant.isNotEmpty && participant != 'CUSTOMER';
  }

  void _validateConfig() {
    final trimmedEndpoint = startChatEndpoint.trim();
    final missing = <String>[
      if (trimmedEndpoint.isEmpty) 'START_CHAT_ENDPOINT',
      if (connectInstanceId.trim().isEmpty) 'CONNECT_INSTANCE_ID',
      if (contactFlowId.trim().isEmpty) 'CONTACT_FLOW_ID',
      if (awsRegion.trim().isEmpty) 'AWS_REGION',
    ];
    final endpoint = Uri.tryParse(trimmedEndpoint);
    if (trimmedEndpoint.isNotEmpty &&
        (endpoint == null || !endpoint.hasScheme || endpoint.host.isEmpty)) {
      missing.add('START_CHAT_ENDPOINT_URL');
    }
    if (missing.isNotEmpty) {
      AppLogger.failure(
        'AmazonConnectChatbotRepository',
        'config validation failed',
        data: <String, Object?>{'missing': missing},
      );
      throw ChatbotException(
        'Thiếu cấu hình Amazon Connect: ${missing.join(', ')}.',
      );
    }
    AppLogger.debug(
      'AmazonConnectChatbotRepository',
      'config validation passed',
      <String, Object?>{
        'startChatEndpoint': startChatEndpoint,
        'connectInstanceId': connectInstanceId,
        'contactFlowId': contactFlowId,
        'awsRegion': awsRegion,
      },
    );
  }

  String? _extractErrorMessage(String body) {
    try {
      final decoded = _decodeJsonMap(body);
      final message = decoded['message'] ?? decoded['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
      final nestedBody = decoded['body'];
      if (nestedBody is String && nestedBody.trim().isNotEmpty) {
        final nested = _decodeJsonMap(nestedBody);
        final nestedMessage = nested['message'] ?? nested['error'];
        if (nestedMessage is String && nestedMessage.trim().isNotEmpty) {
          return nestedMessage;
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  Map<String, String> _metadataToAttributes(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) {
      return const <String, String>{};
    }

    final attributes = <String, String>{};
    for (final entry in metadata.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || entry.value == null) {
        continue;
      }

      attributes[key] = _metadataValueToString(entry.value);
    }
    return attributes;
  }

  String _metadataValueToString(Object? value) {
    return switch (value) {
      String() => value,
      num() || bool() => value.toString(),
      DateTime() => value.toIso8601String(),
      _ => jsonEncode(value),
    };
  }
}

class AmazonConnectStartChatResult {
  const AmazonConnectStartChatResult({
    required this.contactId,
    required this.participantId,
    required this.participantToken,
  });

  factory AmazonConnectStartChatResult.fromResponseBody(String body) {
    AppLogger.debug(
      'AmazonConnectStartChatResult',
      'parse response body started',
      <String, Object?>{'body': body},
    );
    final decoded = _decodeJsonMap(body);
    final result = _extractStartChatResult(decoded);
    AppLogger.debug(
      'AmazonConnectStartChatResult',
      'extracted start chat result',
      <String, Object?>{'decoded': decoded, 'result': result},
    );
    final contactId = _readString(result, 'ContactId', 'contactId');
    final participantId = _readString(result, 'ParticipantId', 'participantId');
    final participantToken = _readString(
      result,
      'ParticipantToken',
      'participantToken',
    );

    if (contactId == null ||
        participantId == null ||
        participantToken == null) {
      AppLogger.warning(
        'AmazonConnectStartChatResult',
        'missing required session fields',
        data: <String, Object?>{
          'contactId': contactId,
          'participantId': participantId,
          'participantToken': participantToken,
          'result': result,
        },
      );
      throw const ChatbotException(
        'StartChatContact response thiếu ContactId, ParticipantId hoặc ParticipantToken.',
      );
    }

    return AmazonConnectStartChatResult(
      contactId: contactId,
      participantId: participantId,
      participantToken: participantToken,
    );
  }

  final String contactId;
  final String participantId;
  final String participantToken;

  AmazonConnectChatSessionDetails toSessionDetails() {
    return AmazonConnectChatSessionDetails(
      contactId: contactId,
      participantId: participantId,
      participantToken: participantToken,
    );
  }
}

Map<String, Object?> _decodeJsonMap(String body) {
  AppLogger.trace('AmazonConnectStartChatResult', 'decode json map', body);
  final decoded = jsonDecode(body);
  return _mapFromValue(decoded);
}

Map<String, Object?> _extractStartChatResult(Map<String, Object?> decoded) {
  final body = decoded['body'];
  if (body is String && body.trim().isNotEmpty) {
    return _extractStartChatResult(_decodeJsonMap(body));
  }

  final data = _optionalMapFromValue(decoded['data']);
  if (data != null) {
    final nested =
        _optionalMapFromValue(data['startChatResult']) ??
        _optionalMapFromValue(data['StartChatResult']) ??
        _optionalMapFromValue(data['startChatContactResult']) ??
        _optionalMapFromValue(data['StartChatContactResult']);
    if (nested != null) {
      return nested;
    }
  }

  return _optionalMapFromValue(decoded['startChatResult']) ??
      _optionalMapFromValue(decoded['StartChatResult']) ??
      _optionalMapFromValue(decoded['startChatContactResult']) ??
      _optionalMapFromValue(decoded['StartChatContactResult']) ??
      data ??
      decoded;
}

Map<String, Object?> _mapFromValue(Object? value) {
  final map = _optionalMapFromValue(value);
  if (map == null) {
    throw const ChatbotException('StartChatContact response không hợp lệ.');
  }
  return map;
}

Map<String, Object?>? _optionalMapFromValue(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      return _decodeJsonMap(value);
    } on Object {
      return null;
    }
  }
  return null;
}

String? _readString(Map<String, Object?> map, String primary, String alias) {
  final value = map[primary] ?? map[alias];
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty ? trimmed : null;
  }
  return null;
}
