import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_logger.dart';

class LoggingHttpClient extends http.BaseClient {
  LoggingHttpClient(this._inner, {required this.tag});

  final http.Client _inner;
  final String tag;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final startedAt = DateTime.now();
    final requestBytes = await request.finalize().toBytes();
    final requestBody = _decodeBody(requestBytes);
    final curl = CurlCommand.fromRequest(
      request,
      bodyBytes: requestBytes,
      body: requestBody,
    ).toCommand();

    AppLogger.start(tag, 'HTTP request', <String, Object?>{
      'method': request.method,
      'url': request.url.toString(),
      'headers': request.headers,
    });
    AppLogger.step(tag, 'HTTP request body', <String, Object?>{
      'body': _tryDecodeJson(requestBody) ?? requestBody,
    });
    AppLogger.command(
      tag,
      'copy and run this cURL to reproduce API call',
      curl,
    );

    final clonedRequest = _cloneRequest(request, requestBytes);

    try {
      final streamedResponse = await _inner.send(clonedRequest);
      final responseBytes = await streamedResponse.stream.toBytes();
      final responseBody = _decodeBody(responseBytes);
      final durationMs = DateTime.now().difference(startedAt).inMilliseconds;

      AppLogger.success(tag, 'HTTP response', <String, Object?>{
        'method': request.method,
        'url': request.url.toString(),
        'statusCode': streamedResponse.statusCode,
        'reasonPhrase': streamedResponse.reasonPhrase,
        'durationMs': durationMs,
        'headers': streamedResponse.headers,
        'body': _tryDecodeJson(responseBody) ?? responseBody,
      });

      return http.StreamedResponse(
        http.ByteStream.fromBytes(responseBytes),
        streamedResponse.statusCode,
        contentLength: streamedResponse.contentLength,
        request: streamedResponse.request,
        headers: streamedResponse.headers,
        isRedirect: streamedResponse.isRedirect,
        persistentConnection: streamedResponse.persistentConnection,
        reasonPhrase: streamedResponse.reasonPhrase,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.failure(
        tag,
        'HTTP request failed',
        data: <String, Object?>{
          'method': request.method,
          'url': request.url.toString(),
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'curl': curl,
        },
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
  }

  http.StreamedRequest _cloneRequest(
    http.BaseRequest request,
    List<int> bodyBytes,
  ) {
    final clonedRequest = http.StreamedRequest(request.method, request.url)
      ..contentLength = bodyBytes.length
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;

    clonedRequest.headers.addAll(request.headers);
    clonedRequest.sink.add(bodyBytes);
    clonedRequest.sink.close();
    return clonedRequest;
  }

  String _decodeBody(List<int> bytes) {
    if (bytes.isEmpty) {
      return '';
    }
    try {
      return utf8.decode(bytes);
    } on Object {
      return base64Encode(bytes);
    }
  }

  Object? _tryDecodeJson(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(body);
    } on Object {
      return null;
    }
  }
}

class CurlCommand {
  const CurlCommand({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
  });

  factory CurlCommand.fromRequest(
    http.BaseRequest request, {
    required List<int> bodyBytes,
    required String body,
  }) {
    return CurlCommand(
      method: request.method,
      url: request.url,
      headers: request.headers,
      body: bodyBytes.isEmpty ? null : body,
    );
  }

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String? body;

  String toCommand() {
    final parts = <String>[
      'curl',
      '-X',
      method,
      _shellQuote(url.toString()),
      for (final entry in headers.entries) ...[
        '-H',
        _shellQuote('${entry.key}: ${entry.value}'),
      ],
      if (body != null && body!.isNotEmpty) ...[
        '--data-raw',
        _shellQuote(body!),
      ],
    ];

    return parts.join(' ');
  }

  String _shellQuote(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }
}
