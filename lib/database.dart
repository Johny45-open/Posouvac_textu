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

  @override
  Set<Column> get primaryKey => {playlistId, songId};
}

class StopMarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get songId => integer().references(Songs, #id, onDelete: KeyAction.cascade)();
  RealColumn get positionRatio => real()(); // Procentuální pozice (0.0 - 1.0)
  IntColumn get durationBars => integer()(); // Délka pauzy v taktech
}

@DriftDatabase(tables: [Songs, Playlists, PlaylistSongs, StopMarks])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();

  AppDatabase._internal() : super(_openConnection());

  factory AppDatabase() => instance;

  @override
  int get schemaVersion => 5;

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
      },
    );
  }

  // Metody pro písně
  Future<List<SongEntry>> getAllSongs() => select(songs).get();
  
  Stream<List<SongEntry>> watchAllSongs({bool onlyFavorites = false, bool onlyUnplayed = false}) {
    final query = select(songs);
    if (onlyFavorites) query.where((s) => s.isFavorite.equals(true));
    if (onlyUnplayed) query.where((s) => s.isPlayed.equals(false));
    return query.watch();
  }

  Future<int> toggleFavorite(int id, bool isFavorite) =>
      (update(songs)..where((s) => s.id.equals(id))).write(SongsCompanion(isFavorite: Value(isFavorite)));

  Future<int> togglePlayed(int id, bool isPlayed) =>
      (update(songs)..where((s) => s.id.equals(id))).write(SongsCompanion(isPlayed: Value(isPlayed)));

  Future<int> resetAllPlayed() => (update(songs)).write(const SongsCompanion(isPlayed: Value(false)));

  Future<int> updateSong(int id, String newArtist, String newTitle) =>
      (update(songs)..where((s) => s.id.equals(id))).write(SongsCompanion(artist: Value(newArtist), title: Value(newTitle)));

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

  // Metody pro playlisty
  Future<int> createPlaylist(String name) => into(playlists).insert(PlaylistsCompanion.insert(name: name));
  Future<List<Playlist>> getAllPlaylists() => select(playlists).get();
  Future<int> deletePlaylist(int id) => (delete(playlists)..where((t) => t.id.equals(id))).go();
  Future<int> renamePlaylist(int id, String newName) =>
      (update(playlists)..where((t) => t.id.equals(id))).write(PlaylistsCompanion(name: Value(newName)));
  Future<int> addSongToPlaylist(int playlistId, int songId) =>
      into(playlistSongs).insert(PlaylistSongsCompanion.insert(playlistId: playlistId, songId: songId), mode: InsertMode.insertOrIgnore);
  Future<int> removeSongFromPlaylist(int playlistId, int songId) =>
      (delete(playlistSongs)..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId))).go();
  Stream<List<SongEntry>> watchSongsInPlaylist(int playlistId) {
    final query = select(songs).join([innerJoin(playlistSongs, playlistSongs.songId.equalsExp(songs.id))])
      ..where(playlistSongs.playlistId.equals(playlistId));
    return query.watch().map((rows) => rows.map((row) => row.readTable(songs)).toList());
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
