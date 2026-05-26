import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'song_entry.dart';

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
  AppDatabase() : super(_openConnection());

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

  Future<int> addSongToPlaylist(int playlistId, int songId) {
    return into(playlistSongs).insert(PlaylistSongsCompanion.insert(playlistId: playlistId, songId: songId));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
