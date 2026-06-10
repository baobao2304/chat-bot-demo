import 'app_environment.dart';
import 'environment_config.dart';

class AppConfig {
  const AppConfig._(this.environmentConfig, {required this.baseUrl});

  static const _chatbotApiBaseUrlOverride = String.fromEnvironment(
    'CHATBOT_API_BASE_URL',
  );

  static final AppConfig current = AppConfig._fromEnvironment(
    AppEnvironment.current,
  );

  final EnvironmentConfig environmentConfig;
  final String baseUrl;

  String get environmentName => environmentConfig.name;

  AppEnvironment get environment => environmentConfig.environment;

  factory AppConfig._fromEnvironment(AppEnvironment environment) {
    final environmentConfig = _configFor(environment);
    final overrideBaseUrl = _chatbotApiBaseUrlOverride.trim();

    return AppConfig._(
      environmentConfig,
      baseUrl: overrideBaseUrl.isNotEmpty
          ? overrideBaseUrl
          : environmentConfig.baseUrl,
    );
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
    baseUrl: 'http://10.0.2.2:3000',
  );

  static const _staging = EnvironmentConfig(
    environment: AppEnvironment.staging,
    name: 'staging',
    baseUrl: 'https://staging-api.example.com',
  );

  static const _prod = EnvironmentConfig(
    environment: AppEnvironment.prod,
    name: 'prod',
    baseUrl: 'https://api.example.com',
  );
}
