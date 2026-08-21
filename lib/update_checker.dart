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

/// Výsledek stažení jedné stránky verzí z GitHubu.
class PagedReleases {
  final List<ReleaseInfo> releases;
  final bool hasMore;

  const PagedReleases({required this.releases, required this.hasMore});
}

class UpdateChecker {
  static const String _releasesApiUrl =
      'https://api.github.com/repos/Johny45-open/Posouvac_textu/releases';
  static const String _fallbackUrl =
      'https://github.com/Johny45-open/Posouvac_textu/releases';

  static const String _cacheKeyReleases = 'cachedReleasesJson';
  static const String _cacheKeyReleasesAt = 'cachedReleasesAt';
  static const Duration _cacheTtl = Duration(hours: 24);
  static const int _perPage = 100;
  static const int _maxPages = 10;

  /// Timeout jednoho HTTP požadavku.
  static const Duration _requestTimeout = Duration(seconds: 8);

  /// Celkový limit kontroly aktualizací – po jeho vypršení se použijí
  /// uložená data nebo vrátí chyba "vypršel čas".
  static const Duration _checkDeadline = Duration(seconds: 10);

  /// Rychlá kontrola aktualizací: nejprve mezipaměť (24 h), při jejím
  /// chybění stahuje stránky jen do okamžiku, kdy narazí na verzi
  /// starší nebo stejnou jako aktuální (typicky stačí 1 požadavek).
  /// Celé kontrolě běží pod časovým limitem; po vypršení se použijí
  /// i starší uložená data.
  static Future<UpdateCheckResult> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final prefs = await SharedPreferences.getInstance();

    final cached = _readCache(prefs, ignoreTtl: false);
    if (cached != null) {
      return _resultFromList(cached, currentVersion);
    }

    try {
      final fresh = await _fetchNewerFromGithub(currentVersion)
          .timeout(_checkDeadline);
      await _writeCache(prefs, fresh.fetched);
      return _resultFromList(fresh.newer, currentVersion);
    } catch (_) {
      // Sit bez odpovedi nebo pomale site – zkusime aspon starsi cache.
      final stale = _readCache(prefs, ignoreTtl: true);
      if (stale != null) {
        return _resultFromList(stale, currentVersion);
      }
      rethrow;
    }
  }

  static UpdateCheckResult _resultFromList(
    List<ReleaseInfo> releases,
    String currentVersion,
  ) {
    final newer = releases
        .where((r) => isNewer(r.tag, currentVersion))
        .toList();
    return UpdateCheckResult(
      currentVersion: currentVersion,
      newerReleases: newer,
    );
  }

  /// Stahuje stránky verzí (od nejnovějších) a končí, jakmile narazí na
  /// stabilní verzi, která není novější než aktuální. Prerelease verze se
  /// při rozhodování o zastavení přeskočí – v novinkách se nepočítají.
  static Future<({List<ReleaseInfo> fetched, List<ReleaseInfo> newer})>
      _fetchNewerFromGithub(String currentVersion) async {
    final fetched = <ReleaseInfo>[];
    final newer = <ReleaseInfo>[];
    var page = 1;
    while (page <= _maxPages) {
      final pageItems = await _fetchPage(page);
      if (pageItems.isEmpty) break;
      fetched.addAll(pageItems);

      var reachedCurrent = false;
      for (final release in pageItems) {
        if (release.isPrerelease) continue;
        if (isNewer(release.tag, currentVersion)) {
          newer.add(release);
        } else {
          reachedCurrent = true;
        }
      }
      if (reachedCurrent) break;
      page++;
    }
    return (fetched: fetched, newer: newer);
  }

  /// Jedna stránka verzí pro Historii verzí. Neukládá se do mezipaměti –
  /// stránka se stahuje rychle a historii chceme vždy aktuální.
  static Future<PagedReleases> fetchReleasePage({required int page}) async {
    final items = await _fetchPage(page);
    return PagedReleases(
      releases: items,
      hasMore: items.length >= _perPage && page < _maxPages,
    );
  }

  static Future<List<ReleaseInfo>> _fetchPage(int page) async {
    final uri = Uri.parse(_releasesApiUrl).replace(
      queryParameters: {'per_page': '$_perPage', 'page': '$page'},
    );
    final response = await http.get(uri).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('GitHub API odpovědělo chybou ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    final releases = <ReleaseInfo>[];
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