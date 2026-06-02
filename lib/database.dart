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
}

@DriftDatabase(tables: [Songs, Playlists, PlaylistSongs])
class AppDatabase extends _$AppDatabase {
  // Singleton instance
  static final AppDatabase instance = AppDatabase._internal();

  AppDatabase._internal() : super(_openConnection());

  factory AppDatabase() => instance;

  @override
  int get schemaVersion => 1;

  // Metody pro přístup k datům
  Future<List<SongEntry>> getAllSongs() => select(songs).get();
  
  Stream<List<SongEntry>> watchAllSongs({bool onlyFavorites = false}) {
    final query = select(songs);
    if (onlyFavorites) {
      query.where((s) => s.isFavorite.equals(true));
    }
    return query.watch();
  }

  Future<int> toggleFavorite(int id, bool isFavorite) {
    return (update(songs)..where((s) => s.id.equals(id)))
        .write(SongsCompanion(isFavorite: Value(isFavorite)));
  }

  Future<int> updateSong(int id, String newArtist, String newTitle) {
    return (update(songs)..where((s) => s.id.equals(id)))
        .write(SongsCompanion(artist: Value(newArtist), title: Value(newTitle)));
  }

  // Metody pro správu playlistů
  Future<int> createPlaylist(String name) {
    return into(playlists).insert(PlaylistsCompanion.insert(name: name));
  }

  Future<List<Playlist>> getAllPlaylists() => select(playlists).get();

  Future<int> deletePlaylist(int id) => (delete(playlists)..where((t) => t.id.equals(id))).go();

  Future<int> renamePlaylist(int id, String newName) =>
      (update(playlists)..where((t) => t.id.equals(id))).write(PlaylistsCompanion(name: Value(newName)));

  Future<int> addSongToPlaylist(int playlistId, int songId) {
    return into(playlistSongs).insert(PlaylistSongsCompanion.insert(playlistId: playlistId, songId: songId),
        mode: InsertMode.insertOrIgnore);
  }

  Future<int> removeSongFromPlaylist(int playlistId, int songId) => (delete(playlistSongs)
        ..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId)))
      .go();

  Stream<List<SongEntry>> watchSongsInPlaylist(int playlistId) {
    final query = select(songs).join([
      innerJoin(playlistSongs, playlistSongs.songId.equalsExp(songs.id)),
    ])
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
