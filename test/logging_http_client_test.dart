import 'package:chatbotdemo/core/logging/logging_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('CurlCommand renders method headers and body', () {
    final request =
        http.Request('POST', Uri.parse('https://example.com/start-chat'))
          ..headers.addAll(<String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          });
    final body = '{"message":"hello"}';
    request.body = body;

    final command = CurlCommand.fromRequest(
      request,
      bodyBytes: request.bodyBytes,
      body: body,
    ).toCommand();

    expect(command, contains("curl -X POST"));
    expect(command, contains("'https://example.com/start-chat'"));
    expect(command, contains("-H 'Content-Type: application/json'"));
    expect(command, contains("-H 'Accept: application/json'"));
    expect(command, contains("--data-raw '$body'"));
  });
}
