import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'app_strings.dart';
import 'database.dart';
import 'player_page.dart';

/// Sjednocený import písně/setlistu s volitelným auto-open (Zeptat se / Automaticky).
class SongImportService {
  static final FlutterTts _tts = FlutterTts();

  static Future<void> _ensureTts() async {
    await _tts.setLanguage("cs-CZ");
    await _tts.setSpeechRate(0.5);
  }

  static Future<bool> _shouldAutoOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('autoOpenReceived') ?? false; // default Zeptat se
    } catch (_) {
      return false;
    }
  }

  static Future<void> _announce(GlobalKey<NavigatorState> nav, String msg) async {
    await _ensureTts();
    _tts.speak(msg);
    final n = nav.currentState;
    if (n != null) {
      try {
        ScaffoldMessenger.of(n.context).showSnackBar(SnackBar(content: Text(msg)));
      } catch (_) {}
    }
    HapticFeedback.vibrate();
  }

  static Future<void> _askAndOpen({
    required GlobalKey<NavigatorState> nav,
    required AppDatabase db,
    required String title,
    required String message,
    required int songId,
    List<int>? setlistIds,
    int? playlistId,
  }) async {
    final auto = await _shouldAutoOpen();
    final n = nav.currentState;
    if (n == null) return;
    final ctx = n.overlay?.context ?? n.context;

    if (auto) {
      await _openPlayer(nav, db, songId, setlistIds, playlistId);
      return;
    }

    // Zeptat se – dialog s focus na Ano pro TalkBack
    final open = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: Text(title)),
        content: Semantics(liveRegion: true, child: Text(message)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Ne")),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ano, otevřít"),
          ),
        ],
      ),
    );
    if (open == true) {
      await _openPlayer(nav, db, songId, setlistIds, playlistId);
    }
  }

  static Future<void> _openPlayer(GlobalKey<NavigatorState> nav, AppDatabase db, int songId, List<int>? setlistIds, int? playlistId) async {
    final n = nav.currentState;
    if (n == null) return;
    // small delay to let dialog close
    await Future.delayed(const Duration(milliseconds: 200));
    n.push(MaterialPageRoute(
      builder: (_) => PlayerPage(songId: songId, db: db, setlistIds: setlistIds, playlistId: playlistId),
    ));
  }

  /// Import jedné písně z JSON (v1 i v2). Vrací songId nebo null při chybě.
  static Future<int?> importSongFromJson(Map<String, dynamic> json, AppDatabase db, GlobalKey<NavigatorState> nav) async {
    final title = (json['title'] as String?)?.trim() ?? '';
    final artist = (json['artist'] as String?)?.trim() ?? '';
    final content = (json['content'] as String?)?.trim() ?? '';
    if (title.isEmpty || content.isEmpty) return null;

    double? tempo;
    if (json['tempo'] is num) tempo = (json['tempo'] as num).toDouble();
    else if (json['tempo'] != null) tempo = double.tryParse(json['tempo'].toString());

    double? scrollSpeed;
    if (json['scrollSpeed'] is num) scrollSpeed = (json['scrollSpeed'] as num).toDouble();
    else if (json['scrollSpeed'] != null) scrollSpeed = double.tryParse(json['scrollSpeed'].toString());

    double? fontSize;
    if (json['fontSize'] is num) fontSize = (json['fontSize'] as num).toDouble();
    else if (json['fontSize'] != null) fontSize = double.tryParse(json['fontSize'].toString());

    double? introDuration;
    if (json['introDuration'] is num) introDuration = (json['introDuration'] as num).toDouble();
    else if (json['introDuration'] != null) introDuration = double.tryParse(json['introDuration'].toString());

    int? duration;
    if (json['duration'] is int) duration = json['duration'] as int;
    else if (json['duration'] != null) duration = int.tryParse(json['duration'].toString() ?? '');

    int? transpose;
    if (json['transpose'] is int) transpose = json['transpose'] as int;
    else if (json['transpose'] != null) transpose = int.tryParse(json['transpose'].toString() ?? '');

    List<Map<String, dynamic>>? stopMarks;
    if (json['stopMarks'] is List) {
      stopMarks = [];
      for (final sm in (json['stopMarks'] as List)) {
        if (sm is! Map) continue;
        final m = Map<String, dynamic>.from(sm as Map);
        int? bars = m['bars'] is int ? m['bars'] as int : int.tryParse(m['bars']?.toString() ?? '');
        if (bars == null || bars <= 0) continue;
        bars = bars.clamp(1, 16).toInt();
        final lt = (m['lineText'] ?? m['line_text'] ?? '').toString();
        int? li;
        if (m.containsKey('lineIndex') && m['lineIndex'] != null) {
          li = m['lineIndex'] is int ? m['lineIndex'] as int : int.tryParse(m['lineIndex'].toString());
        }
        stopMarks.add({'lineText': lt, 'lineIndex': li, 'bars': bars});
      }
    }

    final songId = await db.importOrUpdateSongPackage(
      title: title,
      artist: artist.isNotEmpty ? artist : 'Neznámý interpret',
      content: content,
      tempo: tempo,
      scrollSpeed: scrollSpeed,
      fontSize: fontSize,
      introDuration: introDuration,
      duration: duration,
      transpose: transpose,
      stopMarksParam: stopMarks,
    );

    if (songId == null) return null;

    final msg = AppStrings.songImportSuccess(title);
    await _announce(nav, msg);

    // Zeptat se / auto-open
    await _askAndOpen(
      nav: nav,
      db: db,
      title: "Přijata píseň",
      message: "$msg\n${artist.isNotEmpty ? '$artist – ' : ''}$title\nOtevřít v přehrávači?",
      songId: songId,
    );

    return songId;
  }

  /// Import setlistu z JSON (v2/v3/v4). Vrací PlaylistSyncResult a případně otevře první píseň.
  static Future<PlaylistSyncResult?> importPlaylistFromJson(Map<String, dynamic> json, AppDatabase db, GlobalKey<NavigatorState> nav) async {
    final result = await db.syncPlaylistFromJson(json);
    final hasTime = result.totalDurationShared > 0 || result.unknownShared > 0;
    final timeText = hasTime ? _formatImportTime(result.totalDurationShared, result.unknownShared) : null;
    final baseMessage = result.notFound.isEmpty
        ? AppStrings.playlistImportSuccess(result.playlistName, result.matchedCount)
        : '${AppStrings.playlistImportSuccess(result.playlistName, result.matchedCount)} ${AppStrings.playlistImportMissing(result.notFound.length)}';
    final message = timeText != null ? '$baseMessage $timeText' : baseMessage;
    await _announce(nav, message);

    // Najít playlistId a ids pro auto-open
    int? playlistId;
    List<int> ids = [];
    try {
      final pls = await db.getAllPlaylists();
      for (final p in pls) {
        if (p.name == result.playlistName) { playlistId = p.id; break; }
      }
      if (playlistId != null) {
        ids = await db.getPlaylistSongIds(playlistId);
      }
    } catch (_) {}

    if (ids.isNotEmpty && playlistId != null) {
      await _askAndOpen(
        nav: nav,
        db: db,
        title: "Přijat setlist",
        message: "$message\nOtevřít první píseň setlistu?",
        songId: ids.first,
        setlistIds: ids,
        playlistId: playlistId,
      );
    } else if (result.matchedCount == 0 && result.notFound.isNotEmpty) {
      // nic k otevření
    }

    return result;
  }

  static String _formatImportTime(int totalSec, int unknown) {
    if (totalSec <= 0 && unknown == 0) return "";
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    final base = totalSec > 0 ? "Celkový čas: $m:${s.toString().padLeft(2, '0')}" : "Čas neurčen";
    if (unknown == 0) return base;
    return AppStrings.setlistTimeWithUnknown(base, unknown);
  }

  /// Obecný entry pro raw JSON string (song i playlist) – deleguje.
  static Future<bool> handleRawJson(String raw, AppDatabase db, GlobalKey<NavigatorState> nav) async {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (decoded['type'] == 'song') {
        final id = await importSongFromJson(decoded, db, nav);
        return id != null;
      }
      if (decoded.containsKey('name') && decoded.containsKey('songs')) {
        final r = await importPlaylistFromJson(decoded, db, nav);
        return r != null;
      }
      // fallback starý formát: type==playlist nebo name+songs bez type
      throw const FormatException();
    } catch (_) {
      await _ensureTts();
      _tts.speak(AppStrings.songImportError);
      final n = nav.currentState;
      if (n != null) ScaffoldMessenger.of(n.context).showSnackBar(SnackBar(content: Text(AppStrings.songImportError)));
      return false;
    }
  }
}
