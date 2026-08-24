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
}

class PlaylistSyncResult {
  final String playlistName;
  final int matchedCount;
  final List<String> notFound;
  final int totalDurationShared;
  final int unknownShared;
  final List<DurationFixCandidate> durationCandidates;
  final List<DiacriticFixCandidate> diacriticCandidates;

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

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

class PlaylistSongs extends Table {
  IntColumn get playlistId => integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get songId => integer().references(Songs, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {playlistId, songId};
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

@DriftDatabase(tables: [Songs, Playlists, PlaylistSongs, StopMarks, CustomStrings])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();

  AppDatabase._internal() : super(_openConnection());

  factory AppDatabase() => instance;

  /// Testovací databáze v paměti (bez platformních kanálů).
  factory AppDatabase.forTesting() => AppDatabase._testing();

  AppDatabase._testing() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 9;

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

  /// Export setlistu včetně časů pro sdílení (v2). Vrací mapu připravenou pro jsonEncode.
  Future<Map<String, dynamic>> exportPlaylistToJson(int playlistId, {bool includeContents = false}) async {
    final playlist = await (select(playlists)..where((t) => t.id.equals(playlistId))).getSingle();
    final songsInPlaylist = await watchSongsInPlaylist(playlistId).first;
    int totalDuration = 0;
    int unknownCount = 0;
    for (final s in songsInPlaylist) {
      if (s.duration != null && s.duration! > 0) {
        totalDuration += s.duration!;
      } else {
        unknownCount++;
      }
    }
    final songsJson = <Map<String, dynamic>>[];
    for (final s in songsInPlaylist) {
      final entry = <String, dynamic>{
        'title': s.title,
        'artist': s.artist,
        'duration': s.duration,
      };
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
        parsedSongs.add({'title': title, 'artist': artist, 'duration': duration, 'content': m['content']});
        if (duration != null && duration > 0) {
          if (totalDurationShared == 0) totalDurationShared += duration;
        } else {
          if (unknownShared == 0 && data['totalDuration'] == null) unknownShared++;
        }
      } else {
        final title = raw.toString().trim();
        if (title.isEmpty) continue;
        parsedSongs.add({'title': title, 'artist': '', 'duration': null});
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
          // Zkusit vytvořit píseň přes importSongPackage logiku (bez duplikace)
          final created = await _importSongWithContent(title: title, artist: artist, content: content, duration: duration);
          if (created != null) {
            // Najít playlistId znovu
            final pl = await (select(playlists)..where((t) => t.name.equals(playlistName))).getSingle();
            await into(playlistSongs).insert(
              PlaylistSongsCompanion.insert(playlistId: pl.id, songId: created.id, orderIndex: Value(matchedCount++)),
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
    final diacriticCandidates = <DiacriticFixCandidate>[];
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
        diacriticCandidates.add(DiacriticFixCandidate(
          songId: song.id,
          oldTitle: song.title,
          oldArtist: song.artist,
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

  Future<SongEntry?> _importSongWithContent({required String title, required String artist, required String content, int? duration}) async {
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

  Future<int> applyDiacriticFixes(List<DiacriticFixCandidate> candidates) async {
    var count = 0;
    await transaction(() async {
      for (final c in candidates) {
        final res = await (update(songs)..where((t) => t.id.equals(c.songId))).write(SongsCompanion(title: Value(c.newTitle), artist: Value(c.newArtist)));
        if (res > 0) count++;
      }
    });
    return count;
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
