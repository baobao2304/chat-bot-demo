import 'app_environment.dart';
import 'environment_config.dart';

class AppConfig {
  const AppConfig._(
    this.environmentConfig, {
    required this.baseUrl,
    required this.chatbotWebViewUrl,
    required this.startChatEndpoint,
    required this.connectInstanceId,
    required this.contactFlowId,
    required this.awsRegion,
    required this.customerName,
    required this.connectDisableCsm,
    required this.connectReceiptsEnabled,
    required this.connectReceiptThrottleSeconds,
    required this.connectDeliveredThrottleSeconds,
  });

  static const _chatbotApiBaseUrlOverride = String.fromEnvironment(
    'CHATBOT_API_BASE_URL',
  );
  static const _chatbotWebViewUrlOverride = String.fromEnvironment(
    'CHATBOT_WEBVIEW_URL',
  );
  static const _startChatEndpointOverride = String.fromEnvironment(
    'START_CHAT_ENDPOINT',
  );
  static const _connectInstanceIdOverride = String.fromEnvironment(
    'CONNECT_INSTANCE_ID',
  );
  static const _contactFlowIdOverride = String.fromEnvironment(
    'CONTACT_FLOW_ID',
  );
  static const _awsRegionOverride = String.fromEnvironment('AWS_REGION');
  static const _customerNameOverride = String.fromEnvironment('CUSTOMER_NAME');
  static const _connectDisableCsmOverride = String.fromEnvironment(
    'CONNECT_DISABLE_CSM',
  );
  static const _connectReceiptsEnabledOverride = String.fromEnvironment(
    'CONNECT_RECEIPTS_ENABLED',
  );
  static const _connectReceiptThrottleOverride = String.fromEnvironment(
    'CONNECT_RECEIPT_THROTTLE_SECONDS',
  );
  static const _connectDeliveredThrottleOverride = String.fromEnvironment(
    'CONNECT_DELIVERED_THROTTLE_SECONDS',
  );

  static final AppConfig current = AppConfig._fromEnvironment(
    AppEnvironment.current,
  );

  final EnvironmentConfig environmentConfig;
  final String baseUrl;
  final String chatbotWebViewUrl;
  final String startChatEndpoint;
  final String connectInstanceId;
  final String contactFlowId;
  final String awsRegion;
  final String customerName;
  final bool connectDisableCsm;
  final bool connectReceiptsEnabled;
  final double connectReceiptThrottleSeconds;
  final double connectDeliveredThrottleSeconds;

  String get environmentName => environmentConfig.name;

  AppEnvironment get environment => environmentConfig.environment;

  bool get hasAmazonConnectConfig =>
      startChatEndpoint.isNotEmpty &&
      connectInstanceId.isNotEmpty &&
      contactFlowId.isNotEmpty &&
      awsRegion.isNotEmpty;

  bool get hasChatbotWebViewConfig => chatbotWebViewUrl.isNotEmpty;

  factory AppConfig._fromEnvironment(AppEnvironment environment) {
    final environmentConfig = _configFor(environment);

    return AppConfig._(
      environmentConfig,
      baseUrl: _stringOverride(
        _chatbotApiBaseUrlOverride,
        environmentConfig.baseUrl,
      ),
      chatbotWebViewUrl: _stringOverride(
        _chatbotWebViewUrlOverride,
        environmentConfig.chatbotWebViewUrl,
      ),
      startChatEndpoint: _stringOverride(
        _startChatEndpointOverride,
        environmentConfig.startChatEndpoint,
      ),
      connectInstanceId: _stringOverride(
        _connectInstanceIdOverride,
        environmentConfig.connectInstanceId,
      ),
      contactFlowId: _stringOverride(
        _contactFlowIdOverride,
        environmentConfig.contactFlowId,
      ),
      awsRegion: _stringOverride(
        _awsRegionOverride,
        environmentConfig.awsRegion,
      ),
      customerName: _stringOverride(
        _customerNameOverride,
        environmentConfig.customerName,
      ),
      connectDisableCsm: _boolOverride(
        _connectDisableCsmOverride,
        environmentConfig.connectDisableCsm,
      ),
      connectReceiptsEnabled: _boolOverride(
        _connectReceiptsEnabledOverride,
        environmentConfig.connectReceiptsEnabled,
      ),
      connectReceiptThrottleSeconds: _parseDouble(
        _connectReceiptThrottleOverride,
        fallback: environmentConfig.connectReceiptThrottleSeconds,
      ),
      connectDeliveredThrottleSeconds: _parseDouble(
        _connectDeliveredThrottleOverride,
        fallback: environmentConfig.connectDeliveredThrottleSeconds,
      ),
    );
  }

  static String _stringOverride(String override, String fallback) {
    final trimmedOverride = override.trim();
    return trimmedOverride.isNotEmpty ? trimmedOverride : fallback;
  }

  static bool _boolOverride(String override, bool fallback) {
    final normalized = override.trim().toLowerCase();
    switch (normalized) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
      default:
        return fallback;
    }
  }

  static double _parseDouble(String value, {required double fallback}) {
    return double.tryParse(value.trim()) ?? fallback;
  }

  static EnvironmentConfig _configFor(AppEnvironment environment) {
    switch (environment) {
      case AppEnvironment.dev:
        return _dev;
      case AppEnvironment.staging:
        return _staging;
      case AppEnvironment.prod:
        return _prod;
    }
  }

  static const _dev = EnvironmentConfig(
    environment: AppEnvironment.dev,
    name: 'dev',
    baseUrl: 'http://localhost:3000',
    chatbotWebViewUrl: '',
    startChatEndpoint:
        'https://omxid97jx6.execute-api.ap-southeast-1.amazonaws.com/start-chat',
    connectInstanceId: 'be4e4fdc-fc5f-488a-96e6-dc3603219c93',
    contactFlowId: 'a7bb5042-8393-4f82-96d7-a737c7715e55',
    awsRegion: 'ap-southeast-1',
    customerName: 'CUSTOMER',
    connectDisableCsm: false,
    connectReceiptsEnabled: true,
    connectReceiptThrottleSeconds: 5.0,
    connectDeliveredThrottleSeconds: 3.0,
  );

  static const _staging = EnvironmentConfig(
    environment: AppEnvironment.staging,
    name: 'staging',
    baseUrl: 'https://staging-api.example.com',
    chatbotWebViewUrl: '',
    startChatEndpoint: '',
    connectInstanceId: '',
    contactFlowId: '',
    awsRegion: 'ap-southeast-1',
    customerName: 'CUSTOMER',
    connectDisableCsm: false,
    connectReceiptsEnabled: true,
    connectReceiptThrottleSeconds: 5.0,
    connectDeliveredThrottleSeconds: 3.0,
  );

  static const _prod = EnvironmentConfig(
    environment: AppEnvironment.prod,
    name: 'prod',
    baseUrl: 'https://api.example.com',
    chatbotWebViewUrl: '',
    startChatEndpoint: '',
    connectInstanceId: '',
    contactFlowId: '',
    awsRegion: 'ap-southeast-1',
    customerName: 'CUSTOMER',
    connectDisableCsm: false,
    connectReceiptsEnabled: true,
    connectReceiptThrottleSeconds: 5.0,
    connectDeliveredThrottleSeconds: 3.0,
  );
}
