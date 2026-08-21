import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_progress_indicator.dart';
import 'app_strings.dart';
import 'update_checker.dart';

const String dismissedUpdateVersionKey = 'dismissedUpdateVersion';

void _speak(String message) {
  final tts = FlutterTts();
  tts.setLanguage("cs-CZ");
  tts.setSpeechRate(0.5);
  tts.speak(message);
}

Future<void> _openUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.updateCheckError)),
    );
  }
}

Future<void> _rememberDismissedVersion(String tag) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(dismissedUpdateVersionKey, tag);
}

Future<void> runUpdateCheck(BuildContext context) async {
  _speak(AppStrings.updateChecking);

  UpdateCheckResult? result;
  Object? error;
  final checkFuture = () async {
    try {
      result = await UpdateChecker.checkForUpdate();
    } catch (e) {
      error = e;
    }
  }();

  // Zrušitelný průběh: uživatel může kontrolu kdykoli přerušit.
  // Dialog se vždy zavře jedinou cestou – ať klikne uživatel na Zrušit,
  // nebo doběhne kontrola – aby nemohlo dojít k dvojitému zavření.
  final userCancelled = Completer<void>();
  final closeDialog = Completer<void>();

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      content: AppProgressIndicator(label: AppStrings.updateChecking),
      actions: [
        TextButton(
          onPressed: () {
            if (!userCancelled.isCompleted) userCancelled.complete();
            if (!closeDialog.isCompleted) closeDialog.complete();
          },
          child: Text(AppStrings.progressCancelButton),
        ),
      ],
    ),
  ));

  unawaited(closeDialog.future.whenComplete(() {
    if (context.mounted) Navigator.of(context).pop();
  }));

  await Future.any([checkFuture, userCancelled.future]);
  if (!closeDialog.isCompleted) closeDialog.complete();
  await checkFuture;

  if (userCancelled.isCompleted || !context.mounted) return;

  if (error != null) {
    if (error is TimeoutException) {
      final retry = await _showTimeoutDialog(context);
      if (retry == true && context.mounted) {
        return runUpdateCheck(context);
      }
      return;
    }
    _speak(AppStrings.updateCheckError);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.updateCheckError)),
    );
    return;
  }

  if (result!.hasUpdate) {
    await showUpdateAvailableDialog(context, result!);
  } else {
    _speak(AppStrings.updateUpToDate);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.updateNewsTitle),
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

/// Dialog po vypršení časového limitu kontroly. Nabídne opakování.
Future<bool> _showTimeoutDialog(BuildContext context) async {
  _speak(AppStrings.updateCheckTimeout);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(AppStrings.updateTimeoutTitle),
          content: Text(AppStrings.updateCheckTimeout),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppStrings.updateCloseButton),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppStrings.retryButton),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> showUpdateAvailableDialog(
  BuildContext context,
  UpdateCheckResult result,
) async {
  final newest = result.newest!;
  _speak(AppStrings.updateAvailableMessage(newest.name));
  final openBrowser = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(AppStrings.updateAvailableTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.updateAvailableMessage(newest.name)),
            const SizedBox(height: 16),
            Text(
              AppStrings.updateNewsTitle,
              style: Theme.of(dialogContext).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final release in result.newerReleases)
              _ReleaseBlock(release: release),
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
  await _rememberDismissedVersion(newest.tag);
  if (openBrowser == true && context.mounted) {
    await _openUrl(context, newest.url);
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
  List<ReleaseInfo> _releases = [];
  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasMore = false;
  int _nextPage = 1;
  bool _error = false;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadFirstPage();
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

  void _readRelease(ReleaseInfo release) {
    final notes = UpdateChecker.cleanMarkdown(release.body).replaceAll('\n', '. ');
    final parts = [
      AppStrings.newsVersionSpoken(release.name),
      if (notes.isNotEmpty) notes,
    ];
    _speakNotes(parts.join(' '));
  }

  void _readAll() {
    if (_releases.isEmpty) return;
    final buffer = StringBuffer();
    for (final release in _releases) {
      final notes =
          UpdateChecker.cleanMarkdown(release.body).replaceAll('\n', '. ');
      buffer.write('${AppStrings.newsVersionSpoken(release.name)} ');
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

  /// Načte první stránku (nejnovější verze) – stránka je interaktivní hned.
  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final page = await UpdateChecker.fetchReleasePage(page: 1);
      if (!mounted) return;
      setState(() {
        _releases = page.releases.reversed.toList();
        _hasMore = page.hasMore;
        _nextPage = 2;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  /// Dohraže starší verze na vyžádání.
  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await UpdateChecker.fetchReleasePage(page: _nextPage);
      if (!mounted) return;
      setState(() {
        _releases.insertAll(0, page.releases.reversed.toList());
        _hasMore = page.hasMore;
        _nextPage++;
        _loadingOlder = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOlder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.updateCheckError)),
      );
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
            onPressed: _loading ? null : _loadFirstPage,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _releases.isEmpty) {
      return Center(
        child: AppProgressIndicator(label: AppStrings.updateChecking),
      );
    }
    if (_releases.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ? AppStrings.updateCheckError : AppStrings.updateHistoryEmpty),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadFirstPage,
              icon: const Icon(Icons.refresh),
              label: Text(AppStrings.retryButton),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _releases.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _releases.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _loadingOlder
                  ? const CircularProgressIndicator()
                  : OutlinedButton.icon(
                      onPressed: _loadOlder,
                      icon: const Icon(Icons.unfold_more),
                      label: Text(AppStrings.historyLoadOlderButton),
                    ),
            ),
          );
        }
        final release = _releases[index];
        final notes = UpdateChecker.cleanMarkdown(release.body);
        return ListTile(
          title: Text(release.name),
          subtitle: notes.isEmpty ? null : Text(notes),
          trailing: IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: AppStrings.newsReadTooltip,
            onPressed: () => _readRelease(release),
          ),
          onTap: () => _openUrl(context, release.url),
        );
      },
    );
  }
}

class _ReleaseBlock extends StatelessWidget {
  final ReleaseInfo release;

  const _ReleaseBlock({required this.release});

  @override
  Widget build(BuildContext context) {
    final notes = UpdateChecker.cleanMarkdown(release.body);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            release.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (notes.isNotEmpty)
            Text(notes),
        ],
      ),
    );
  }
}