import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'app_strings.dart';
import 'database.dart';

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

      // Balíček písně {type: 'song', title, artist, content}
      if (decoded['type'] == 'song') {
        final title = (decoded['title'] as String?)?.trim() ?? '';
        final artist = (decoded['artist'] as String?)?.trim() ?? '';
        final content = (decoded['content'] as String?)?.trim() ?? '';
        if (title.isEmpty || content.isEmpty) {
          throw const FormatException();
        }
        final added = await widget.db.importSongPackage(
          title: title,
          artist: artist.isNotEmpty ? artist : 'Neznámý interpret',
          content: content,
        );
        _announce(added
            ? AppStrings.songImportSuccess(title)
            : AppStrings.songImportExists(title));
        return true;
      }

      // Playlist {name, songs} – v2 i starý formát
      if (decoded.containsKey('name') && decoded.containsKey('songs')) {
        final result = await widget.db.syncPlaylistFromJson(decoded);
        final hasTime = result.totalDurationShared > 0 || result.unknownShared > 0;
        final timeText = hasTime ? _formatImportTime(result.totalDurationShared, result.unknownShared) : null;
        final baseMessage = result.notFound.isEmpty
            ? AppStrings.playlistImportSuccess(result.playlistName, result.matchedCount)
            : '${AppStrings.playlistImportSuccess(result.playlistName, result.matchedCount)} '
                '${AppStrings.playlistImportMissing(result.notFound.length)}';
        final message = timeText != null ? '$baseMessage $timeText' : baseMessage;
        _announce(message);
        if (result.durationCandidates.isNotEmpty || result.diacriticCandidates.isNotEmpty) {
          await _showFixDialog(result);
        }
        return true;
      }

      throw const FormatException();
    } catch (_) {
      // Není to JSON balíček - starší QR kódy obsahují jen samotný text.
      return _confirmPlainTextImport(raw);
    }
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
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
    );
    if (confirm != true) return;
    int fixedTime = 0;
    int fixedDia = 0;
    if (timeCount > 0) fixedTime = await widget.db.applyMissingDurations(result.durationCandidates);
    if (diaCount > 0) fixedDia = await widget.db.applyDiacriticRepairs(result.diacriticCandidates);
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