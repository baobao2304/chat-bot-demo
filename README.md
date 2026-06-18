# chatbotdemo

Flutter chat demo integrated with a local Flutter plugin package for the
Amazon Connect Chat mobile SDKs.

## Amazon Connect Mobile

The plugin package lives at `packages/amazon_connect_chat_flutter` and wraps
the native Amazon Connect Chat SDKs:

| Platform | Native dependency |
| --- | --- |
| Android | `software.aws.connect:amazon-connect-chat-android:2.0.11` |
| iOS | `AmazonConnectChatIOS ~> 2.0.13` |

The app opens a Home screen with two flows:

- `WebView Chatbot`: loads `CHATBOT_WEBVIEW_URL` in an in-app WebView.
- `Native Chatbot`: uses the Amazon Connect native chat SDK on Android/iOS.

Run the Android or iOS demo with an environment and your StartChatContact
backend config:

```sh
flutter run \
  --dart-define=APP_ENV=dev \
  --dart-define=CHATBOT_WEBVIEW_URL=https://your-chatbot-web.example.com \
  --dart-define=START_CHAT_ENDPOINT=https://your-api.example.com/Prod/ \
  --dart-define=CONNECT_INSTANCE_ID=your-instance-id \
  --dart-define=CONTACT_FLOW_ID=your-contact-flow-id \
  --dart-define=AWS_REGION=US_WEST_2 \
  --dart-define=CUSTOMER_NAME=CUSTOMER
```

Optional privacy/receipt tuning:

```sh
--dart-define=CONNECT_DISABLE_CSM=true
--dart-define=CONNECT_RECEIPTS_ENABLED=true
--dart-define=CONNECT_RECEIPT_THROTTLE_SECONDS=5.0
--dart-define=CONNECT_DELIVERED_THROTTLE_SECONDS=3.0
--dart-define=CHATBOT_VERBOSE_LOGS=true
```

`APP_ENV` supports `dev`, `staging`, and `prod`. Defaults live in
`lib/core/config/app_config.dart`; every value above can still be overridden
with `--dart-define` for one-off testing.

Verbose logs are enabled automatically outside release builds. Set
`CHATBOT_VERBOSE_LOGS=false` to silence them, or `true` to force them on. API
logs include request/response body and ready-to-copy cURL commands. Each log
event is enclosed by a border and separated by a blank line. Filter by
`CHATBOT_LOG`; follow `seq`, `part=HEAD/DATA/CURL/ERROR/STACK`, and
`phase=START/STEP/OK/FAIL` to see where the flow stopped.

The native SDKs still require your backend to call `StartChatContact`; the app
expects `data.startChatResult.ContactId`, `ParticipantId`, and
`ParticipantToken`. The optional `data.featurePermissions.MESSAGING_MARKDOWN`
flag is also parsed.

iOS requires CocoaPods and a minimum deployment target of iOS 15.0.

For the full app flow, StartChatContact contract, SDK stream handling, and
Android/iOS integration checklist, see
[`docs/amazon_connect_chatbot_flow.md`](docs/amazon_connect_chatbot_flow.md).
