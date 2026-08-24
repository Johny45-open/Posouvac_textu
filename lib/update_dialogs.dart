import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_progress_indicator.dart';
import 'app_strings.dart';
import 'update_checker.dart';

void _speak(String message) {
  final tts = FlutterTts();
  tts.setLanguage("cs-CZ");
  tts.setSpeechRate(0.5);
  tts.speak(message);
}

Future<void> _openUrl(BuildContext context, String? url) async {
  final fallbackUrl = 'https://github.com/Johny45-open/Posouvac_textu/releases';
  final target = (url != null && url.isNotEmpty) ? url : fallbackUrl;
  final uri = Uri.parse(target);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.updateCheckError)),
    );
  }
}

/// Stejné chování jako v Mluvici_kalkulacka: bez 24h cache, bez dismissed,
/// vždy volá /releases/latest s hlavičkami a timeoutem.
Future<void> runUpdateCheck(BuildContext context) async {
  _speak(AppStrings.updateChecking);

  // Jednoduchý průběh bez rušitelného Completeru – shodné s Kalkulačkou
  // (Kalkulačka nemá progress dialog, jen čeká na result).
  // Pro zachování UX Posouvače zobrazíme krátký neresitelný progress.
  bool progressShown = false;
  if (context.mounted) {
    progressShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: AppProgressIndicator(label: AppStrings.updateChecking),
      ),
    );
  }

  GitHubReleaseInfo? release;
  try {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = '${info.version}+${info.buildNumber}';
    final checker = GitHubReleaseChecker();
    release = await checker.checkForUpdates(
      owner: 'Johny45-open',
      repo: 'Posouvac_textu',
      currentVersion: currentVersion,
    );
    checker.close();
  } catch (_) {
    release = null;
  }

  if (progressShown && context.mounted) {
    Navigator.of(context).pop();
  }
  if (!context.mounted) return;

  if (release != null) {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    await showUpdateAvailableDialog(context, release, currentVersion);
  } else {
    _speak(AppStrings.updateUpToDate);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Semantics(header: true, child: Text(AppStrings.updateNewsTitle)),
        content: Text(AppStrings.updateUpToDate),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppStrings.updateCloseButton),
          ),
        ],
      ),
    );
  }
}

Future<void> showUpdateAvailableDialog(
  BuildContext context,
  GitHubReleaseInfo release,
  String currentVersion,
) async {
  _speak(AppStrings.updateAvailableMessage(release.normalizedVersion));
  final openBrowser = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Semantics(header: true, child: Text(AppStrings.updateAvailableTitle)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.updateAvailableMessage(release.normalizedVersion)),
            if (release.releaseSummary.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                AppStrings.updateNewsTitle,
                style: Theme.of(dialogContext).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(release.releaseSummary),
            ] else if (release.plainTextBody.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                AppStrings.updateNewsTitle,
                style: Theme.of(dialogContext).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(release.plainTextBody),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(AppStrings.updateCloseButton),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(AppStrings.updateOpenButton),
        ),
      ],
    ),
  );
  if (openBrowser == true && context.mounted) {
    await _openUrl(context, release.htmlUrl);
  }
}

Future<void> openReleaseHistory(BuildContext context) async {
  _speak(AppStrings.updateHistoryTitle);
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const ReleaseHistoryPage()),
  );
}

class ReleaseHistoryPage extends StatefulWidget {
  const ReleaseHistoryPage({super.key});

  @override
  State<ReleaseHistoryPage> createState() => _ReleaseHistoryPageState();
}

class _ReleaseHistoryPageState extends State<ReleaseHistoryPage> {
  final FlutterTts _tts = FlutterTts();
  List<GitHubReleaseInfo> _releases = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;
  String? _errorType;
  bool _showingCached = false;
  String? _cachedTimestamp;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadReleases();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage("cs-CZ");
      await _tts.setSpeechRate(0.5);
      _tts.setStartHandler(() {
        if (mounted) setState(() => _speaking = true);
      });
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _speaking = false);
      });
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _speaking = false);
      });
      _tts.setErrorHandler((msg) {
        if (mounted) setState(() => _speaking = false);
      });
    } catch (_) {}
  }

  Future<void> _speakNotes(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(clean);
    } catch (_) {}
  }

  void _readRelease(GitHubReleaseInfo release) {
    final notes = release.plainTextBody.replaceAll('\n', '. ');
    final parts = [
      AppStrings.newsVersionSpoken(release.normalizedVersion),
      if (notes.isNotEmpty) notes,
    ];
    _speakNotes(parts.join(' '));
  }

  void _readAll() {
    if (_releases.isEmpty) return;
    final buffer = StringBuffer();
    for (final release in _releases) {
      final notes = release.plainTextBody.replaceAll('\n', '. ');
      buffer.write('${AppStrings.newsVersionSpoken(release.normalizedVersion)} ');
      if (notes.isNotEmpty) buffer.write('$notes ');
    }
    _speakNotes(buffer.toString());
  }

  Future<void> _stopReading() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _loadReleases({bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _errorType = null;
        _showingCached = false;
        _cachedTimestamp = null;
        _currentPage = 1;
        _hasMore = true;
      });
    }

    final checker = GitHubReleaseChecker();
    final page = loadMore ? _currentPage + 1 : 1;
    final result = await checker.fetchRecentReleasesWithResult(
      owner: 'Johny45-open',
      repo: 'Posouvac_textu',
      perPage: 30,
      page: page,
    );
    checker.close();
    if (!mounted) return;

    if (result.isSuccess) {
      if (!loadMore) {
        await _saveCache(result.releases);
      }
      setState(() {
        if (loadMore) {
          _releases.addAll(result.releases);
          _currentPage = page;
          _loadingMore = false;
        } else {
          _releases = result.releases;
          _currentPage = 1;
          _loading = false;
        }
        _hasMore = result.releases.length == 30;
        if (_releases.isEmpty) {
          _error = AppStrings.updateHistoryEmpty;
          _errorType = 'empty';
        } else {
          _error = null;
          _errorType = null;
        }
        _showingCached = false;
        _cachedTimestamp = null;
      });
    } else {
      if (!loadMore && _releases.isEmpty) {
        final cached = await _loadCached();
        if (cached != null && cached.releases.isNotEmpty) {
          setState(() {
            _loading = false;
            _loadingMore = false;
            _releases = cached.releases;
            _cachedTimestamp = cached.timestamp;
            _error = _errorMessageForType(result.errorType!);
            _errorType = result.errorType;
            _showingCached = true;
            _hasMore = false;
          });
        } else {
          setState(() {
            _loading = false;
            _loadingMore = false;
            _error = _errorMessageForType(result.errorType!);
            _errorType = result.errorType;
          });
        }
      } else if (loadMore) {
        setState(() => _loadingMore = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessageForType(result.errorType!))),
          );
        }
      } else {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = _errorMessageForType(result.errorType!);
          _errorType = result.errorType;
        });
      }
    }
  }

  String _errorMessageForType(String type) {
    switch (type) {
      case 'offline':
        return 'Novinky se nepodařilo načíst. Zkontrolujte připojení k internetu.';
      case 'timeout':
        return 'Načítání novinek vypršelo. Zkuste to znovu.';
      case 'rateLimit':
        return 'Byl překročen limit GitHub API. Zkuste to znovu za hodinu.';
      case 'notFound':
        return 'Repozitář nebo novinky nebyly nalezeny.';
      case 'serverError':
        return 'Chyba serveru GitHub. Zkuste to znovu později.';
      case 'empty':
        return AppStrings.updateHistoryEmpty;
      default:
        return AppStrings.updateCheckError;
    }
  }

  Future<void> _saveCache(List<GitHubReleaseInfo> releases) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = releases
          .map((r) => {
                'tag_name': r.tagName,
                'html_url': r.htmlUrl,
                'body': r.body,
              })
          .toList();
      await prefs.setString('news_cache_json', jsonEncode(jsonList));
      await prefs.setString('news_cache_timestamp', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<({List<GitHubReleaseInfo> releases, String? timestamp})?> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('news_cache_json');
      final timestamp = prefs.getString('news_cache_timestamp');
      if (jsonStr == null) return null;
      final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
      final releases = decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => GitHubReleaseInfo(
                tagName: (m['tag_name'] as String?) ?? '',
                htmlUrl: m['html_url'] as String?,
                body: m['body'] as String?,
              ))
          .toList();
      if (releases.isEmpty) return null;
      return (releases: releases, timestamp: timestamp);
    } catch (_) {
      return null;
    }
  }

  String _formatCachedTimestamp(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$d.$m.$y $hh:$mm';
    } catch (_) {
      return iso;
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.updateHistoryTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.record_voice_over),
            tooltip: AppStrings.newsReadAllTooltip,
            onPressed: _releases.isEmpty ? null : _readAll,
          ),
          if (_speaking)
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: AppStrings.newsStopTooltip,
              onPressed: _stopReading,
            ),
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: AppStrings.updateRefreshTooltip,
            onPressed: _loading ? null : () => _loadReleases(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: AppProgressIndicator(label: AppStrings.updateChecking),
      );
    }
    if (_releases.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error ?? AppStrings.updateHistoryEmpty, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _loadReleases(),
              icon: const Icon(Icons.refresh),
              label: Text(AppStrings.retryButton),
            ),
          ],
        ),
      );
    }
    // Máme data – případně s bannerem o cache
    return ListView.builder(
      itemCount: _releases.length + (_hasMore && !_showingCached ? 1 : 0) + (_showingCached ? 1 : 0),
      itemBuilder: (context, index) {
        if (_showingCached && index == 0 && _error != null) {
          return Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                ),
                if (_cachedTimestamp != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Zobrazeny poslední uložené novinky z ${_formatCachedTimestamp(_cachedTimestamp)}.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _loadReleases(),
                  icon: const Icon(Icons.refresh),
                  label: Text(AppStrings.retryButton),
                ),
              ],
            ),
          );
        }
        final adjustedIndex = _showingCached ? index - 1 : index;
        if (adjustedIndex < 0) return const SizedBox.shrink();
        if (adjustedIndex >= _releases.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton.icon(
                      onPressed: () => _loadReleases(loadMore: true),
                      icon: const Icon(Icons.unfold_more),
                      label: Text(AppStrings.historyLoadOlderButton),
                    ),
            ),
          );
        }
        final release = _releases[adjustedIndex];
        final notes = release.plainTextBody;
        return ListTile(
          title: Text('Verze ${release.normalizedVersion}'),
          subtitle: notes.isEmpty ? null : Text(notes),
          trailing: IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: AppStrings.newsReadTooltip,
            onPressed: () => _readRelease(release),
          ),
          onTap: () => _openUrl(context, release.htmlUrl),
        );
      },
    );
  }
}