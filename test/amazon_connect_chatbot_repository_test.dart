import 'dart:async';
import 'dart:convert';

import 'package:amazon_connect_chat_flutter/amazon_connect_chat_flutter.dart';
import 'package:chatbotdemo/features/chatbot/chatbot.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AmazonConnectStartChatRequest', () {
    test('serializes the backend request contract', () {
      const request = AmazonConnectStartChatRequest(
        instanceId: 'be4e4fdc-fc5f-488a-96e6-dc3603219c93',
        contactFlowId: 'a7bb5042-8393-4f82-96d7-a737c7715e55',
        displayName: 'CUSTOMER',
        attributes: <String, String>{
          'app': 'chatbotdemo',
          'domain': 'banking-demo',
        },
        supportedMessagingContentTypes: <String>[
          'text/plain',
          'text/markdown',
          'application/vnd.amazonaws.connect.message.interactive',
        ],
      );

      expect(request.toJson(), <String, Object?>{
        'InstanceId': 'be4e4fdc-fc5f-488a-96e6-dc3603219c93',
        'ContactFlowId': 'a7bb5042-8393-4f82-96d7-a737c7715e55',
        'ParticipantDetails': <String, Object?>{'DisplayName': 'CUSTOMER'},
        'Attributes': <String, String>{
          'app': 'chatbotdemo',
          'domain': 'banking-demo',
        },
        'SupportedMessagingContentTypes': <String>[
          'text/plain',
          'text/markdown',
          'application/vnd.amazonaws.connect.message.interactive',
        ],
      });
    });
  });

  group('AmazonConnectStartChatResponse', () {
    test('parses the deployed backend response contract', () {
      final response = AmazonConnectStartChatResponse.fromResponseBody(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'startChatResult': <String, Object?>{
              'ContactId': 'contact-1',
              'ParticipantId': 'participant-1',
              'ParticipantToken': 'token-1',
            },
            'featurePermissions': <String, Object?>{
              'MESSAGING_MARKDOWN': false,
            },
          },
        }),
      );

      expect(response.startChatResult.contactId, 'contact-1');
      expect(response.startChatResult.participantId, 'participant-1');
      expect(response.startChatResult.participantToken, 'token-1');
      expect(response.featurePermissions?.messagingMarkdown, isFalse);
    });
  });

  group('AmazonConnectStartChatResult', () {
    test('parses nested API response', () {
      final result = AmazonConnectStartChatResult.fromResponseBody(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'startChatResult': <String, Object?>{
              'ContactId': 'contact-1',
              'ParticipantId': 'participant-1',
              'ParticipantToken': 'token-1',
            },
          },
        }),
      );

      expect(result.contactId, 'contact-1');
      expect(result.participantId, 'participant-1');
      expect(result.participantToken, 'token-1');
    });

    test('parses Lambda proxy body response', () {
      final result = AmazonConnectStartChatResult.fromResponseBody(
        jsonEncode(<String, Object?>{
          'statusCode': 200,
          'body': jsonEncode(<String, Object?>{
            'contactId': 'contact-2',
            'participantId': 'participant-2',
            'participantToken': 'token-2',
          }),
        }),
      );

      expect(result.contactId, 'contact-2');
      expect(result.participantId, 'participant-2');
      expect(result.participantToken, 'token-2');
    });
  });

  group('AmazonConnectChatbotRepository', () {
    const methodsChannel = MethodChannel('amazon_connect_chat_flutter/methods');
    const eventsChannel = MethodChannel('amazon_connect_chat_flutter/events');
    const messagesChannel = MethodChannel(
      'amazon_connect_chat_flutter/messages',
    );

    final methodCalls = <MethodCall>[];
    http.Request? startChatRequest;
    var sessionActive = false;

    setUp(() {
      methodCalls.clear();
      startChatRequest = null;
      sessionActive = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodsChannel, (methodCall) async {
            methodCalls.add(methodCall);

            switch (methodCall.method) {
              case 'requireNativeIntegrations':
              case 'configure':
                return null;
              case 'isSessionActive':
                return sessionActive;
              case 'connect':
                sessionActive = true;
                return null;
              case 'sendMessage':
                scheduleMicrotask(() {
                  unawaited(
                    _emitMessage(<String, Object?>{
                      'kind': 'message',
                      'id': 'message-1',
                      'timestamp': '2026-06-18T01:02:03.000Z',
                      'contentType': AmazonConnectContentType.plainText,
                      'participant': 'AGENT',
                      'text': 'Xin chao',
                      'messageDirection': 'INCOMING',
                    }),
                  );
                });
                return null;
              case 'disconnect':
                sessionActive = false;
                return null;
            }

            return null;
          });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(eventsChannel, (_) async => null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(messagesChannel, (_) async => null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodsChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(eventsChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(messagesChannel, null);
    });

    test(
      'starts session, sends message, and resolves incoming reply',
      () async {
        final httpClient = MockClient((request) async {
          startChatRequest = request;
          return http.Response(
            jsonEncode(<String, Object?>{
              'data': <String, Object?>{
                'startChatResult': <String, Object?>{
                  'ContactId': 'contact-1',
                  'ParticipantId': 'participant-1',
                  'ParticipantToken': 'token-1',
                },
              },
            }),
            200,
          );
        });
        final repository = AmazonConnectChatbotRepository(
          startChatEndpoint: 'https://example.com/start-chat',
          connectInstanceId: 'instance-1',
          contactFlowId: 'flow-1',
          awsRegion: 'ap-southeast-1',
          customerName: 'Customer Demo',
          httpClient: httpClient,
          replyTimeout: const Duration(seconds: 1),
        );

        final reply = await repository.sendMessage(
          message: '  hello  ',
          conversationId: ' source-contact-1 ',
          metadata: <String, dynamic>{
            'app': 'chatbotdemo',
            'attempt': 1,
            'enabled': true,
            'ignored': null,
          },
        );

        expect(reply.reply, 'Xin chao');
        expect(reply.conversationId, 'contact-1');

        final startChatBody =
            jsonDecode(startChatRequest!.body) as Map<String, dynamic>;
        expect(startChatBody['InstanceId'], 'instance-1');
        expect(startChatBody['ContactFlowId'], 'flow-1');
        expect(startChatBody['ParticipantDetails'], <String, Object?>{
          'DisplayName': 'Customer Demo',
        });
        expect(startChatBody['PersistentChat'], <String, Object?>{
          'SourceContactId': 'source-contact-1',
          'RehydrationType': 'ENTIRE_PAST_SESSION',
        });
        expect(startChatBody['Attributes'], <String, String>{
          'app': 'chatbotdemo',
          'attempt': '1',
          'enabled': 'true',
        });
        expect(
          startChatBody['SupportedMessagingContentTypes'],
          containsAll(<String>[
            AmazonConnectContentType.plainText,
            AmazonConnectContentType.richText,
            AmazonConnectContentType.interactiveText,
          ]),
        );

        final sendCall = methodCalls.lastWhere(
          (methodCall) => methodCall.method == 'sendMessage',
        );
        final sendArguments = sendCall.arguments as Map<Object?, Object?>;
        expect(sendArguments['text'], 'hello');
        expect(
          sendArguments['contentType'],
          AmazonConnectContentType.plainText,
        );
        expect(methodCalls.map((call) => call.method), contains('connect'));

        await repository.dispose();
      },
    );
  });
}

Future<void> _emitMessage(Map<String, Object?> payload) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'amazon_connect_chat_flutter/messages',
        const StandardMethodCodec().encodeSuccessEnvelope(payload),
        (_) {},
      );
}
