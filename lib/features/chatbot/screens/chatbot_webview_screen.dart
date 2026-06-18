import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/logging/app_logger.dart';

class ChatbotWebViewScreen extends StatefulWidget {
  const ChatbotWebViewScreen({
    super.key,
    required this.url,
    this.title = 'WebView Chatbot',
  });

  final String url;
  final String title;

  @override
  State<ChatbotWebViewScreen> createState() => _ChatbotWebViewScreenState();
}

class _ChatbotWebViewScreenState extends State<ChatbotWebViewScreen> {
  WebViewController? _controller;
  String? _configurationError;

  @override
  void initState() {
    super.initState();
    AppLogger.info('ChatbotWebViewScreen', 'initState', <String, Object?>{
      'title': widget.title,
      'url': widget.url,
    });

    final uri = Uri.tryParse(widget.url.trim());
    if (uri == null || !_isSupportedWebUrl(uri)) {
      _configurationError =
          'Thiếu cấu hình CHATBOT_WEBVIEW_URL hoặc URL không hợp lệ.';
      AppLogger.warning(
        'ChatbotWebViewScreen',
        'invalid webview url',
        data: <String, Object?>{
          'url': widget.url,
          'parsedUri': uri?.toString(),
        },
      );
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            AppLogger.info(
              'ChatbotWebViewScreen',
              'page started',
              <String, Object?>{'url': url},
            );
          },
          onPageFinished: (url) {
            AppLogger.info(
              'ChatbotWebViewScreen',
              'page finished',
              <String, Object?>{'url': url},
            );
          },
          onWebResourceError: (error) {
            AppLogger.error(
              'ChatbotWebViewScreen',
              'web resource error',
              data: <String, Object?>{
                'errorCode': error.errorCode,
                'description': error.description,
                'errorType': error.errorType?.name,
                'isForMainFrame': error.isForMainFrame,
                'url': error.url,
              },
            );
          },
          onNavigationRequest: (request) {
            AppLogger.info(
              'ChatbotWebViewScreen',
              'navigation request',
              <String, Object?>{
                'url': request.url,
                'isMainFrame': request.isMainFrame,
              },
            );
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(uri);
    AppLogger.info(
      'ChatbotWebViewScreen',
      'loadRequest issued',
      uri.toString(),
    );
  }

  bool _isSupportedWebUrl(Uri uri) {
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.trace('ChatbotWebViewScreen', 'build', <String, Object?>{
      'hasController': _controller != null,
      'configurationError': _configurationError,
    });
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: false),
      body: controller == null
          ? _WebViewConfigurationError(message: _configurationError!)
          : WebViewWidget(controller: controller),
    );
  }
}

class _WebViewConfigurationError extends StatelessWidget {
  const _WebViewConfigurationError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
