import 'app_environment.dart';

class EnvironmentConfig {
  const EnvironmentConfig({
    required this.environment,
    required this.name,
    required this.baseUrl,
  });

  final AppEnvironment environment;
  final String name;
  final String baseUrl;
}
