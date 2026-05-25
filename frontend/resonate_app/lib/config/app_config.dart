class AppConfig {
  AppConfig._(); // prevent instantiation

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.0.2.2:3001',
  );

  static const String musicSearchUrl = '$baseUrl/api/music/search';
}
