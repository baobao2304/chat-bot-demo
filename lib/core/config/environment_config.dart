import 'app_environment.dart';

class EnvironmentConfig {
  const EnvironmentConfig({
    required this.environment,
    required this.name,
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

  final AppEnvironment environment;
  final String name;
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
}
