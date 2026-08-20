import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReleaseInfo {
  final String tag;
  final String name;
  final String body;
  final String url;
  final bool isPrerelease;

  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.body,
    required this.url,
    this.isPrerelease = false,
  });

  Map<String, dynamic> toJson() => {
    'tag': tag,
    'name': name,
    'body': body,
    'url': url,
    'isPrerelease': isPrerelease,
  };

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) => ReleaseInfo(
    tag: json['tag'] as String,
    name: json['name'] as String,
    body: json['body'] as String? ?? '',
    url: json['url'] as String,
    isPrerelease: json['isPrerelease'] as bool? ?? false,
  );
}

class UpdateCheckResult {
  final String currentVersion;
  final List<ReleaseInfo> newerReleases;

  const UpdateCheckResult({
    required this.currentVersion,
    required this.newerReleases,
  });

  bool get hasUpdate => newerReleases.isNotEmpty;
  ReleaseInfo? get newest => newerReleases.isEmpty ? null : newerReleases.first;
}

class UpdateChecker {
  static const String _releasesApiUrl =
      'https://api.github.com/repos/Johny45-open/Posouvac_textu/releases';
  static const String _fallbackUrl =
      'https://github.com/Johny45-open/Posouvac_textu/releases';

  static const String _cacheKeyReleases = 'cachedReleasesJson';
  static const String _cacheKeyReleasesAt = 'cachedReleasesAt';
  static const Duration _cacheTtl = Duration(hours: 24);
  static const int _maxReleases = 1000;
  static const int _perPage = 100;

  static Future<List<ReleaseInfo>> fetchReleases({
    bool includePrerelease = false,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = _readCache(prefs, ignoreTtl: false);
      if (cached != null) return _filterPrerelease(cached, includePrerelease);
    }
    try {
      final fresh = await _fetchAllFromGithub();
      await _writeCache(prefs, fresh);
      return _filterPrerelease(fresh, includePrerelease);
    } catch (_) {
      final cached = _readCache(prefs, ignoreTtl: true);
      if (cached != null) return _filterPrerelease(cached, includePrerelease);
      rethrow;
    }
  }

  static Future<UpdateCheckResult> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final releases = await fetchReleases();
    final newer = releases
        .where((r) => isNewer(r.tag, currentVersion))
        .toList();
    return UpdateCheckResult(
      currentVersion: currentVersion,
      newerReleases: newer,
    );
  }

  static Future<List<ReleaseInfo>> _fetchAllFromGithub() async {
    final releases = <ReleaseInfo>[];
    var page = 1;
    while (page * _perPage <= _maxReleases) {
      final uri = Uri.parse(_releasesApiUrl).replace(
        queryParameters: {'per_page': '$_perPage', 'page': '$page'},
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('GitHub API odpovědělo chybou ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as List<dynamic>;
      if (data.isEmpty) break;

      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final tag = item['tag_name'] as String?;
        if (tag == null) continue;
        if (item['draft'] == true) continue;
        releases.add(ReleaseInfo(
          tag: tag,
          name: (item['name'] as String?)?.trim().isNotEmpty == true
              ? (item['name'] as String).trim()
              : tag,
          body: (item['body'] as String?) ?? '',
          url: (item['html_url'] as String?) ?? _fallbackUrl,
          isPrerelease: item['prerelease'] == true,
        ));
      }
      page++;
    }
    return releases;
  }

  static List<ReleaseInfo>? _readCache(
    SharedPreferences prefs, {
    required bool ignoreTtl,
  }) {
    final at = prefs.getInt(_cacheKeyReleasesAt);
    if (at == null) return null;
    if (!ignoreTtl) {
      final age = DateTime.now().millisecondsSinceEpoch - at;
      if (age > _cacheTtl.inMilliseconds) return null;
    }
    final raw = prefs.getString(_cacheKeyReleases);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(ReleaseInfo.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(
    SharedPreferences prefs,
    List<ReleaseInfo> releases,
  ) async {
    final json = jsonEncode(releases.map((r) => r.toJson()).toList());
    await prefs.setString(_cacheKeyReleases, json);
    await prefs.setInt(_cacheKeyReleasesAt, DateTime.now().millisecondsSinceEpoch);
  }

  static List<ReleaseInfo> _filterPrerelease(
    List<ReleaseInfo> releases,
    bool includePrerelease,
  ) {
    if (includePrerelease) return releases;
    return releases.where((r) => !r.isPrerelease).toList();
  }

  static List<int> parseVersion(String version) {
    final cleaned = version.replaceFirst(RegExp(r'^[vV]'), '').trim();
    final parts = cleaned
        .split(RegExp(r'[.\-]'))
        .take(3)
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  static bool isNewer(String candidate, String current) {
    final a = parseVersion(candidate);
    final b = parseVersion(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return false;
  }

  static String cleanMarkdown(String text) {
    var t = text;
    t = t.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    t = t.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
    t = t.replaceAll(RegExp(r'\*(.+?)\*'), r'$1');
    t = t.replaceAll(RegExp(r'\[(.+?)\]\([^)]+\)'), r'$1');
    t = t.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '\u2022 ');
    t = t.replaceAll('`', '');
    return t.trim();
  }
}