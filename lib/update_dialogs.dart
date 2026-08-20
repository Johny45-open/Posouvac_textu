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

Future<void> _showProgressDialog(BuildContext context, String label) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: AppProgressIndicator(label: label),
    ),
  );
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
  await _showProgressDialog(context, AppStrings.updateChecking);
  try {
    final result = await UpdateChecker.checkForUpdate();
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (result.hasUpdate) {
      await showUpdateAvailableDialog(context, result);
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
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    _speak(AppStrings.updateCheckError);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.updateCheckError)),
    );
  }
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
  await _showProgressDialog(context, AppStrings.updateChecking);
  try {
    final releases = await UpdateChecker.fetchReleases(includePrerelease: true);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    final ordered = releases.reversed.toList();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReleaseHistoryPage(releases: ordered),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    _speak(AppStrings.updateCheckError);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.updateCheckError)),
    );
  }
}

class ReleaseHistoryPage extends StatefulWidget {
  final List<ReleaseInfo> releases;

  const ReleaseHistoryPage({super.key, required this.releases});

  @override
  State<ReleaseHistoryPage> createState() => _ReleaseHistoryPageState();
}

class _ReleaseHistoryPageState extends State<ReleaseHistoryPage> {
  late List<ReleaseInfo> _releases;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _releases = widget.releases;
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final releases = await UpdateChecker.fetchReleases(
        includePrerelease: true,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() => _releases = releases.reversed.toList());
      _speak(AppStrings.updateHistoryRefreshed);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.updateCheckError)),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.updateHistoryTitle),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: AppStrings.updateRefreshTooltip,
            onPressed: _refreshing ? null : _refresh,
          ),
        ],
      ),
      body: _releases.isEmpty
          ? Center(child: Text(AppStrings.updateHistoryEmpty))
          : ListView.builder(
              itemCount: _releases.length,
              itemBuilder: (context, index) {
                final release = _releases[index];
                final notes = UpdateChecker.cleanMarkdown(release.body);
                return ListTile(
                  title: Text(release.name),
                  subtitle: notes.isEmpty ? null : Text(notes),
                  onTap: () => _openUrl(context, release.url),
                );
              },
            ),
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