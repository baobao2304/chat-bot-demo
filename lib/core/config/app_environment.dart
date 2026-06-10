enum AppEnvironment {
  dev,
  staging,
  prod;

  static const _environmentValue = String.fromEnvironment('APP_ENV');

  static AppEnvironment get current => fromValue(_environmentValue);

  static AppEnvironment fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'staging':
        return AppEnvironment.staging;
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      case 'dev':
      case 'development':
      case '':
        return AppEnvironment.dev;
      default:
        return AppEnvironment.dev;
    }
  }
}
