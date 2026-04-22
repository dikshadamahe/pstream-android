class AppConfig {
  AppConfig._();

  static String get proxyBaseUrl => _trimTrailingSlash(
    const String.fromEnvironment(
      'ORACLE_URL',
      defaultValue: 'http://127.0.0.1:3001',
    ),
  );

  static String get tmdbReadToken =>
      const String.fromEnvironment('TMDB_TOKEN', defaultValue: '');

  static String _trimTrailingSlash(String value) {
    return value.replaceFirst(RegExp(r'/+$'), '');
  }
}
