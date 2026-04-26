import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pstream_android/config/app_config.dart';

/// Append-only text log for Oracle/network issues. File lives under app
/// documents so you can `adb pull` or use **Settings → Copy network debug log**.
class OracleDebugLog {
  OracleDebugLog._();

  static const String _fileName = 'veil_network_debug.txt';
  static const String _folderName = 'VeilDiagnostics';
  static const int _maxBytes = 240000;

  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
    'User-Agent': 'Veil/1.0 (Android; debug-log)',
  };

  static Future<File?> _targetFile() async {
    try {
      final Directory root = await getApplicationDocumentsDirectory();
      final Directory folder = Directory('${root.path}/$_folderName');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      return File('${folder.path}/$_fileName');
    } on Object catch (e, st) {
      debugPrint('OracleDebugLog._targetFile: $e\n$st');
      return null;
    }
  }

  static Future<void> append(String line) async {
    final File? file = await _targetFile();
    if (file == null) {
      return;
    }
    final String ts = DateTime.now().toUtc().toIso8601String();
    final String row = '$ts  $line\n';
    try {
      if (await file.exists()) {
        final int len = await file.length();
        if (len > _maxBytes) {
          final String old = await file.readAsString();
          const String marker = '--- truncated ---\n';
          final int keep = (_maxBytes ~/ 2) - marker.length;
          final String tail =
              old.length <= keep ? old : old.substring(old.length - keep);
          await file.writeAsString('$marker$tail$row', flush: true);
          return;
        }
      }
      await file.writeAsString(row, mode: FileMode.append, flush: true);
    } on Object catch (e, st) {
      debugPrint('OracleDebugLog.append: $e\n$st');
    }
  }

  /// Call once after [WidgetsFlutterBinding.ensureInitialized] (e.g. from [main]).
  static Future<void> recordStartup() async {
    await append(
      'BOOT '
      'proxyBaseUrl=${AppConfig.proxyBaseUrl} '
      'tmdbTokenSet=${AppConfig.hasTmdbReadToken} '
      'defaultLocalOracle=${AppConfig.isDefaultLocalOracleUrl} '
      'scrapeOrder=${AppConfig.scrapeSourceOrder} '
      'kDebugMode=$kDebugMode',
    );
    await _probeHealth();
  }

  static Future<void> _probeHealth() async {
    final String base = AppConfig.proxyBaseUrl;
    if (base.isEmpty ||
        AppConfig.isDefaultLocalOracleUrl ||
        !Uri.parse(base).hasScheme) {
      await append('HEALTH skip (no usable Oracle URL)');
      return;
    }
    final Uri uri = Uri.parse(base.endsWith('/') ? '${base}health' : '$base/health');
    final Stopwatch sw = Stopwatch()..start();
    final http.Client client = http.Client();
    try {
      final http.Response res =
          await client.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      sw.stop();
      await append(
        'HEALTH GET ${uri.toString()} '
        'http=${res.statusCode} '
        '${sw.elapsedMilliseconds}ms '
        'bodyPrefix=${_prefix(res.body, 160)}',
      );
    } on TimeoutException catch (e) {
      sw.stop();
      await append('HEALTH TIMEOUT ${uri.toString()} after ${sw.elapsedMilliseconds}ms ($e)');
    } on SocketException catch (e) {
      sw.stop();
      await append('HEALTH SOCKET ${uri.toString()} ($e)');
    } on Object catch (e) {
      sw.stop();
      await append('HEALTH ERROR ${uri.toString()} ($e)');
    } finally {
      client.close();
    }
  }

  static String _prefix(String body, int max) {
    final String t = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length <= max) {
      return t;
    }
    return '${t.substring(0, max)}…';
  }

  /// Full file text for clipboard / paste, or null if missing / unreadable.
  static Future<String?> readAllForExport() async {
    final File? file = await _targetFile();
    if (file == null || !await file.exists()) {
      return null;
    }
    try {
      return await file.readAsString();
    } on Object {
      return null;
    }
  }

  static Future<String?> logFilePathForDisplay() async {
    final File? file = await _targetFile();
    return file?.path;
  }
}
