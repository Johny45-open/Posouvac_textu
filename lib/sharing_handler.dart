import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'app_strings.dart';
import 'database.dart';
import 'playlists_page.dart';

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

    void announce(String message) {
      _tts.speak(message);
      final nav = navKey.currentState;
      if (nav != null) {
        ScaffoldMessenger.of(nav.context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }

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
        final added = await db.importSongPackage(
          title: title,
          artist: artist.isNotEmpty ? artist : 'Neznámý interpret',
          content: content,
        );
        announce(added
            ? AppStrings.songImportSuccess(title)
            : AppStrings.songImportExists(title));
        return;
      }

      final result = await db.syncPlaylistFromJson(decoded);
      final message = result.notFound.isEmpty
          ? AppStrings.playlistImportSuccess(result.playlistName, result.matchedCount)
          : '${AppStrings.playlistImportSuccess(result.playlistName, result.matchedCount)} '
              '${AppStrings.playlistImportMissing(result.notFound.length)}';
      announce(message);
      _openPlaylists(navKey);
    } catch (_) {
      announce(AppStrings.songImportError);
    }
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