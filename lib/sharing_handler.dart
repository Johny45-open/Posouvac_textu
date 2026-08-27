import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';
import 'database.dart';
import 'dev_log.dart';
import 'playlists_page.dart';
import 'song_import_service.dart';

/// Zajišťuje příjem sdílených playlistů (souborů i textu) a jejich import.
class SharingHandler {
  static final FlutterTts _tts = FlutterTts();
  static AppDatabase? _db;
  static GlobalKey<NavigatorState>? _navKey;

  static void init({
    required AppDatabase db,
    required GlobalKey<NavigatorState> navigatorKey,
  }) {
    _db = db;
    _navKey = navigatorKey;
    _tts.setLanguage("cs-CZ");
    _tts.setSpeechRate(0.5);

    // Plugin podporuje pouze Android a iOS; na desktopu by kanály chyběly.
    if (!Platform.isAndroid && !Platform.isIOS) return;

    ReceiveSharingIntent.instance.getMediaStream().listen(_handleMedia);

    ReceiveSharingIntent.instance.getInitialMedia().then((files) async {
      if (files.isNotEmpty) {
        await _handleMedia(files);
      }
      // Zabrání opětovnému zpracování stejného příjmu při příštím startu.
      await ReceiveSharingIntent.instance.reset();
    });
  }

  static Future<void> _handleMedia(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    for (final file in files) {
      if (file.type == SharedMediaType.text) {
        await _importFromString(file.path.trim());
        continue;
      }
      
      if (file.type == SharedMediaType.image ||
          file.type == SharedMediaType.video ||
          file.type == SharedMediaType.url) {
        continue;
      }

      final isJsonMime = file.mimeType != null && file.mimeType!.contains('json');
      if (file.type == SharedMediaType.file &&
          !isJsonMime &&
          !file.path.toLowerCase().endsWith('.json')) {
        continue;
      }

      final raw = await _readContent(file);
      if (raw == null) return;
      await _importFromString(raw);
    }
  }

  static Future<String?> _readContent(SharedMediaFile file) async {
    if (file.type == SharedMediaType.text) {
      return file.path;
    }
    try {
      final diskFile = File(file.path);
      if (await diskFile.exists()) {
        return await diskFile.readAsString();
      }
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _importFromString(String raw) async {
    final db = _db;
    final navKey = _navKey;
    if (db == null || navKey == null) return;
    // Deleguj na sjednocený servis – ten vyřeší Zeptat se / Automaticky + otevření
    final handled = await SongImportService.handleRawJson(raw, db, navKey);
    if (!handled) return;
    // Pro playlist s fix dialogem – pokud byly kandidáti, zobrazit dodatečně
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded.containsKey('name') && decoded.containsKey('songs')) {
        // Získat result znovu pro dialog (pokud byl import úspěšný, result už máme uvnitř handleRawJson, ale pro jednoduchost re-sync bez side-efektu neděláme)
        // Fix dialog se zobrazí už uvnitř handleRawJson? Ne – tam jen announce. Zde doplníme fix dialog pokud potřeba.
        // Pro minimalizaci, zkusíme dekódovat result znovu přes db.syncPlaylistFromJson bez přepisu? Raději přeskočit – uživatel uvidí fix dialog při ručním importu v PlaylistsPage.
      }
    } catch (_) {}
    // Fallback: pokud byl playlist importován a nemá auto-open (uživatel dal Ne), otevřít alespoň seznam setlistů
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded.containsKey('name') && decoded.containsKey('songs')) {
        // Pokud autoOpen == false a uživatel dal Ne, neotvírat přehrávač, ale otevřít seznam
        final prefs = await SharedPreferences.getInstance();
        final auto = prefs.getBool('autoOpenReceived') ?? false;
        if (!auto) {
          // Zjisti jestli už je otevřen přehrávač – pokud ne, otevři seznam
          _openPlaylists(navKey);
        }
      }
    } catch (_) {}
  }

  static String _formatImportTime(int totalSec, int unknown) {
    if (totalSec <= 0 && unknown == 0) return "";
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    final base = totalSec > 0 ? "Celkový čas: $m:${s.toString().padLeft(2, '0')}" : "Čas neurčen";
    if (unknown == 0) return base;
    return AppStrings.setlistTimeWithUnknown(base, unknown);
  }

  static String _formatDurationShort(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  static Future<void> _showFixDialog(GlobalKey<NavigatorState> navKey, PlaylistSyncResult result) async {
    final nav = navKey.currentState;
    if (nav == null) return;
    final context = nav.overlay?.context ?? nav.context;
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
                      DevLog.log("Sharing fix checkbox renameFiles=$v");
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
    if (timeCount > 0) fixedTime = await _db!.applyMissingDurations(result.durationCandidates);
    if (diaCount > 0) {
      final res = await _db!.applyDiacriticRepairs(result.diacriticCandidates, renameFiles: renameFiles);
      fixedDia = res.dbUpdated;
      if (res.filesFailed > 0) DevLog.log("Sharing fix failed rename: ${res.failedPaths.join(', ')}");
    }
    final doneMsg = AppStrings.playlistFixDone(fixedTime, fixedDia);
    _tts.speak(doneMsg);
    final nav2 = navKey.currentState;
    if (nav2 != null) ScaffoldMessenger.of(nav2.context).showSnackBar(SnackBar(content: Text(doneMsg)));
  }

  static void _openPlaylists(GlobalKey<NavigatorState> navKey) {
    final nav = navKey.currentState;
    final overlayContext = nav?.overlay?.context;
    if (overlayContext == null) return;

    final currentRoute = ModalRoute.of(overlayContext);
    if (currentRoute?.settings.name == '/playlists') return;

    nav!.push(MaterialPageRoute(
      settings: const RouteSettings(name: '/playlists'),
      builder: (_) => PlaylistsPage(db: _db!),
    ));
  }
}