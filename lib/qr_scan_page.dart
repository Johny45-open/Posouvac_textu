import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';
import 'database.dart';
import 'dev_log.dart';
import 'player_page.dart';

/// Skener QR kódů pro offline import písní do knihovny.
/// Rozpozná balíček písně, playlist i obyčejný text a uloží ho do knihovny.
class QrScanPage extends StatefulWidget {
  final AppDatabase db;

  const QrScanPage({super.key, required this.db});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final FlutterTts _tts = FlutterTts();
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('cs-CZ');
    _tts.setSpeechRate(0.5);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tts.speak(AppStrings.scanQrInstruction);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;
      _handleScanned(value);
      return;
    }
  }

  Future<void> _handleScanned(String raw) async {
    _processing = true;
    final handled = await _importFromString(raw);
    if (!mounted) return;
    if (handled) {
      Navigator.of(context).pop();
    } else {
      setState(() => _processing = false);
    }
  }

  Future<bool> _importFromString(String raw) async {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      if (decoded['type'] == 'song') {
        final title = (decoded['title'] as String?)?.trim() ?? '';
        final artist = (decoded['artist'] as String?)?.trim() ?? '';
        final content = (decoded['content'] as String?)?.trim() ?? '';
        if (title.isEmpty || content.isEmpty) {
          throw const FormatException();
        }
        double? tempo = decoded['tempo'] is num ? (decoded['tempo'] as num).toDouble() : double.tryParse(decoded['tempo']?.toString() ?? '');
        double? scrollSpeed = decoded['scrollSpeed'] is num ? (decoded['scrollSpeed'] as num).toDouble() : double.tryParse(decoded['scrollSpeed']?.toString() ?? '');
        double? fontSize = decoded['fontSize'] is num ? (decoded['fontSize'] as num).toDouble() : double.tryParse(decoded['fontSize']?.toString() ?? '');
        double? introDuration = decoded['introDuration'] is num ? (decoded['introDuration'] as num).toDouble() : double.tryParse(decoded['introDuration']?.toString() ?? '');
        int? duration = decoded['duration'] is int ? decoded['duration'] as int : int.tryParse(decoded['duration']?.toString() ?? '');
        List<Map<String,dynamic>>? stopMarks;
        if (decoded['stopMarks'] is List) {
          stopMarks = [];
          for (final m in (decoded['stopMarks'] as List)) {
            if (m is! Map) continue;
            final mm = Map<String,dynamic>.from(m as Map);
            int? bars = mm['bars'] is int ? mm['bars'] as int : int.tryParse(mm['bars']?.toString() ?? '2') ?? 2;
            stopMarks.add({'bars': bars, 'lineText': mm['lineText']?.toString() ?? '', 'lineIndex': mm['lineIndex']});
          }
        }
        final songId = await widget.db.importOrUpdateSongPackage(title: title, artist: artist.isNotEmpty ? artist : 'Neznámý interpret', content: content, tempo: tempo, scrollSpeed: scrollSpeed, fontSize: fontSize, introDuration: introDuration, duration: duration, stopMarksParam: stopMarks);
        if (songId != null) {
          _announce(AppStrings.songImportSuccess(title));
          final prefs = await SharedPreferences.getInstance();
          final auto = prefs.getBool('autoOpenReceived') ?? false;
          if (auto) {
            await _openSong(songId);
          } else {
            final open = await _askOpenSong(title, artist);
            if (open == true) await _openSong(songId);
          }
        } else {
          _announce(AppStrings.songImportExists(title));
        }
        return true;
      }
      if (decoded.containsKey('name') && decoded.containsKey('songs')) {
        final result = await widget.db.syncPlaylistFromJson(decoded);
        final hasTime = result.totalDurationShared > 0 || result.unknownShared > 0;
        final timeText = hasTime ? _formatImportTime(result.totalDurationShared, result.unknownShared) : null;
        final baseMessage = result.notFound.isEmpty
            ? AppStrings.playlistImportSuccess(result.playlistName, result.matchedCount)
            : '${AppStrings.playlistImportSuccess(result.playlistName, result.matchedCount)} ${AppStrings.playlistImportMissing(result.notFound.length)}';
        final message = timeText != null ? '$baseMessage $timeText' : baseMessage;
        _announce(message);
        if (result.durationCandidates.isNotEmpty || result.diacriticCandidates.isNotEmpty) {
          await _showFixDialog(result);
        }
        try {
          final pls = await widget.db.getAllPlaylists();
          int? pid;
          for (final p in pls) if (p.name == result.playlistName) { pid = p.id; break; }
          if (pid != null) {
            final ids = await widget.db.getPlaylistSongIds(pid);
            if (ids.isNotEmpty) {
              final prefs = await SharedPreferences.getInstance();
              final auto = prefs.getBool('autoOpenReceived') ?? false;
              if (auto) {
                await _openPlaylistSong(ids.first, ids, pid);
              } else {
                final open = await _askOpenPlaylist(result.playlistName, ids.length);
                if (open == true) await _openPlaylistSong(ids.first, ids, pid);
              }
            }
          }
        } catch (_) {}
        return true;
      }
      throw const FormatException();
    } catch (_) {
      return _confirmPlainTextImport(raw);
    }
  }

  Future<bool?> _askOpenSong(String title, String artist) async {
    if (!mounted) return false;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: const Text("Přijata píseň")),
        content: Semantics(liveRegion: true, child: Text("$title ${artist.isNotEmpty ? 'od $artist' : ''}\nOtevřít v přehrávači?")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Ne")),
          FilledButton(autofocus: true, onPressed: () => Navigator.pop(context, true), child: const Text("Ano, otevřít")),
        ],
      ),
    );
  }

  Future<bool?> _askOpenPlaylist(String name, int count) async {
    if (!mounted) return false;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: Text("Přijat setlist $name")),
        content: Semantics(liveRegion: true, child: Text("$count písní. Otevřít první píseň?")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Ne")),
          FilledButton(autofocus: true, onPressed: () => Navigator.pop(context, true), child: const Text("Ano, otevřít")),
        ],
      ),
    );
  }

  Future<void> _openSong(int songId) async {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(songId: songId, db: widget.db)));
  }

  Future<void> _openPlaylistSong(int songId, List<int> ids, int pid) async {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(songId: songId, db: widget.db, setlistIds: ids, playlistId: pid)));
  }

  Future<bool> _confirmPlainTextImport(String rawText) async {
    final titleController =
        TextEditingController(text: AppStrings.scanPlainDefaultTitle);
    final artistController =
        TextEditingController(text: AppStrings.scanPlainDefaultArtist);
    final content = rawText.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: Text(AppStrings.scanPlainDialogTitle)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.scanPlainDialogText),
              const SizedBox(height: 16),
              TextFormField(
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: AppStrings.scanPlainTitleLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: artistController,
                decoration: InputDecoration(
                  labelText: AppStrings.scanPlainArtistLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.scanPlainPreviewLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: SelectableText(content),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importovat'),
          ),
        ],
      ),
    );

    final title = titleController.text.trim();
    if (confirmed == true && title.isNotEmpty) {
      final artist = artistController.text.trim();
      final added = await widget.db.importSongPackage(
        title: title,
        artist: artist.isNotEmpty ? artist : 'Neznámý interpret',
        content: content.isEmpty ? title : content,
      );
      _announce(added
          ? AppStrings.songImportSuccess(title)
          : AppStrings.songImportExists(title));
      return true;
    }
    return false;
  }

  String _formatImportTime(int totalSec, int unknown) {
    if (totalSec <= 0 && unknown == 0) return "";
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    final base = totalSec > 0 ? "Celkový čas: $m:${s.toString().padLeft(2, '0')}" : "Čas neurčen";
    if (unknown == 0) return base;
    return AppStrings.setlistTimeWithUnknown(base, unknown);
  }

  String _formatDurationShort(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  Future<void> _showFixDialog(PlaylistSyncResult result) async {
    if (!mounted) return;
    final timeCount = result.durationCandidates.length;
    final diaCount = result.diacriticCandidates.length;
    final prefs = await SharedPreferences.getInstance();
    bool renameFiles = prefs.getBool('diacriticRenameFiles') ?? false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => SimpleDialog(
          title: Semantics(header: true, child: Text(AppStrings.playlistFixDialogTitle)),
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text(AppStrings.playlistFixDialogContent(timeCount, diaCount))),
            if (timeCount > 0)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4), child: Semantics(header: true, child: Text("Chybějící časy:", style: const TextStyle(fontWeight: FontWeight.bold)))),
            for (final c in result.durationCandidates.take(5))
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2), child: Text(AppStrings.playlistFixTimeItem(c.artist, c.title, _formatDurationShort(c.newDuration)), style: const TextStyle(fontSize: 13))),
            if (timeCount > 5) Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text("... a dalších ${timeCount - 5}", style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
            if (diaCount > 0)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4), child: Semantics(header: true, child: Text("Oprava diakritiky:", style: const TextStyle(fontWeight: FontWeight.bold)))),
            for (final c in result.diacriticCandidates.take(5))
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2), child: Text(AppStrings.playlistFixDiaItem(c.oldArtist, c.oldTitle, c.newArtist, c.newTitle), style: const TextStyle(fontSize: 13))),
            if (diaCount > 5) Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text("... a dalších ${diaCount - 5}", style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
            if (diaCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Semantics(
                  label: renameFiles ? "Přejmenovat i soubory, zaškrtnuto" : "Přejmenovat i soubory, nezaškrtnuto",
                  child: CheckboxListTile(
                    title: const Text("Přejmenovat i soubory"),
                    subtitle: const Text("Na Windows může selhat, pokud je soubor otevřen"),
                    value: renameFiles,
                    onChanged: (v) {
                      setDialogState(() => renameFiles = v ?? false);
                      DevLog.log("QR fix checkbox renameFiles=$v");
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.playlistFixSkipLabel)),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.playlistFixConfirmLabel)),
              ]),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    await prefs.setBool('diacriticRenameFiles', renameFiles);
    int fixedTime = 0;
    int fixedDia = 0;
    if (timeCount > 0) fixedTime = await widget.db.applyMissingDurations(result.durationCandidates);
    if (diaCount > 0) {
      final res = await widget.db.applyDiacriticRepairs(result.diacriticCandidates, renameFiles: renameFiles);
      fixedDia = res.dbUpdated;
      if (res.filesFailed > 0) DevLog.log("QR fix failed rename: ${res.failedPaths.join(', ')}");
    }
    final doneMsg = AppStrings.playlistFixDone(fixedTime, fixedDia);
    _tts.speak(doneMsg);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(doneMsg)));
  }

  void _announce(String message) {
    _tts.speak(message);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.scanQrPageTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              AppStrings.scanQrInstruction,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.no_photography, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          AppStrings.scanQrPermissionError,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
