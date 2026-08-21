import 'dart:convert';
import 'dart:io';

import 'database.dart';
import 'song_utils.dart';

/// Neshoda mezi metadaty písně v databázi a skutečným obsahem txt souboru.
class LibraryIssue {
  final int songId;
  final String filePath;
  final String currentArtist;
  final String currentTitle;
  final String suggestedArtist;
  final String suggestedTitle;
  final bool fileMissing;

  const LibraryIssue({
    required this.songId,
    required this.filePath,
    required this.currentArtist,
    required this.currentTitle,
    required this.suggestedArtist,
    required this.suggestedTitle,
    this.fileMissing = false,
  });

  bool get metadataDiffers =>
      !fileMissing &&
      (suggestedTitle.trim() != currentTitle.trim() ||
          suggestedArtist.trim() != currentArtist.trim());
}

/// Nástroj pro kontrolu a opravu knihovny: porovná uložené názvy písní
/// s obsahem txt souborů (stejnou logikou, jakou používá import).
class LibraryChecker {
  /// Odvodí očekávaný název a interpreta ze souboru.
  /// Název: první řádek souboru (pokud není prázdný a je do 50 znaků),
  /// jinak ze jména souboru. Interpret: vždy ze jména souboru.
  static Future<({String title, String artist})> deriveMetadata(File file) async {
    final bytes = await file.readAsBytes();
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }
    final lines = content.split('\n');
    final firstLine = lines.isNotEmpty ? lines.first.trim() : '';
    final parsed = Song.parseImportedFileName(file.path);
    final title =
        (firstLine.isNotEmpty && firstLine.length < 50) ? firstLine : parsed.title;
    final artist = parsed.artist ?? Song.unknownArtist;
    return (title: title, artist: artist);
  }

  /// Projde celou knihovnu a vrátí seznam neshod a chybějících souborů.
  static Future<List<LibraryIssue>> findIssues(AppDatabase db) async {
    final songs = await db.getAllSongs();
    final issues = <LibraryIssue>[];
    for (final song in songs) {
      final file = File(song.filePath);
      if (!await file.exists()) {
        issues.add(LibraryIssue(
          songId: song.id,
          filePath: song.filePath,
          currentArtist: song.artist,
          currentTitle: song.title,
          suggestedArtist: song.artist,
          suggestedTitle: song.title,
          fileMissing: true,
        ));
        continue;
      }
      try {
        final derived = await deriveMetadata(file);
        if (derived.title.trim() != song.title.trim() ||
            derived.artist.trim() != song.artist.trim()) {
          issues.add(LibraryIssue(
            songId: song.id,
            filePath: song.filePath,
            currentArtist: song.artist,
            currentTitle: song.title,
            suggestedArtist: derived.artist,
            suggestedTitle: derived.title,
          ));
        }
      } catch (_) {
        issues.add(LibraryIssue(
          songId: song.id,
          filePath: song.filePath,
          currentArtist: song.artist,
          currentTitle: song.title,
          suggestedArtist: song.artist,
          suggestedTitle: song.title,
          fileMissing: true,
        ));
      }
    }
    return issues;
  }

  /// Hromadně opraví metadata podle návrhů. Vrací počet opravených písní.
  static Future<int> repairAll(AppDatabase db, List<LibraryIssue> issues) async {
    var repaired = 0;
    for (final issue in issues) {
      if (!issue.metadataDiffers) continue;
      try {
        final count = await db.updateSong(
          issue.songId,
          issue.suggestedArtist,
          issue.suggestedTitle,
        );
        if (count > 0) repaired++;
      } catch (_) {}
    }
    return repaired;
  }
}
