import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/murrtube_api.dart';
import 'cookie_loader.dart';

/// Export/import of all local app data (preferences + login cookies) as a
/// single JSON document so an account can be moved to another device.
class DataTransfer {
  static const _appMarker = 'murrmobile';
  static const _formatVersion = 1;

  /// Expected types for the keys this app reads. A wrong-typed value would
  /// throw inside SharedPreferences getters the next time it's read.
  static const _knownPrefTypes = <String, Type>{
    'age_confirmed': bool,
    'app_theme': String,
    'video_quality': String,
    'video_muted': bool,
    'navigation_mode': String,
  };

  static Future<String> exportJson() async {
    final prefs = await SharedPreferences.getInstance();
    final preferences = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      preferences[key] = prefs.get(key);
    }
    return jsonEncode({
      'app': _appMarker,
      'format_version': _formatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'preferences': preferences,
      // The live cookie jar can hold tokens the server rotated in after
      // login, which never get written back to the file.
      'cookies': MurrtubeApi.cookies ?? await CookieLoader.load(),
    });
  }

  static Future<File> exportToFile() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/murrmobile_backup.json');
    await file.writeAsString(await exportJson());
    return file;
  }

  /// Fallback for platforms without a share sheet (e.g. Linux): drops the
  /// backup into the documents directory.
  static Future<File> exportToDocuments() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/murrmobile_backup.json');
    await file.writeAsString(await exportJson());
    return file;
  }

  /// Applies a backup produced by [exportJson]. Throws [FormatException]
  /// when the content is not a Murrmobile backup.
  static Future<void> importJson(String content) async {
    final decoded = jsonDecode(content);
    if (decoded is! Map || decoded['app'] != _appMarker) {
      throw const FormatException('Not a Murrmobile backup');
    }
    final version = decoded['format_version'];
    if (version is int && version > _formatVersion) {
      throw const FormatException('Backup was made by a newer app version');
    }

    final rawPrefs = decoded['preferences'];
    if (rawPrefs is Map) {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in rawPrefs.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        final expected = _knownPrefTypes[key];
        if (expected == bool && value is! bool) continue;
        if (expected == String && value is! String) continue;
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is List) {
          await prefs.setStringList(
            key,
            value.map((e) => '$e').toList(),
          );
        }
      }
    }

    if (decoded.containsKey('cookies')) {
      final cookies = decoded['cookies'];
      if (cookies == null) {
        MurrtubeApi.clearCookies();
        await CookieLoader.clear();
      } else if (cookies is String && cookies.trim().isNotEmpty) {
        final trimmed = cookies.trim();
        // Pasted backups may carry Netscape-format cookie dumps; reduce
        // them to a Cookie header string before storing.
        final parsed =
            trimmed.contains('\n') ? CookieLoader.parse(trimmed) : trimmed;
        if (parsed == null) {
          throw const FormatException('Unreadable cookies in backup');
        }
        await CookieLoader.save(parsed);
        MurrtubeApi.setCookies(parsed);
      } else if (cookies is String) {
        MurrtubeApi.clearCookies();
        await CookieLoader.clear();
      } else {
        throw const FormatException('Invalid cookies in backup');
      }
    }
  }
}
