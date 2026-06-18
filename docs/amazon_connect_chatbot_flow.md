# Amazon Connect Chatbot Flow

This document describes how this Flutter demo integrates Amazon Connect Chat on
Android and iOS, and how a user message moves through the app, backend, native
SDK, and Amazon Connect.

## Integration Overview

The app has two chatbot entry points from `HomeScreen`:

| Entry point | Purpose |
| --- | --- |
| `WebView Chatbot` | Opens `CHATBOT_WEBVIEW_URL` in `ChatbotWebViewScreen`. |
| `Native Chatbot` | Opens `ChatbotScreen` with `AmazonConnectChatbotRepository` on Android/iOS. |

The native flow uses the local Flutter plugin `amazon_connect_chat_flutter`.
That plugin wraps:

| Platform | Native SDK |
| --- | --- |
| Android | `software.aws.connect:amazon-connect-chat-android:2.0.11` |
| iOS | `AmazonConnectChatIOS ~> 2.0.13` |

The mobile app does not call AWS `StartChatContact` directly. It calls your
backend endpoint, and the backend calls AWS with protected credentials.

## Platform Setup

Android:

- `android/app/build.gradle.kts` sets `minSdk = 24`.
- `android/app/src/main/AndroidManifest.xml` includes `android.permission.INTERNET`.
- The plugin pulls the Android Amazon Connect Chat SDK through Gradle.

iOS:

- `ios/Podfile` sets `platform :ios, '15.0'`.
- `ios/Podfile` uses static frameworks with `use_frameworks! :linkage => :static`.
- `ios/Podfile.lock` includes `AmazonConnectChatIOS (2.0.13)`.
- `ios/Runner.xcodeproj` has `IPHONEOS_DEPLOYMENT_TARGET = 15.0`.
- `AppDelegate.swift` registers Flutter plugins through `GeneratedPluginRegistrant`.

Build checks used for this repo:

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

## Runtime Configuration

`AppConfig.current` reads defaults from `lib/core/config/app_config.dart` and
allows overrides with `--dart-define`.

Required native chat config:

```sh
--dart-define=START_CHAT_ENDPOINT=https://your-api.example.com/start-chat
--dart-define=CONNECT_INSTANCE_ID=your-instance-id
--dart-define=CONTACT_FLOW_ID=your-contact-flow-id
--dart-define=AWS_REGION=ap-southeast-1
--dart-define=CUSTOMER_NAME=CUSTOMER
```

Optional config:

```sh
--dart-define=CONNECT_DISABLE_CSM=true
--dart-define=CONNECT_RECEIPTS_ENABLED=true
--dart-define=CONNECT_RECEIPT_THROTTLE_SECONDS=5.0
--dart-define=CONNECT_DELIVERED_THROTTLE_SECONDS=3.0
--dart-define=CHATBOT_VERBOSE_LOGS=true
```

## Debug Logging

Verbose logging is enabled by default for debug/profile builds and disabled by
default for release builds.

Control it explicitly:

```sh
--dart-define=CHATBOT_VERBOSE_LOGS=true
--dart-define=CHATBOT_VERBOSE_LOGS=false
```

The logger prints:

- App bootstrap config and selected repository.
- Home navigation and screen lifecycle.
- Chat UI send/retry/fail/append-reply state.
- Backend request payloads.
- Backend response status, headers, and body.
- Ready-to-copy cURL for every default `package:http` API call.
- Amazon Connect native configure/connect/send calls.
- Amazon Connect SDK transcript items and session events.
- Pending reply queue state.
- Parser steps for `StartChatContact` responses.
- Exceptions with stack traces.

Every log line starts with `CHATBOT_LOG`, so filter logcat/Xcode output by that
prefix. Each log event is split into clear parts with the same `seq`:

```text
part=HEAD       The readable checkpoint line.
part=DATA       JSON data for the same seq.
part=CURL       Ready-to-copy curl command for the same seq.
part=ERROR      Error object for the same seq.
part=STACK      Stack trace for the same seq.
seq=00024       Global order. Follow this number to read the exact timeline.
phase=START     A flow begins.
phase=STEP      A checkpoint inside the flow.
phase=OK        A step or flow completed.
phase=FAIL      This is where the flow failed.
tag=...         Screen/repository/component that produced the log.
msg=...         Human-readable step name.
```

Example native send flow:

```text
CHATBOT_LOG seq=00009 part=HEAD phase=START tag=AmazonConnectChatbotRepository msg="repository sendMessage flow"
CHATBOT_LOG seq=00009 part=DATA chunk=1/1 value={...}
CHATBOT_LOG seq=00010 part=HEAD phase=STEP tag=AmazonConnectChatbotRepository msg="ensure native SDK connection"
CHATBOT_LOG seq=00012 part=HEAD phase=START tag=AmazonConnectChatbotRepository msg="configure native SDK"
CHATBOT_LOG seq=00013 part=HEAD phase=OK tag=AmazonConnectChatbotRepository msg="configure native SDK done"
CHATBOT_LOG seq=00016 part=HEAD phase=STEP tag=AmazonConnectChatbotRepository msg="StartChatContact backend request prepared"
CHATBOT_LOG seq=00020 part=HEAD phase=OK tag=AmazonConnectChatbotRepository msg="StartChatContact parsed"
CHATBOT_LOG seq=00021 part=HEAD phase=START tag=AmazonConnectChatbotRepository msg="connect native SDK session"
CHATBOT_LOG seq=00022 part=HEAD phase=OK tag=AmazonConnectChatbotRepository msg="connect native SDK session done"
CHATBOT_LOG seq=00024 part=HEAD phase=STEP tag=AmazonConnectChatbotRepository msg="call native SDK sendMessage"
CHATBOT_LOG seq=00026 part=HEAD phase=OK tag=AmazonConnectChatbotRepository msg="incoming reply completed pending message"
CHATBOT_LOG seq=00027 part=HEAD phase=OK tag=AmazonConnectChatbotRepository msg="repository sendMessage flow completed"
```

If a payload is too long for logcat/Xcode, it is split safely:

```text
CHATBOT_LOG seq=00040 part=DATA chunk=1/3 value=...
CHATBOT_LOG seq=00040 part=DATA chunk=2/3 value=...
CHATBOT_LOG seq=00040 part=DATA chunk=3/3 value=...
```

Example cURL log:

```text
CHATBOT_LOG seq=00018 part=HEAD phase=CURL tag=AmazonConnectStartChatHttp msg="copy and run this cURL to reproduce API call"
CHATBOT_LOG seq=00018 part=CURL chunk=1/1 value=curl -X POST 'https://your-api.example.com/start-chat' -H 'Content-Type: application/json' -H 'Accept: application/json' --data-raw '{"InstanceId":"connect-instance-id","ContactFlowId":"contact-flow-id"}'
```

These logs intentionally include request/response data and Amazon Connect
session tokens to make debugging easier. Do not enable verbose logs in
production unless your log storage is protected and retention is controlled.

## App Flow

1. `main.dart` creates `AppConfig.current`.
2. `ChatbotDemoApp` builds `HomeScreen`.
3. User taps `Native Chatbot`.
4. `HomeScreen` creates a new repository through `createChatbotRepository`.
5. On Android/iOS, `main.dart` returns `AmazonConnectChatbotRepository`.
6. `ChatbotScreen` owns the repository and passes it to `ChatbotView`.
7. `ChatbotView` renders local chat UI and calls `repository.sendMessage`.
8. `AmazonConnectChatbotRepository` connects to Amazon Connect if needed.
9. The repository sends the message through the native SDK.
10. Incoming SDK stream messages resolve the pending Flutter reply.
11. `ChatbotView` appends the bot reply and updates the conversation id.
12. When the screen closes, `ChatbotScreen` disposes the repository.

## First Message Flow

When the user sends the first native chat message:

1. `ChatbotView._sendMessage` adds the user message with `sending` status.
2. It calls:

```dart
repository.sendMessage(
  message: text,
  conversationId: _conversationId,
  metadata: widget.metadata,
);
```

3. `AmazonConnectChatbotRepository` trims and validates the message.
4. `_ensureConnected` validates config and configures the native SDK once:

```dart
AmazonConnectChatConfig(
  region: awsRegion,
  disableCsm: disableCsm,
  features: AmazonConnectChatFeatures(
    messageReceipts: AmazonConnectMessageReceiptsConfig(...),
  ),
)
```

5. If no SDK session is active, `_startChat` posts to `START_CHAT_ENDPOINT`.
6. The request body sent to the backend includes:

```json
{
  "InstanceId": "connect-instance-id",
  "ContactFlowId": "contact-flow-id",
  "ParticipantDetails": {
    "DisplayName": "CUSTOMER"
  },
  "Attributes": {
    "app": "chatbotdemo",
    "domain": "banking-demo"
  },
  "SupportedMessagingContentTypes": [
    "text/plain",
    "text/markdown",
    "application/vnd.amazonaws.connect.message.interactive"
  ]
}
```

7. Backend calls AWS `StartChatContact`.
8. Backend returns `ContactId`, `ParticipantId`, and `ParticipantToken`.
9. The repository accepts these response shapes:

```text
ContactId / ParticipantId / ParticipantToken
contactId / participantId / participantToken
data.startChatResult.*
startChatResult.*
Lambda proxy response body containing any of the above
```

10. The repository calls the plugin:

```dart
client.connect(
  AmazonConnectChatSessionDetails(
    contactId: contactId,
    participantId: participantId,
    participantToken: participantToken,
  ),
);
```

11. After connect, it sends the user text as `text/plain`:

```dart
client.sendMessage(
  trimmedMessage,
  contentType: AmazonConnectContentType.plainText,
);
```

12. The native SDK sends the message over the Amazon Connect chat session.

## Reply Flow

`AmazonConnectChatbotRepository` subscribes to SDK streams in its constructor:

```dart
client.messages.listen(_handleTranscriptItem);
client.events.listen(_handleSessionEvent);
```

When an incoming `AmazonConnectChatMessage` arrives:

1. The repository ignores duplicate message ids.
2. It ignores empty text.
3. It ignores outgoing customer messages.
4. It completes the oldest pending `sendMessage` completer.
5. It returns:

```dart
ChatbotReply(
  reply: item.text,
  conversationId: _contactId,
)
```

`ChatbotView` then:

1. Marks the user message as `sent`.
2. Stores `conversationId`.
3. Appends the assistant message.
4. Hides the typing indicator.

## Persistent Chat Flow

After the first successful reply, `ChatbotView` keeps the returned
`conversationId`. On the next send, that id is passed back into the repository.

If `conversationId` is present, the backend request includes:

```json
{
  "PersistentChat": {
    "SourceContactId": "previous-contact-id",
    "RehydrationType": "ENTIRE_PAST_SESSION"
  }
}
```

Amazon Connect can use this to rehydrate the previous chat session, depending on
your contact flow and backend permissions.

## Error and Session Handling

The repository surfaces user-facing `ChatbotException` messages for:

- Missing config.
- Invalid `START_CHAT_ENDPOINT`.
- Failed backend `StartChatContact` response.
- Missing `ContactId`, `ParticipantId`, or `ParticipantToken`.
- Native SDK errors.
- Unsupported platform.
- Reply timeout.
- SDK stream errors.
- Terminal session events.

Terminal SDK events clear local session state and fail pending replies:

```text
error
deep_heartbeat_failure
auto_disconnection
chat_ended
session_active_changed with isActive=false
```

`dispose()` disconnects the SDK session, cancels stream subscriptions, fails any
pending reply, and closes the HTTP client.

## Backend Contract

The backend endpoint receives the mobile request body and should call AWS
`StartChatContact`. Keep AWS credentials, instance ids, and contact flow
authorization on the server side.

Minimum successful backend response:

```json
{
  "data": {
    "startChatResult": {
      "ContactId": "contact-id",
      "ParticipantId": "participant-id",
      "ParticipantToken": "participant-token"
    },
    "featurePermissions": {
      "MESSAGING_MARKDOWN": false
    }
  }
}
```

Legacy direct and Lambda proxy response styles are also accepted for backward
compatibility.

Lambda proxy example:

```json
{
  "statusCode": 200,
  "body": "{\"ContactId\":\"contact-id\",\"ParticipantId\":\"participant-id\",\"ParticipantToken\":\"participant-token\"}"
}
```

Recommended backend error shape:

```json
{
  "message": "Cannot start Amazon Connect chat"
}
```

The app displays that `message` when the backend returns a non-2xx status.
