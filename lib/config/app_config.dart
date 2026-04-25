class AppConfig {
  AppConfig._();

  static String get proxyBaseUrl => _normalizeProxyBaseUrl(
    const String.fromEnvironment(
      'ORACLE_URL',
      defaultValue: 'http://127.0.0.1:3001',
    ),
  );

  static String get tmdbReadToken =>
      const String.fromEnvironment('TMDB_TOKEN', defaultValue: '');

  static bool get hasTmdbReadToken => tmdbReadToken.trim().isNotEmpty;

  static bool get isDefaultLocalOracleUrl {
    return proxyBaseUrl == 'http://127.0.0.1:3001' ||
        proxyBaseUrl == 'http://localhost:3001';
  }

  static double get watchedRatio {
    const String rawValue = String.fromEnvironment(
      'WATCHED_RATIO',
      defaultValue: '0.90',
    );
    return double.tryParse(rawValue) ?? 0.90;
  }

  static String _trimTrailingSlash(String value) {
    return value.replaceFirst(RegExp(r'/+$'), '');
  }

  static String _normalizeProxyBaseUrl(String value) {
    final String trimmed = _trimTrailingSlash(value.trim());
    if (trimmed.isEmpty) {
      return '';
    }

    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return trimmed;
    }

    if (uri.hasPort) {
      return trimmed;
    }

    final Uri normalized = uri.replace(port: 3001);
    return normalized.toString();
  }
}
