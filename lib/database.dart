import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'song_entry.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';

part 'database.g.dart';

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

  @override
  int get schemaVersion => 8;

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

  Future<int> updateSongDuration(int id, int? seconds) =>
      (update(songs)..where((s) => s.id.equals(id))).write(SongsCompanion(duration: Value(seconds)));

  Future<int> updateSongSettings(int id, double? bpm, double? introDuration, double fontSize, double scrollMultiplier) =>
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
  
  Future<List<StopMark>> getStopMarksForSong(int songId) =>
      (select(stopMarks)..where((t) => t.songId.equals(songId))).get();

  Future<int> deleteStopMark(int id) => (delete(stopMarks)..where((t) => t.id.equals(id))).go();

  Future<String> exportSongsToCsv() async {
    final songs = await select(this.songs).get();
    final buffer = StringBuffer();
    // Přidání UTF-8 BOM pro správnou interpretaci v Excelu
    buffer.write('\uFEFF');
    buffer.writeln("id,artist,title,duration");
    for (final song in songs) {
      buffer.writeln("${song.id},\"${song.artist}\",\"${song.title}\",${song.duration ?? 0}");
    }
    return buffer.toString();
  }

  Future<int> importSongsFromCsv(String csvContent) async {
    print("DEBUG: ZAHÁJEN IMPORT S DÉLKOU: ${csvContent.length}");
    final content = csvContent.startsWith('\uFEFF') ? csvContent.substring(1) : csvContent;
    final lines = content.split('\n');
    if (lines.length < 2) {
      print("DEBUG: Import ukončen - příliš krátký soubor");
      return 0; // Header + at least one data line
    }

    int updatedCount = 0;
    await transaction(() async {
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        // Robustnější split: prostě rozdělit podle čárky, pak vyčistit uvozovky
        final parts = line.split(',').map((p) => p.trim().replaceAll('"', '').trim()).toList();
        
        print("DEBUG: Řádek $i, počet částí: ${parts.length}, části: $parts");

        // Pokud máme alespoň ID, pokusíme se o import i s menším počtem sloupců
        if (parts.isEmpty) {
          print("DEBUG: Přeskakuji řádek $i, prázdný");
          continue;
        }
        
        // ID může být obalené uvozovkami nebo obsahovat jiné znaky, vyčistíme ho na čisté číslo
        final idStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '').trim();
        final id = int.tryParse(idStr);
        final artist = parts.length > 1 ? parts[1].trim() : "Neznámý";
        final title = parts.length > 2 ? parts[2].trim() : "Neznámý";
        final duration = parts.length > 3 ? int.tryParse(parts[3].trim()) ?? 0 : 0;

        print("DEBUG: Importovat ID: $id (původně: ${parts[0]}), Interpret: $artist, Název: $title");

        if (id != null) {
          final result = await (update(songs)..where((t) => t.id.equals(id))).write(
            SongsCompanion(
              artist: Value(artist),
              title: Value(title),
              duration: Value(duration > 0 ? duration : null),
            ),
          );
          print("DEBUG: Výsledek aktualizace ID $id: $result");
          if (result > 0) updatedCount++;
        } else {
          print("DEBUG: Nepodařilo se naparsovat ID: ${parts[0]}");
        }
      }
    });
    return updatedCount;
  }

  Future<List<Map<String, dynamic>>> previewSongsFromCsv(String csvContent) async {
    final content = csvContent.startsWith('\uFEFF') ? csvContent.substring(1) : csvContent;
    final lines = content.split('\n');
    if (lines.length < 2) return [];

    final preview = <Map<String, dynamic>>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      final pattern = RegExp(r',(?=(?:(?:[^"]*"){2})*[^"]*$)');
      final parts = line.split(pattern).map((p) => p.trim().replaceAll('"', '').trim()).toList();
      
      print("DEBUG: Řádek $i, díly: $parts"); 

      if (parts.length < 4) {
        print("DEBUG: Přeskakuji řádek $i, málo sloupců");
        continue;
      }
      
      final id = int.tryParse(parts[0]);
      print("DEBUG: Zkouším ID: $id");
      
      if (id != null) {
        final song = await (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (song != null) {
          preview.add({
            'id': id,
            'oldArtist': song.artist,
            'newArtist': parts[1],
            'oldTitle': song.title,
            'newTitle': parts[2],
            'newDuration': int.tryParse(parts[3]) ?? 0,
          });
        } else {
          print("DEBUG: Píseň s ID $id nenalezena v databázi");
        }
      } else {
         print("DEBUG: Nepodařilo se naparsovat ID: ${parts[0]}");
      }
    }
    return preview;
  }

  Future<void> syncPlaylistFromJson(Map<String, dynamic> data) async {
    final playlistName = data['name'] as String;
    final songTitles = (data['songs'] as List<dynamic>).cast<String>();

    await transaction(() async {
      // 1. Najít nebo vytvořit playlist
      Playlist? playlist = await (select(playlists)..where((t) => t.name.equals(playlistName))).getSingleOrNull();
      int playlistId;
      if (playlist == null) {
        playlistId = await into(playlists).insert(PlaylistsCompanion.insert(name: playlistName));
      } else {
        playlistId = playlist.id;
        // Vyčistit stávající songy v playlistu pro novou verzi
        await (delete(playlistSongs)..where((t) => t.playlistId.equals(playlistId))).go();
      }

      // 2. Přiřadit písně
      int order = 0;
      for (final title in songTitles) {
        final song = await (select(songs)..where((t) => t.title.equals(title))).getSingleOrNull();
        if (song != null) {
          await into(playlistSongs).insert(
            PlaylistSongsCompanion.insert(
              playlistId: playlistId,
              songId: song.id,
              orderIndex: Value(order++),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
    });
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

  Future<void> movePlaylistSong(int playlistId, int songId, int newOrderIndex) async {
    await (update(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId)))
        .write(PlaylistSongsCompanion(orderIndex: Value(newOrderIndex)));
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
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      sqlite3.tempDirectory = dbFolder.path;
    }

    return NativeDatabase(file);
  });
}
