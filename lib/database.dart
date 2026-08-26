import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:io';
import 'song_entry.dart';
import 'package:sqlite3/sqlite3.dart';

part 'database.g.dart';

class DurationFixCandidate {
  final int songId;
  final String title;
  final String artist;
  final int newDuration;
  const DurationFixCandidate({
    required this.songId,
    required this.title,
    required this.artist,
    required this.newDuration,
  });
}

class DiacriticFixCandidate {
  final int songId;
  final String oldTitle;
  final String oldArtist;
  final String newTitle;
  final String newArtist;
  const DiacriticFixCandidate({
    required this.songId,
    required this.oldTitle,
    required this.oldArtist,
    required this.newTitle,
    required this.newArtist,
  });

  // Kompatibilita pro sjednocené API (A): umožní číst i jako current*
  String get currentTitle => oldTitle;
  String get currentArtist => oldArtist;

  DiacriticRepairCandidate toRepair() => DiacriticRepairCandidate(
        songId: songId,
        currentTitle: oldTitle,
        currentArtist: oldArtist,
        newTitle: newTitle,
        newArtist: newArtist,
      );
}

class DiacriticRepairCandidate {
  final int songId;
  final String currentTitle;
  final String currentArtist;
  final String newTitle;
  final String newArtist;
  const DiacriticRepairCandidate({
    required this.songId,
    required this.currentTitle,
    required this.currentArtist,
    required this.newTitle,
    required this.newArtist,
  });

  // Kompatibilita pro kód očekávající DiacriticFixCandidate (B)
  String get oldTitle => currentTitle;
  String get oldArtist => currentArtist;

  DiacriticFixCandidate toFix() => DiacriticFixCandidate(
        songId: songId,
        oldTitle: currentTitle,
        oldArtist: currentArtist,
        newTitle: newTitle,
        newArtist: newArtist,
      );
}

class PlaylistSyncResult {
  final String playlistName;
  final int matchedCount;
  final List<String> notFound;
  final int totalDurationShared;
  final int unknownShared;
  final List<DurationFixCandidate> durationCandidates;
  final List<DiacriticRepairCandidate> diacriticCandidates;

  PlaylistSyncResult({
    required this.playlistName,
    required this.matchedCount,
    required this.notFound,
    this.totalDurationShared = 0,
    this.unknownShared = 0,
    this.durationCandidates = const [],
    this.diacriticCandidates = const [],
  });
}

/// Výsledek hromadného importu metadat z CSV.
class CsvImportResult {
  final int updated;
  final int skipped;

  const CsvImportResult({required this.updated, required this.skipped});
}

/// Výsledek importu slovníku diakritiky.
class DiacriticCsvImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;

  const DiacriticCsvImportResult({required this.imported, required this.skipped, this.errors = const []});
}

/// Výsledek hromadné opravy diakritiky včetně volitelného přejmenování souborů.
class DiacriticRepairResult {
  final int dbUpdated;
  final int filesRenamed;
  final int filesFailed;
  final List<String> failedPaths;

  const DiacriticRepairResult({
    required this.dbUpdated,
    this.filesRenamed = 0,
    this.filesFailed = 0,
    this.failedPaths = const [],
  });
}

/// Záznam písně bez návrhu opravy s důvodem (pro výpis 23→21).
class DiacriticUnrepairedEntry {
  final SongEntry song;
  final String reason; // alreadyCorrect, missingInMap, compositeNoMatch
  final String normTitle;
  final String normArtist;
  const DiacriticUnrepairedEntry({
    required this.song,
    required this.reason,
    required this.normTitle,
    required this.normArtist,
  });
}

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

class PlaylistSongs extends Table {
  IntColumn get playlistId => integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get songId => integer().references(Songs, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  RealColumn get tempo => real().nullable()(); // Tempo specifické pro setlist (BPM), null = globální z Songs.tempo

  @override
  Set<Column> get primaryKey => {playlistId, songId};
}

/// Obálka písně v setlistu včetně per-setlist tempa.
class PlaylistSongWithTempo {
  final SongEntry song;
  final double? playlistTempo;
  final int orderIndex;
  const PlaylistSongWithTempo({
    required this.song,
    this.playlistTempo,
    required this.orderIndex,
  });

  double? get effectiveTempo => playlistTempo ?? song.tempo;
}

class StopMarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get songId => integer().references(Songs, #id, onDelete: KeyAction.cascade)();
  RealColumn get positionRatio => real()(); // Procentuální pozice (0.0 - 1.0)
  IntColumn get durationBars => integer()(); // Délka pauzy v taktech
  IntColumn get lineIndex => integer().nullable()(); // Index kotevního řádku textu
  TextColumn get lineText => text().nullable()(); // Text kotevního řádku (pro stabilitu)
}

class CustomStrings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Songs, Playlists, PlaylistSongs, StopMarks, CustomStrings, DiacriticMappings])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();

  AppDatabase._internal() : super(_openConnection());

  factory AppDatabase() => instance;

  /// Testovací databáze v paměti (bez platformních kanálů).
  factory AppDatabase.forTesting() => AppDatabase._testing();

  AppDatabase._testing() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.deleteTable('playlist_songs');
          await m.createTable(playlistSongs);
        }
        if (from < 3) {
          await m.addColumn(songs, songs.isPlayed);
        }
        if (from < 4) {
          await m.addColumn(songs, songs.introDuration);
        }
        if (from < 5) {
          await m.createTable(stopMarks);
        }
        if (from < 6) {
          await m.addColumn(playlistSongs, playlistSongs.orderIndex);
        }
        if (from < 7) {
          await m.addColumn(songs, songs.duration);
        }
        if (from < 8) {
          await m.createTable(customStrings);
        }
        if (from < 9) {
          await m.addColumn(stopMarks, stopMarks.lineIndex);
          await m.addColumn(stopMarks, stopMarks.lineText);
        }
        if (from < 10) {
          await m.createTable(diacriticMappings);
        }
        if (from < 11) {
          await m.addColumn(playlistSongs, playlistSongs.tempo);
        }
        if (from < 12) {
          // vyčisti otrávené záznamy typu Mladek->Mladdek, ponech jen čistě diakritiku
          final existing = await customSelect('SELECT norm_key, corrected FROM diacritic_mappings', readsFrom: {diacriticMappings}).get();
          for (final row in existing) {
            final normKey = row.read<String>('norm_key');
            final corrected = row.read<String>('corrected');
            if (_normForMatch(corrected) != normKey) {
              await customStatement('DELETE FROM diacritic_mappings WHERE norm_key = ?', [normKey]);
            }
          }
        }
      },
      beforeOpen: (details) async {
        // pojistka i bez migrace (např. už verze 12 ale starý poisoned obsah) – tiché vyčištění při každém startu
        if (details.wasCreated) return;
        try {
          final existing = await customSelect('SELECT norm_key, corrected FROM diacritic_mappings', readsFrom: {diacriticMappings}).get();
          for (final row in existing) {
            final normKey = row.read<String>('norm_key');
            final corrected = row.read<String>('corrected');
            if (_normForMatch(corrected) != normKey) {
              await customStatement('DELETE FROM diacritic_mappings WHERE norm_key = ?', [normKey]);
            }
          }
        } catch (_) {}
      },
    );
  }

  // Metody pro písně
  Future<List<SongEntry>> getAllSongs() => select(songs).get();
  
  Stream<List<SongEntry>> watchAllSongs({bool onlyFavorites = false, bool onlyUnplayed = false, bool sortByArtist = true}) {
    final query = select(songs);
    if (onlyFavorites) query.where((s) => s.isFavorite.equals(true));
    if (onlyUnplayed) query.where((s) => s.isPlayed.equals(false));
    
    if (sortByArtist) {
      query.orderBy([(t) => OrderingTerm(expression: t.artist.lower()), (t) => OrderingTerm(expression: t.title.lower())]);
    } else {
      query.orderBy([(t) => OrderingTerm(expression: t.title.lower()), (t) => OrderingTerm(expression: t.artist.lower())]);
    }
    
    return query.watch();
  }

  Future<int> toggleFavorite(int id, bool isFavorite) =>
      (update(songs)..where((s) => s.id.equals(id))).write(SongsCompanion(isFavorite: Value(isFavorite)));

  Future<int> togglePlayed(int id, bool isPlayed) =>
      (update(songs)..where((s) => s.id.equals(id))).write(SongsCompanion(isPlayed: Value(isPlayed)));

  Future<int> resetAllPlayed() => (update(songs)).write(const SongsCompanion(isPlayed: Value(false)));

  Future<int> updateSong(int id, String newArtist, String newTitle) =>
      (update(songs)..where((s) => s.id.equals(id))).write(SongsCompanion(artist: Value(newArtist), title: Value(newTitle)));

  Future<int> updateSongPath(int id, String newPath) =>
      (update(songs)..where((s) => s.id.equals(id))).write(SongsCompanion(filePath: Value(newPath)));

  Future<int> updateSongDuration(int id, int? seconds) =>
      (update(songs)..where((s) => s.id.equals(id))).write(SongsCompanion(duration: Value(seconds)));

  Future<int> updateSongSettings(int id, double? bpm, double? introDuration, double? fontSize, double scrollMultiplier) =>
      (update(songs)..where((s) => s.id.equals(id))).write(SongsCompanion(
        tempo: Value(bpm),
        introDuration: Value(introDuration),
        customFontSize: Value(fontSize),
        customScrollSpeed: Value(scrollMultiplier),
      ));

  // Metody pro zarážky
  Future<int> addStopMark(int songId, double ratio, int bars) {
    return into(stopMarks).insert(StopMarksCompanion.insert(songId: songId, positionRatio: ratio, durationBars: bars));
  }

  Future<int> addStopMarkAtLine(int songId, int lineIndex, String lineText, int bars) {
    return into(stopMarks).insert(StopMarksCompanion.insert(
      songId: songId,
      positionRatio: 0,
      durationBars: bars,
      lineIndex: Value(lineIndex),
      lineText: Value(lineText),
    ));
  }
  
  Future<List<StopMark>> getStopMarksForSong(int songId) =>
      (select(stopMarks)..where((t) => t.songId.equals(songId))).get();

  Future<int> deleteStopMark(int id) => (delete(stopMarks)..where((t) => t.id.equals(id))).go();

  Future<int> deleteSong(int id) => (delete(songs)..where((t) => t.id.equals(id))).go();

  /// Naimportuje přijatý balíček písně (text + metadata) do knihovny.
  /// Obsah zapíše do nového souboru v aplikačním adresáři a vloží záznam.
  /// Vrací true, pokud byla píseň nově přidána, false pokud už existuje.
  Future<bool> importSongPackage({
    required String title,
    required String artist,
    required String content,
  }) async {
    final existing = await (select(songs)
          ..where((t) => t.title.equals(title) & t.artist.equals(artist)))
        .getSingleOrNull();
    if (existing != null) return false;

    final appDir = await getApplicationDocumentsDirectory();
    final songsDir = Directory(p.join(appDir.path, 'imported_songs'));
    if (!await songsDir.exists()) {
      await songsDir.create(recursive: true);
    }

    final safeArtist = artist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    var fileName = '${safeArtist.isNotEmpty ? '$safeArtist - ' : ''}$safeTitle.txt';
    var filePath = p.join(songsDir.path, fileName);
    var counter = 1;
    while (await File(filePath).exists()) {
      final base = fileName.replaceAll('.txt', '');
      filePath = p.join(songsDir.path, '${base}_$counter.txt');
      counter++;
    }

    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);

    await into(songs).insert(
      SongsCompanion.insert(
        filePath: filePath,
        artist: artist,
        title: title,
      ),
    );
    return true;
  }

  Future<String> exportSongsToCsv() async {
    final songs = await select(this.songs).get();
    final buffer = StringBuffer();
    // Přidání UTF-8 BOM pro správnou interpretaci v Excelu
    buffer.write('\uFEFF');
    buffer.writeln("id,artist,title,duration,filePath");
    for (final song in songs) {
      // Bezpečné escapování uvozovek pro CSV
      String escape(String? s) => (s ?? '').replaceAll('"', '""');
      buffer.writeln(
          "${song.id},\"${escape(song.artist)}\",\"${escape(song.title)}\",${song.duration ?? 0},\"${escape(song.filePath)}\"");
    }
    return buffer.toString();
  }

  /// Rozparsuje jeden řádek CSV – respektuje čárky uvnitř uvozovek.
  static List<String> _parseCsvLine(String line) {
    final pattern = RegExp(r',(?=(?:(?:[^"]*"){2})*[^"]*$)');
    return line
        .split(pattern)
        .map((p) => p.trim().replaceAll(RegExp(r'^"|"$'), '').replaceAll('""', '"').trim())
        .toList();
  }

  /// Rozparsuje jeden řádek CSV slovníku – respektuje čárky i středníky (český Excel)
  /// uvnitř uvozovek. Zkouší čárku, pak středník.
  static List<String> _parseDiacriticCsvLine(String line) {
    var parts = _parseCsvLine(line);
    if (parts.length >= 2) return parts;
    if (line.contains(';')) {
      final semiPattern = RegExp(r';(?=(?:(?:[^"]*"){2})*[^"]*$)');
      parts = line
          .split(semiPattern)
          .map((p) => p.trim().replaceAll(RegExp(r'^"|"$'), '').replaceAll('""', '"').trim())
          .toList();
    }
    return parts;
  }

  /// Normalizuje cestu pro porovnání (oddělovače a velikost písmen).
  static String _normalizePath(String path) =>
      path.replaceAll('\\', '/').trim().toLowerCase();

  /// Odstraní diakritiku pro porovnání názvů souborů bez háčků/čárek.
  static String _stripDiacritics(String input) {
    const map = {
      'á': 'a', 'č': 'c', 'ď': 'd', 'é': 'e', 'ě': 'e', 'í': 'i', 'ň': 'n',
      'ó': 'o', 'ř': 'r', 'š': 's', 'ť': 't', 'ú': 'u', 'ů': 'u', 'ý': 'y', 'ž': 'z',
      'Á': 'A', 'Č': 'C', 'Ď': 'D', 'É': 'E', 'Ě': 'E', 'Í': 'I', 'Ň': 'N',
      'Ó': 'O', 'Ř': 'R', 'Š': 'S', 'Ť': 'T', 'Ú': 'U', 'Ů': 'U', 'Ý': 'Y', 'Ž': 'Z',
      'ä': 'a', 'ë': 'e', 'ï': 'i', 'ö': 'o', 'ü': 'u',
      'Ä': 'A', 'Ë': 'E', 'Ï': 'I', 'Ö': 'O', 'Ü': 'U',
      'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
      'À': 'A', 'È': 'E', 'Ì': 'I', 'Ò': 'O', 'Ù': 'U',
      'â': 'a', 'ê': 'e', 'î': 'i', 'ô': 'o', 'û': 'u',
      'Â': 'A', 'Ê': 'E', 'Î': 'I', 'Ô': 'O', 'Û': 'U',
    };
    var out = input;
    map.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  static String _normForMatch(String input) =>
      _stripDiacritics(input.trim().toLowerCase()).replaceAll(RegExp(r'\s+'), ' ');

  /// Povolena je pouze změna diakritiky – po strip musí být řetězce shodné.
  /// Odmítá překlepy typu "Mladek" -> "Mladdek" (vložení písmene).
  static bool _isDiacriticOnly(String raw, String corrected) {
    return _normForMatch(raw) == _normForMatch(corrected);
  }

  /// Výsledek hromadného importu metadat z CSV.
  /// [skipped] obsahuje řádky, které se nepodařilo bezpečně spárovat
  /// (id existuje, ale filePath nesedí) – ty se záměrně nepřepisují,
  /// aby se metadata nezapsala špatné písni.
  Future<CsvImportResult> importSongsFromCsv(String csvContent) async {
    final content = csvContent.startsWith('\uFEFF') ? csvContent.substring(1) : csvContent;
    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.length < 2) return const CsvImportResult(updated: 0, skipped: 0);

    int updatedCount = 0;
    int skippedCount = 0;
    await transaction(() async {
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = _parseCsvLine(line);
        if (parts.length < 3) continue;

        final idStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '').trim();
        final id = int.tryParse(idStr);
        if (id == null) continue;

        final song = await (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (song == null) continue;

        // Ověření identity řádku: pokud CSV obsahuje filePath a nesedí
        // s uloženou cestou, jde nejspíš o zastaralé CSV z jiného stavu
        // knihovny – takový řádek přeskočíme.
        if (parts.length > 4 && parts[4].isNotEmpty) {
          if (_normalizePath(parts[4]) != _normalizePath(song.filePath)) {
            skippedCount++;
            continue;
          }
        }

        final artist = parts[1].trim();
        final title = parts[2].trim();
        final duration = parts.length > 3 ? int.tryParse(parts[3].trim()) ?? 0 : 0;

        final result = await (update(songs)..where((t) => t.id.equals(id))).write(
          SongsCompanion(
            artist: Value(artist),
            title: Value(title),
            duration: Value(duration > 0 ? duration : null),
          ),
        );
        if (result > 0) updatedCount++;
      }
    });
    return CsvImportResult(updated: updatedCount, skipped: skippedCount);
  }

  Future<List<Map<String, dynamic>>> previewSongsFromCsv(String csvContent) async {
    final content = csvContent.startsWith('\uFEFF') ? csvContent.substring(1) : csvContent;
    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.length < 2) return [];

    final preview = <Map<String, dynamic>>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = _parseCsvLine(line);

      if (parts.isEmpty || parts[0].isEmpty) continue;

      final idStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '').trim();
      final id = int.tryParse(idStr);

      if (id != null) {
        final song = await (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (song != null) {
          final pathMismatch =
              parts.length > 4 && parts[4].isNotEmpty && _normalizePath(parts[4]) != _normalizePath(song.filePath);
          preview.add({
            'id': id,
            'oldArtist': song.artist,
            'newArtist': parts.length > 1 ? parts[1].trim() : song.artist,
            'oldTitle': song.title,
            'newTitle': parts.length > 2 ? parts[2].trim() : song.title,
            'newDuration': parts.length > 3 ? int.tryParse(parts[3].trim()) ?? 0 : song.duration ?? 0,
            'pathMismatch': pathMismatch,
          });
        }
      }
    }
    return preview;
  }

  /// Export setlistu včetně časů a temp pro sdílení (v2 – tempo volitelné, zpětně kompatibilní). Vrací mapu připravenou pro jsonEncode.
  Future<Map<String, dynamic>> exportPlaylistToJson(int playlistId, {bool includeContents = false}) async {
    final playlist = await (select(playlists)..where((t) => t.id.equals(playlistId))).getSingle();
    final items = await getPlaylistSongsWithTempo(playlistId);
    int totalDuration = 0;
    int unknownCount = 0;
    for (final w in items) {
      final s = w.song;
      if (s.duration != null && s.duration! > 0) {
        totalDuration += s.duration!;
      } else {
        unknownCount++;
      }
    }
    final songsJson = <Map<String, dynamic>>[];
    for (final w in items) {
      final s = w.song;
      final entry = <String, dynamic>{
        'title': s.title,
        'artist': s.artist,
        'duration': s.duration,
        if (w.playlistTempo != null) 'tempo': w.playlistTempo,
        if (w.playlistTempo == null && s.tempo != null) 'tempo': s.tempo,
      };
      // Pokud obě tempa null, tempo neuvádíme (zůstane null na importu)
      if (entry['tempo'] == null) entry.remove('tempo');
      if (includeContents) {
        try {
          final file = File(s.filePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            String content;
            try {
              content = utf8.decode(bytes);
            } catch (_) {
              content = latin1.decode(bytes);
            }
            entry['content'] = content;
          }
        } catch (_) {}
      }
      songsJson.add(entry);
    }
    return {
      'type': 'playlist',
      'version': 2,
      'name': playlist.name,
      'exportedAt': DateTime.now().toIso8601String(),
      'totalDuration': totalDuration,
      'unknownCount': unknownCount,
      'songs': songsJson,
    };
  }

  Future<PlaylistSyncResult> syncPlaylistFromJson(Map<String, dynamic> data) async {
    final playlistName = (data['name'] as String?)?.trim() ?? '';
    if (playlistName.isEmpty) {
      throw const FormatException('Chybějící název playlistu.');
    }
    final rawSongs = data['songs'] as List<dynamic>? ?? const [];
    // V2: List<Map> s title/artist/duration, zpětně kompatibilní List<String>
    final List<Map<String, dynamic>> parsedSongs = [];
    final List<String> notFoundLabels = [];
    int totalDurationShared = 0;
    int unknownShared = 0;
    // Spočítat sdílený čas pro hlášku (pokud je v exportu)
    if (data.containsKey('totalDuration') && data['totalDuration'] is int) {
      totalDurationShared = data['totalDuration'] as int;
    }
    if (data.containsKey('unknownCount') && data['unknownCount'] is int) {
      unknownShared = data['unknownCount'] as int;
    }
    for (final raw in rawSongs) {
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        final title = (m['title'] ?? m['name'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        final artist = (m['artist'] ?? '').toString().trim();
        final duration = m['duration'] is int ? m['duration'] as int : int.tryParse(m['duration']?.toString() ?? '');
        double? tempo;
        if (m.containsKey('tempo') && m['tempo'] != null) {
          if (m['tempo'] is num) tempo = (m['tempo'] as num).toDouble();
          else tempo = double.tryParse(m['tempo'].toString());
          if (tempo != null && (tempo < 30 || tempo > 300)) tempo = null;
        }
        parsedSongs.add({'title': title, 'artist': artist, 'duration': duration, 'tempo': tempo, 'content': m['content']});
        if (duration != null && duration > 0) {
          if (totalDurationShared == 0) totalDurationShared += duration;
        } else {
          if (unknownShared == 0 && data['totalDuration'] == null) unknownShared++;
        }
      } else {
        final rawTitle = raw.toString().trim();
        if (rawTitle.isEmpty) continue;
        // Fallback pro staré Generator soubory: "Interpret - Název" jako jeden string
        var artist = '';
        var title = rawTitle;
        final sep = RegExp(r'\s+[-–—]\s+').firstMatch(rawTitle);
        if (sep != null) {
          final a = rawTitle.substring(0, sep.start).trim();
          final t = rawTitle.substring(sep.end).trim();
          if (a.isNotEmpty && t.isNotEmpty) {
            artist = a;
            title = t;
          }
        } else {
          final all = RegExp(r'\s*[-–—]\s*').allMatches(rawTitle).toList();
          if (all.isNotEmpty) {
            final last = all.last;
            final a = rawTitle.substring(0, last.start).trim();
            final t = rawTitle.substring(last.end).trim();
            if (a.isNotEmpty && t.isNotEmpty) {
              artist = a;
              title = t;
            }
          }
        }
        parsedSongs.add({'title': title, 'artist': artist, 'duration': null, 'tempo': null});
        unknownShared++;
      }
    }
    // Pokud totalDuration nebyl v exportu, spočítat z parsed
    if (!data.containsKey('totalDuration')) {
      totalDurationShared = parsedSongs.fold<int>(0, (sum, e) => sum + ((e['duration'] as int?) ?? 0));
      unknownShared = parsedSongs.where((e) => (e['duration'] as int?) == null || (e['duration'] as int) == 0).length;
    }

    // Slovníky pro match: norm(artist|title) primárně, norm(title) fallback, vše s diakritikou-insensitive
    final allSongs = await select(songs).get();
    final byNormFull = <String, SongEntry>{};
    final byNormTitle = <String, SongEntry>{};
    for (final song in allSongs) {
      final fullKey = _normForMatch('${song.artist}|${song.title}');
      final titleKey = _normForMatch(song.title);
      if (fullKey.isNotEmpty && !byNormFull.containsKey(fullKey)) byNormFull[fullKey] = song;
      if (titleKey.isNotEmpty && !byNormTitle.containsKey(titleKey)) byNormTitle[titleKey] = song;
    }

    final notFound = <String>[];
    final matchedIds = <int>[];
    final matchedEntries = <SongEntry>[];
    // Kandidáti na doplnění budou spočítáni až po transakci, kdy máme matchedEntries
    final Map<int, int> sharedDurationBySongId = {};
    final Map<int, Map<String, String>> sharedDiacriticBySongId = {};

    var matchedCount = 0;

    await transaction(() async {
      Playlist? playlist = await (select(playlists)..where((t) => t.name.equals(playlistName))).getSingleOrNull();
      int playlistId;
      if (playlist == null) {
        playlistId = await into(playlists).insert(PlaylistsCompanion.insert(name: playlistName));
      } else {
        playlistId = playlist.id;
        await (delete(playlistSongs)..where((t) => t.playlistId.equals(playlistId))).go();
      }
      int order = 0;
      for (final entry in parsedSongs) {
        final title = entry['title'] as String;
        final artist = entry['artist'] as String? ?? '';
        final duration = entry['duration'] as int?;
        final tempo = entry['tempo'] as double?;
        final fullKey = artist.isNotEmpty ? _normForMatch('$artist|$title') : '';
        final titleKey = _normForMatch(title);
        SongEntry? song = fullKey.isNotEmpty ? byNormFull[fullKey] : null;
        song ??= byNormTitle[titleKey];
        final label = artist.isNotEmpty ? '$artist - $title' : title;
        if (song != null) {
          matchedCount++;
          matchedIds.add(song.id);
          matchedEntries.add(song);
          if (duration != null && duration > 0) {
            sharedDurationBySongId[song.id] = duration;
          }
          // Kandidát na diakritiku: norm shodný ale přesný string se liší
          final normLocalTitle = _normForMatch(song.title);
          final normSharedTitle = _normForMatch(title);
          final normLocalArtist = _normForMatch(song.artist);
          final normSharedArtist = _normForMatch(artist);
          final needsDiacritic = (normLocalTitle == normSharedTitle && song.title != title) ||
              (artist.isNotEmpty && normLocalArtist == normSharedArtist && song.artist != artist);
          if (needsDiacritic && title.isNotEmpty) {
            sharedDiacriticBySongId[song.id] = {'newTitle': title, 'newArtist': artist.isNotEmpty ? artist : song.artist};
          }
          await into(playlistSongs).insert(
            PlaylistSongsCompanion.insert(
              playlistId: playlistId,
              songId: song.id,
              orderIndex: Value(order++),
              tempo: Value(tempo),
            ),
            mode: InsertMode.insertOrIgnore,
          );
          // Pokud byl v exportu i content a píseň lokálně neexistovala by, řeší se jinde;
          // zde content ignorujeme, protože match už proběhl – text se nesdílí pro existující píseň
        } else {
          notFound.add(label);
          notFoundLabels.add(label);
        }
      }
      // Pokud export obsahoval nové písně s content a nenašly se, vytvořit je (volitelně)
      for (final entry in parsedSongs) {
        final label = (entry['artist'] as String).isNotEmpty ? "${entry['artist']} - ${entry['title']}" : entry['title'] as String;
        if (notFound.contains(label) && entry['content'] != null && (entry['content'] as String).trim().isNotEmpty) {
          final title = entry['title'] as String;
          final artist = (entry['artist'] as String).isNotEmpty ? entry['artist'] as String : 'Neznámý interpret';
          final content = entry['content'] as String;
          final duration = entry['duration'] as int?;
          final tempo = entry['tempo'] as double?;
          // Zkusit vytvořit píseň přes importSongPackage logiku (bez duplikace)
          final created = await _importSongWithContent(title: title, artist: artist, content: content, duration: duration, tempo: tempo);
          if (created != null) {
            // Najít playlistId znovu
            final pl = await (select(playlists)..where((t) => t.name.equals(playlistName))).getSingle();
            await into(playlistSongs).insert(
              PlaylistSongsCompanion.insert(playlistId: pl.id, songId: created.id, orderIndex: Value(matchedCount++), tempo: Value(tempo)),
              mode: InsertMode.insertOrIgnore,
            );
            notFound.remove(label);
            matchedIds.add(created.id);
            matchedEntries.add(created);
          }
        }
      }
    });

    // Sestavit kandidáty na doplnění
    final durationCandidates = <DurationFixCandidate>[];
    final diacriticCandidates = <DiacriticRepairCandidate>[];
    for (final song in matchedEntries) {
      final sharedDur = sharedDurationBySongId[song.id];
      if (sharedDur != null && (song.duration == null || song.duration == 0)) {
        durationCandidates.add(DurationFixCandidate(
          songId: song.id,
          title: song.title,
          artist: song.artist,
          newDuration: sharedDur,
        ));
      }
      final dia = sharedDiacriticBySongId[song.id];
      if (dia != null) {
        diacriticCandidates.add(DiacriticRepairCandidate(
          songId: song.id,
          currentTitle: song.title,
          currentArtist: song.artist,
          newTitle: dia['newTitle']!,
          newArtist: dia['newArtist']!,
        ));
      }
    }

    return PlaylistSyncResult(
      playlistName: playlistName,
      matchedCount: matchedCount,
      notFound: notFound,
      totalDurationShared: totalDurationShared,
      unknownShared: unknownShared,
      durationCandidates: durationCandidates,
      diacriticCandidates: diacriticCandidates,
    );
  }

  Future<SongEntry?> _importSongWithContent({required String title, required String artist, required String content, int? duration, double? tempo}) async {
    final existing = await (select(songs)..where((t) => t.title.equals(title) & t.artist.equals(artist))).getSingleOrNull();
    if (existing != null) return null;
    final appDir = await getApplicationDocumentsDirectory();
    final songsDir = Directory(p.join(appDir.path, 'imported_songs'));
    if (!await songsDir.exists()) await songsDir.create(recursive: true);
    final safeArtist = artist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    var fileName = '${safeArtist.isNotEmpty ? '$safeArtist - ' : ''}$safeTitle.txt';
    var filePath = p.join(songsDir.path, fileName);
    var counter = 1;
    while (await File(filePath).exists()) {
      final base = fileName.replaceAll('.txt', '');
      filePath = p.join(songsDir.path, '${base}_$counter.txt');
      counter++;
    }
    await File(filePath).writeAsString(content, encoding: utf8);
    final id = await into(songs).insert(SongsCompanion.insert(
      filePath: filePath,
      artist: artist,
      title: title,
      duration: Value(duration != null && duration > 0 ? duration : null),
      tempo: Value(tempo),
    ));
    return (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> applyMissingDurations(List<DurationFixCandidate> candidates) async {
    var count = 0;
    await transaction(() async {
      for (final c in candidates) {
        final res = await (update(songs)..where((t) => t.id.equals(c.songId))).write(SongsCompanion(duration: Value(c.newDuration)));
        if (res > 0) count++;
      }
    });
    return count;
  }

  // --- SLOVNÍK DIAKRITIKY ---
  /// Oddělovače pro kompozitního interpreta: ", ", " a ", " & ", ";", "/", " feat. ", " ft. ", " featuring "
  static final RegExp _artistDelimiter = RegExp(
    r'(\s*,\s*|\s+a\s+|\s+&\s+|\s*;\s*|\s*/\s*|\s+feat\.?\s+|\s+ft\.?\s+|\s+featuring\s+)',
    caseSensitive: false,
  );

  /// Pattern pro "Artist (feat. Host)" – závorková verze
  static final RegExp _featParenPattern = RegExp(
    r'^(.*)\s*\(\s*(feat\.?|ft\.?|featuring)\s+(.+?)\s*\)\s*$',
    caseSensitive: false,
  );

  /// Pattern pro "Artist feat. Host" – bez závorek
  static final RegExp _featBarePattern = RegExp(
    r'^(.*)\s+(feat\.?|ft\.?|featuring)\s+(.+)$',
    caseSensitive: false,
  );

  static String? _lookupSingle(String part, Map<String, String> map) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) return null;
    final key = _normForMatch(trimmed);
    final corrected = map[key];
    if (corrected != null && corrected != trimmed) {
      // obrana proti otrávenému záznamu: např. "Ivan Mladek" -> "Ivan Mladdek"
      if (_normForMatch(corrected) != key) return null;
      return corrected;
    }
    return null;
  }

  /// Aplikuje slovník na kompozitní řetězec (např. "Hana Hegerova, Karel Gott a Waldemar Matuska").
  /// Zachovává původní oddělovače, opravuje jen sub-části nalezené v [map].
  /// Podporuje i "feat." varianty: "Ivan Mladek (feat. Ludek Sobota)" -> "Ivan Mládek (feat. Luděk Sobota)"
  static String? _resolveComposite(String raw, Map<String, String> map) {
    if (raw.trim().isEmpty) return null;
    // rychlá cesta – celý řetězec přímo v mapě (s validací diakritiky)
    final direct = map[_normForMatch(raw)];
    if (direct != null && direct != raw) {
      if (_normForMatch(direct) == _normForMatch(raw)) return direct;
      // otrávený záznam – nebrat v úvahu, pokračovat kompozitní logikou
    }

    // 1) Závorková feat verze: "Hlavní (feat. Host)" – oprav obě části i když host je kompozitní
    final parenMatch = _featParenPattern.firstMatch(raw);
    if (parenMatch != null) {
      final mainPart = parenMatch.group(1)!.trim();
      final featTag = parenMatch.group(2)!.trim(); // "feat." / "ft." / "featuring"
      final featPart = parenMatch.group(3)!.trim();
      if (mainPart.isNotEmpty && featPart.isNotEmpty) {
        // hlavní interpret může být sám kompozitní (",", " a ", atd.)
        String? fixedMain = _lookupSingle(mainPart, map) ?? _resolveCompositeInner(mainPart, map);
        String? fixedFeat = _lookupSingle(featPart, map) ?? _resolveCompositeInner(featPart, map);
        // pokud ani jedno neopravitelné, zkus rekurzi na celé části
        fixedMain ??= (mainPart != raw ? null : null); // placeholder, fixedMain již je null pokud neopraveno
        // efektivně: pokud nenalezeno, ponech původní
        final newMain = fixedMain ?? mainPart;
        final newFeat = fixedFeat ?? featPart;
        if (newMain != mainPart || newFeat != featPart) {
          // normalizuj tag na "feat." pro konzistenci, ale zachovej původní variantu pokud je "featuring"
          final normalizedTag = featTag.toLowerCase().startsWith('featuring') ? 'featuring' : featTag.toLowerCase().contains('ft') && !featTag.toLowerCase().contains('fea') ? 'ft.' : 'feat.';
          // zachovej původní tečku? použij normalizedTag
          return '$newMain ($normalizedTag $newFeat)';
        }
      }
    }

    // 2) Bare feat verze bez závorek: "Hlavní feat. Host" – zachytí i delimiter fallback
    final bareMatch = _featBarePattern.firstMatch(raw);
    if (bareMatch != null) {
      final mainPart = bareMatch.group(1)!.trim();
      final featTag = bareMatch.group(2)!.trim();
      final featPart = bareMatch.group(3)!.trim();
      if (mainPart.isNotEmpty && featPart.isNotEmpty) {
        String? fixedMain = _lookupSingle(mainPart, map) ?? _resolveCompositeInner(mainPart, map);
        String? fixedFeat = _lookupSingle(featPart, map) ?? _resolveCompositeInner(featPart, map);
        final newMain = fixedMain ?? mainPart;
        final newFeat = fixedFeat ?? featPart;
        if (newMain != mainPart || newFeat != featPart) {
          final normalizedTag = featTag.toLowerCase().startsWith('featuring') ? 'featuring' : featTag.toLowerCase().contains('ft') && !featTag.toLowerCase().contains('fea') ? 'ft.' : 'feat.';
          return '$newMain $normalizedTag $newFeat';
        }
      }
    }

    if (!_artistDelimiter.hasMatch(raw)) return direct;
    final resolved = raw.splitMapJoin(
      _artistDelimiter,
      onMatch: (m) => m.group(0)!,
      onNonMatch: (part) {
        if (part.trim().isEmpty) return part;
        // zkus přímý lookup, jinak rekurzi pro feat uvnitř části (např. "A (feat. B)")
        final subFeat = _resolveComposite(part.trim(), map);
        if (subFeat != null) return subFeat;
        final corrected = map[_normForMatch(part)];
        if (corrected != null && corrected != part) {
          if (_normForMatch(corrected) != _normForMatch(part)) return part;
          return corrected;
        }
        return part;
      },
    );
    return resolved != raw ? resolved : null;
  }

  /// Vnitřní helper pro kompozit bez feat-paren rekurze (zabrání cyklu).
  static String? _resolveCompositeInner(String raw, Map<String, String> map) {
    if (raw.trim().isEmpty) return null;
    if (!_artistDelimiter.hasMatch(raw)) return null;
    final resolved = raw.splitMapJoin(
      _artistDelimiter,
      onMatch: (m) => m.group(0)!,
      onNonMatch: (part) {
        if (part.trim().isEmpty) return part;
        final corrected = map[_normForMatch(part)];
        if (corrected != null && corrected != part) {
          if (_normForMatch(corrected) != _normForMatch(part)) return part;
          return corrected;
        }
        return part;
      },
    );
    return resolved != raw ? resolved : null;
  }

  /// Vyhledá opravený zápis ve slovníku (podle textu bez diakritiky).
  /// Podporuje kompozitní interprety – opraví po částech, včetně "feat.".
  Future<String?> lookupDiacritic(String rawText) async {
    final key = _normForMatch(rawText);
    if (key.isEmpty) return null;
    final row = await (select(diacriticMappings)..where((t) => t.normKey.equals(key))).getSingleOrNull();
    if (row != null) {
      if (_normForMatch(row.corrected) != key) return null;
      return row.corrected;
    }
    // kompozit: "Hana Hegerova, Karel Gott a Waldemar Matuska" nebo "Ivan Mladek (feat. Ludek Sobota)"
    final isComposite = _artistDelimiter.hasMatch(rawText) ||
        _featParenPattern.hasMatch(rawText) ||
        _featBarePattern.hasMatch(rawText);
    if (!isComposite) return null;
    final mappings = await select(diacriticMappings).get();
    final map = {for (final m in mappings) m.normKey: m.corrected};
    if (map.isEmpty) return null;
    return _resolveComposite(rawText, map);
  }

  /// Naučí slovník dvojici [raw] -> [corrected] (např. z ruční opravy písně).
  /// Pro kompozitní interprety ("A, B a C") učí po částech, včetně "feat.".
  /// Odmítá páry, kde se liší i písmena (překlep), nejen diakritika – např. Mladek -> Mladdek.
  Future<void> learnDiacritic(String raw, String corrected) async {
    if (!_isDiacriticOnly(raw, corrected) && !_artistDelimiter.hasMatch(raw) && !_featParenPattern.hasMatch(raw) && !_featBarePattern.hasMatch(raw)) {
      // rychlá validace pro jednoduchý případ – pokud mění i písmena, odmítnout
      // kompozitní případy se validují po rozdělení níže
      final simpleKey = _normForMatch(raw);
      final simpleValNorm = _normForMatch(corrected);
      if (simpleKey.isNotEmpty && simpleValNorm.isNotEmpty && simpleKey != simpleValNorm) {
        // může to být kompozit s různými oddělovači – nech projít k další logice, která rozseká
        if (!_artistDelimiter.hasMatch(corrected) && !_featParenPattern.hasMatch(corrected) && !_featBarePattern.hasMatch(corrected)) {
          return;
        }
      }
    }
    // Speciálně pro feat závorkovou verzi: uč hlavní a hosta zvlášť
    final rawFeatParen = _featParenPattern.firstMatch(raw);
    final corrFeatParen = _featParenPattern.firstMatch(corrected);
    if (rawFeatParen != null && corrFeatParen != null) {
      final rMain = rawFeatParen.group(1)!.trim();
      final cMain = corrFeatParen.group(1)!.trim();
      final rFeat = rawFeatParen.group(3)!.trim();
      final cFeat = corrFeatParen.group(3)!.trim();
      if (rMain.isNotEmpty && cMain.isNotEmpty && rMain != cMain) {
        await learnDiacritic(rMain, cMain);
      } else if (rMain.isNotEmpty && cMain.isNotEmpty && _artistDelimiter.hasMatch(rMain)) {
        await learnDiacritic(rMain, cMain);
      }
      if (rFeat.isNotEmpty && cFeat.isNotEmpty && rFeat != cFeat) {
        await learnDiacritic(rFeat, cFeat);
      } else if (rFeat.isNotEmpty && cFeat.isNotEmpty && _artistDelimiter.hasMatch(rFeat)) {
        await learnDiacritic(rFeat, cFeat);
      }
      // pokud obě části naučeny, není třeba učit celek
      if (rMain != cMain || rFeat != cFeat) return;
    }
    final rawFeatBare = _featBarePattern.firstMatch(raw);
    final corrFeatBare = _featBarePattern.firstMatch(corrected);
    if (rawFeatBare != null && corrFeatBare != null) {
      final rMain = rawFeatBare.group(1)!.trim();
      final cMain = corrFeatBare.group(1)!.trim();
      final rFeat = rawFeatBare.group(3)!.trim();
      final cFeat = corrFeatBare.group(3)!.trim();
      if (rMain.isNotEmpty && cMain.isNotEmpty && rMain != cMain) {
        await learnDiacritic(rMain, cMain);
      }
      if (rFeat.isNotEmpty && cFeat.isNotEmpty && rFeat != cFeat) {
        await learnDiacritic(rFeat, cFeat);
      }
      if (rMain != cMain || rFeat != cFeat) return;
    }

    // Pokud oba obsahují stejný počet delimiterů, uč po částech
    if (_artistDelimiter.hasMatch(raw) || _artistDelimiter.hasMatch(corrected)) {
      final rawParts = raw.split(_artistDelimiter);
      final corrParts = corrected.split(_artistDelimiter);
      if (rawParts.length == corrParts.length && rawParts.length > 1) {
        for (var i = 0; i < rawParts.length; i++) {
          final r = rawParts[i].trim();
          final c = corrParts[i].trim();
          if (r.isEmpty || c.isEmpty) continue;
          if (!_isDiacriticOnly(r, c)) continue;
          final k = _normForMatch(r);
          if (k.isEmpty || k == c.toLowerCase().trim()) continue;
          // přeskočit "Karel Gott" -> "Karel Gott" beze změny
          if (r == c) continue;
          await into(diacriticMappings).insert(
            DiacriticMappingsCompanion.insert(normKey: k, corrected: c),
            mode: InsertMode.insertOrReplace,
          );
        }
        return;
      }
    }
    final key = _normForMatch(raw);
    final value = corrected.trim();
    if (key.isEmpty || value.isEmpty || key == value.toLowerCase().trim()) return;
    if (!_isDiacriticOnly(raw, value)) return;
    if (raw.trim() == value) return;
    await into(diacriticMappings).insert(
      DiacriticMappingsCompanion.insert(normKey: key, corrected: value),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<int> getDiacriticCount() async {
    final countExp = diacriticMappings.normKey.count();
    final query = selectOnly(diacriticMappings)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Smaže otrávené záznamy, kde se liší i písmena (ne jen diakritika).
  /// Vrací počet smazaných.
  Future<int> purgeInvalidDiacriticMappings() async {
    final all = await select(diacriticMappings).get();
    var deleted = 0;
    for (final m in all) {
      if (_normForMatch(m.corrected) != m.normKey) {
        await (delete(diacriticMappings)..where((t) => t.normKey.equals(m.normKey))).go();
        deleted++;
      }
    }
    return deleted;
  }

  /// Najde písně, jejichž název/interpret má ve slovníku opravenou verzi.
  /// Podporuje kompozitní interprety (",", " a ", " & ", ";", "/") pouze pro interpreta.
  Future<List<DiacriticRepairCandidate>> findDiacriticRepairs() async {
    final all = await select(songs).get();
    final mappings = await select(diacriticMappings).get();
    // filtruj otrávené záznamy, aby se nikdy nenavrhla oprava typu Mladek->Mladdek
    final map = <String, String>{};
    for (final m in mappings) {
      if (_normForMatch(m.corrected) != m.normKey) continue;
      map[m.normKey] = m.corrected;
    }
    if (map.isEmpty) return const [];
    final result = <DiacriticRepairCandidate>[];
    for (final s in all) {
      final directTitleRaw = map[_normForMatch(s.title)];
      final compositeArtist = _resolveComposite(s.artist, map);
      final directArtistRaw = map[_normForMatch(s.artist)];
      // tituly se opravují pouze přímou shodou; kompozitní logika jen pro interpreta
      // validace: navržená oprava musí být diakriticky shodná
      final resolvedTitle = (directTitleRaw != null && _normForMatch(directTitleRaw) == _normForMatch(s.title)) ? directTitleRaw : null;
      String? resolvedArtist;
      if (compositeArtist != null && _normForMatch(compositeArtist) == _normForMatch(s.artist)) {
        resolvedArtist = compositeArtist;
      } else if (directArtistRaw != null && _normForMatch(directArtistRaw) == _normForMatch(s.artist)) {
        resolvedArtist = directArtistRaw;
      }
      final changedTitle = resolvedTitle != null && resolvedTitle != s.title;
      final changedArtist = resolvedArtist != null && resolvedArtist != s.artist;
      if (!changedTitle && !changedArtist) continue;
      result.add(DiacriticRepairCandidate(
        songId: s.id,
        currentTitle: s.title,
        currentArtist: s.artist,
        newTitle: changedTitle ? resolvedTitle! : s.title,
        newArtist: changedArtist ? resolvedArtist! : s.artist,
      ));
    }
    return result;
  }

  /// Vrátí písně bez návrhu opravy s důvodem (pro výpis 23→21).
  Future<List<DiacriticUnrepairedEntry>> getDiacriticUnrepairedWithReason() async {
    final all = await select(songs).get();
    final mappings = await select(diacriticMappings).get();
    final map = {for (final m in mappings) m.normKey: m.corrected};
    final repairedIds = (await findDiacriticRepairs()).map((e) => e.songId).toSet();
    final result = <DiacriticUnrepairedEntry>[];
    for (final s in all) {
      if (repairedIds.contains(s.id)) continue;
      final normTitle = _normForMatch(s.title);
      final normArtist = _normForMatch(s.artist);
      final hasTitleDiacritic = _stripDiacritics(s.title) != s.title;
      final hasArtistDiacritic = _stripDiacritics(s.artist) != s.artist;
      final titleInMap = map.containsKey(normTitle);
      final artistInMap = map.containsKey(normArtist) || _resolveComposite(s.artist, map) != null;
      String reason;
      if ((hasTitleDiacritic || hasArtistDiacritic) && !titleInMap && !artistInMap) {
        // má háčky, ale není v mapě – považujeme za už správně (nebo chybí jiný tvar)
        // pokud map neobsahuje norm, ale text už má diakritiku, nespravujeme
        reason = 'alreadyCorrect';
      } else if (!titleInMap && !artistInMap) {
        // bez háčků a není v mapě
        final isComposite = _artistDelimiter.hasMatch(s.artist) ||
            _featParenPattern.hasMatch(s.artist) ||
            _featBarePattern.hasMatch(s.artist);
        reason = isComposite ? 'compositeNoMatch' : 'missingInMap';
      } else {
        // v mapě je, ale current == corrected (už opraveno)
        reason = 'alreadyCorrect';
      }
      // upřesnění: pokud už má diakritiku a map by vracel stejný text, je to alreadyCorrect
      result.add(DiacriticUnrepairedEntry(
        song: s,
        reason: reason,
        normTitle: normTitle,
        normArtist: normArtist,
      ));
    }
    return result;
  }

  /// Aplikuje potvrzené hromadné opravy diakritiky.
  /// Pokud [renameFiles] je true, pokusí se přejmenovat i soubory na disku (volitelně kvůli Windows).
  Future<DiacriticRepairResult> applyDiacriticRepairs(
    List<DiacriticRepairCandidate> candidates, {
    bool renameFiles = false,
  }) async {
    var dbCount = 0;
    // Uložit původní cesty před transakcí pro případné přejmenování
    final Map<int, SongEntry> byId = {};
    if (renameFiles && candidates.isNotEmpty) {
      final all = await select(songs).get();
      for (final s in all) {
        byId[s.id] = s;
      }
    }
    await transaction(() async {
      for (final c in candidates) {
        final res = await (update(songs)..where((t) => t.id.equals(c.songId))).write(
          SongsCompanion(title: Value(c.newTitle), artist: Value(c.newArtist)),
        );
        if (res > 0) dbCount++;
      }
    });
    if (!renameFiles) {
      return DiacriticRepairResult(dbUpdated: dbCount);
    }
    // Volitelné přejmenování souborů – mimo transakci, odolné vůči Windows zámkům
    var renamed = 0;
    var failed = 0;
    final failedPaths = <String>[];
    for (final c in candidates) {
      final song = byId[c.songId];
      if (song == null) continue;
      // přeskočit pokud se název nezměnil (nemělo by nastat, ale defenzivně)
      if (c.newTitle == song.title && c.newArtist == song.artist) continue;
      try {
        final oldFile = File(song.filePath);
        if (!await oldFile.exists()) continue;
        final dir = p.dirname(song.filePath);
        final safeArtist = c.newArtist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
        final safeTitle = c.newTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
        var newFileName = '${safeArtist.isNotEmpty ? '$safeArtist - ' : ''}$safeTitle.txt';
        var newPath = p.join(dir, newFileName);
        // Windows MAX_PATH ochrana – ořez názvu
        if (newPath.length > 240) {
          final ext = '.txt';
          final maxBase = 240 - dir.length - ext.length - 1;
          if (maxBase > 10) {
            newFileName = newFileName.substring(0, maxBase) + ext;
            newPath = p.join(dir, newFileName);
          }
        }
        var counter = 1;
        while (newPath != song.filePath && await File(newPath).exists()) {
          final base = newFileName.replaceAll('.txt', '');
          newPath = p.join(dir, '${base}_$counter.txt');
          counter++;
        }
        if (newPath != song.filePath) {
          await oldFile.rename(newPath);
          await (update(songs)..where((t) => t.id.equals(c.songId))).write(SongsCompanion(filePath: Value(newPath)));
          renamed++;
        }
      } catch (_) {
        failed++;
        failedPaths.add(song.filePath);
      }
    }
    return DiacriticRepairResult(
      dbUpdated: dbCount,
      filesRenamed: renamed,
      filesFailed: failed,
      failedPaths: failedPaths,
    );
  }

  /// (B) Kompatibilita: aplikace oprav z playlist syncu (DiacriticFixCandidate).
  Future<DiacriticRepairResult> applyDiacriticFixes(
    List<DiacriticFixCandidate> candidates, {
    bool renameFiles = false,
  }) async {
    // Deleguje na Repair variantu přes konverzi - sjednocené chování (A+B)
    return applyDiacriticRepairs(candidates.map((c) => c.toRepair()).toList(), renameFiles: renameFiles);
  }

  /// Zpětná kompatibilita pro volání očekávající int (vrací dbUpdated).
  Future<int> applyDiacriticRepairsLegacy(List<DiacriticRepairCandidate> candidates) async {
    final r = await applyDiacriticRepairs(candidates);
    return r.dbUpdated;
  }

  Future<String> exportDiacriticCsv() async {
    final rows = await select(diacriticMappings).get();
    final buffer = StringBuffer();
    // Přidání UTF-8 BOM pro správnou interpretaci v Excelu
    buffer.write('\uFEFF');
    buffer.writeln('bezDiakritiky,sDiakritikou');
    String escape(String s) => s.replaceAll('"', '""');
    for (final r in rows) {
      buffer.writeln('"${escape(r.normKey)}","${escape(r.corrected)}"');
    }
    return buffer.toString();
  }

  Future<DiacriticCsvImportResult> importDiacriticCsv(String csvContent) async {
    final content = csvContent.startsWith('\uFEFF') ? csvContent.substring(1) : csvContent;
    final lines = content.split(RegExp(r'\r?\n'));
    int count = 0;
    int skipped = 0;
    final errors = <String>[];
    await transaction(() async {
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = _parseDiacriticCsvLine(line);
        if (parts.length < 2) {
          skipped++;
          errors.add('ř.${i + 1}: $line');
          continue;
        }
        final key = _normForMatch(parts[0].split(';').first.trim());
        var rawValue = parts[1].trim();
        // Defenzivně ořež trailing artefakty z českého Excelu (oddělovač ; a zbytečné ))
        // a případný duplicitní obsah za středníkem: "Ivan Mládek;Ivan Mládek" -> "Ivan Mládek"
        if (rawValue.contains(';')) rawValue = rawValue.split(';').first.trim();
        rawValue = rawValue.replaceAll(RegExp(r'[;\)]+$'), '').trim();
        rawValue = rawValue.replaceAll(RegExp(r'^"+|"+$'), '').trim();
        final value = rawValue;
        if (key.isEmpty || value.isEmpty || key == value.toLowerCase().trim()) {
          skipped++;
          continue;
        }
        if (_normForMatch(value) != key) {
          skipped++;
          errors.add('ř.${i + 1}: odmítnuto (překlep, liší se písmena) $key -> $value');
          continue;
        }
        await into(diacriticMappings).insert(
          DiacriticMappingsCompanion.insert(normKey: key, corrected: value),
          mode: InsertMode.insertOrReplace,
        );
        count++;
      }
    });
    return DiacriticCsvImportResult(imported: count, skipped: skipped, errors: errors);
  }

  Future<int> createPlaylist(String name) => into(playlists).insert(PlaylistsCompanion.insert(name: name));
  
  Future<List<Playlist>> getAllPlaylists() => select(playlists).get();
  Future<int> deletePlaylist(int id) => (delete(playlists)..where((t) => t.id.equals(id))).go();
  Future<int> renamePlaylist(int id, String newName) =>
      (update(playlists)..where((t) => t.id.equals(id))).write(PlaylistsCompanion(name: Value(newName)));
  Future<int> addSongToPlaylist(int playlistId, int songId) async {
    final lastEntry = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.desc(t.orderIndex)])
          ..limit(1))
        .getSingleOrNull();
    final nextIndex = (lastEntry?.orderIndex ?? -1) + 1;
    return into(playlistSongs).insert(
        PlaylistSongsCompanion.insert(playlistId: playlistId, songId: songId, orderIndex: Value(nextIndex)),
        mode: InsertMode.insertOrIgnore);
  }

  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    final lastEntry = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.desc(t.orderIndex)])
          ..limit(1))
        .getSingleOrNull();
    
    int nextIndex = (lastEntry?.orderIndex ?? -1) + 1;

    await batch((batch) {
      for (final songId in songIds) {
        batch.insert(
          playlistSongs,
          PlaylistSongsCompanion.insert(
            playlistId: playlistId,
            songId: songId,
            orderIndex: Value(nextIndex++),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Future<void> reorderPlaylistSongs(int playlistId, int songId, bool moveUp) async {
    final allInPlaylist = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
        .get();

    final currentIndex = allInPlaylist.indexWhere((e) => e.songId == songId);
    if (currentIndex == -1) return;

    if (moveUp && currentIndex > 0) {
      final current = allInPlaylist[currentIndex];
      final previous = allInPlaylist[currentIndex - 1];
      await (update(playlistSongs)..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(current.songId)))
          .write(PlaylistSongsCompanion(orderIndex: Value(previous.orderIndex)));
      await (update(playlistSongs)..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(previous.songId)))
          .write(PlaylistSongsCompanion(orderIndex: Value(current.orderIndex)));
    } else if (!moveUp && currentIndex < allInPlaylist.length - 1) {
      final current = allInPlaylist[currentIndex];
      final next = allInPlaylist[currentIndex + 1];
      await (update(playlistSongs)..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(current.songId)))
          .write(PlaylistSongsCompanion(orderIndex: Value(next.orderIndex)));
      await (update(playlistSongs)..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(next.songId)))
          .write(PlaylistSongsCompanion(orderIndex: Value(current.orderIndex)));
    }
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) =>
      (delete(playlistSongs)..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId))).go();

  Future<void> clearCustomStrings() async {
    await delete(customStrings).go();
  }

  Future<void> movePlaylistSong(int playlistId, int songId, int newOrderIndex) async {
    await transaction(() async {
      final all = await (select(playlistSongs)
            ..where((t) => t.playlistId.equals(playlistId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();
      final curIdx = all.indexWhere((e) => e.songId == songId);
      if (curIdx == -1) return;
      final item = all.removeAt(curIdx);
      final target = newOrderIndex.clamp(0, all.length).toInt();
      all.insert(target, item);
      for (var i = 0; i < all.length; i++) {
        await (update(playlistSongs)
              ..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(all[i].songId)))
            .write(PlaylistSongsCompanion(orderIndex: Value(i)));
      }
    });
  }

  Stream<List<SongEntry>> watchSongsInPlaylist(int playlistId) {

    final query = select(songs).join([innerJoin(playlistSongs, playlistSongs.songId.equalsExp(songs.id))])
      ..where(playlistSongs.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistSongs.orderIndex)]);
    return query.watch().map((rows) => rows.map((row) => row.readTable(songs)).toList());
  }

  /// Stream pro setlist včetně per-song tempa (null = globální).
  Stream<List<PlaylistSongWithTempo>> watchSongsWithTempoInPlaylist(int playlistId) {
    final query = select(songs).join([innerJoin(playlistSongs, playlistSongs.songId.equalsExp(songs.id))])
      ..where(playlistSongs.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistSongs.orderIndex)]);
    return query.watch().map((rows) => rows.map((row) {
          final song = row.readTable(songs);
          final ps = row.readTable(playlistSongs);
          return PlaylistSongWithTempo(song: song, playlistTempo: ps.tempo, orderIndex: ps.orderIndex);
        }).toList());
  }

  Future<List<PlaylistSongWithTempo>> getPlaylistSongsWithTempo(int playlistId) async {
    final query = select(songs).join([innerJoin(playlistSongs, playlistSongs.songId.equalsExp(songs.id))])
      ..where(playlistSongs.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistSongs.orderIndex)]);
    final rows = await query.get();
    return rows.map((row) {
      final song = row.readTable(songs);
      final ps = row.readTable(playlistSongs);
      return PlaylistSongWithTempo(song: song, playlistTempo: ps.tempo, orderIndex: ps.orderIndex);
    }).toList();
  }

  Future<double?> getPlaylistSongTempo(int playlistId, int songId) async {
    final row = await (select(playlistSongs)..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId))).getSingleOrNull();
    return row?.tempo;
  }

  Future<Map<int, double?>> getPlaylistTemposMap(int playlistId) async {
    final rows = await (select(playlistSongs)..where((t) => t.playlistId.equals(playlistId))).get();
    return {for (final r in rows) r.songId: r.tempo};
  }

  Future<int> updatePlaylistSongTempo(int playlistId, int songId, double? tempo) =>
      (update(playlistSongs)..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId)))
          .write(PlaylistSongsCompanion(tempo: Value(tempo)));

  // --- ZÁLOHA A OBNOVENÍ ---
  Future<Map<String, dynamic>> exportToJson() async {
    final allSongs = await getAllSongs();
    final allPlaylists = await getAllPlaylists();
    final allStopMarks = await select(stopMarks).get();
    final allPlaylistSongs = await select(playlistSongs).get();

    return {
      'version': schemaVersion,
      'songs': allSongs.map((s) => s.toJson()).toList(),
      'playlists': allPlaylists.map((p) => p.toJson()).toList(),
      'stopMarks': allStopMarks.map((sm) => sm.toJson()).toList(),
      'playlistSongs': allPlaylistSongs.map((ps) => ps.toJson()).toList(),
    };
  }

  Future<void> importFromJson(Map<String, dynamic> data) async {
    await transaction(() async {
      // Vyčistíme stávající data (nebo můžeme inteligentně spojovat, pro začátek čistý import)
      await delete(playlistSongs).go();
      await delete(stopMarks).go();
      await delete(playlists).go();
      await delete(songs).go();

      for (final s in data['songs']) {
        await into(songs).insert(SongEntry.fromJson(s));
      }
      for (final p in data['playlists']) {
        await into(playlists).insert(Playlist.fromJson(p));
      }
      for (final sm in data['stopMarks']) {
        await into(stopMarks).insert(StopMark.fromJson(sm));
      }
      for (final ps in data['playlistSongs']) {
        await into(playlistSongs).insert(PlaylistSong.fromJson(ps));
      }
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));

    if (Platform.isAndroid) {
      sqlite3.tempDirectory = dbFolder.path;
    }

    return NativeDatabase(file);
  });
}
