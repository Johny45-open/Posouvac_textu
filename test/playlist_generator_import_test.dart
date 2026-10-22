import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:posouvac_textu/database.dart';

/// Fake path_provider – vrací dočasný adresář, aby test fungoval i bez
/// skutečného mobilního prostředí (jinak se test zasekává na platformovém
/// kanálu path_provider při ukládání obsahu nové písně).
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.baseDir);

  final Directory baseDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => baseDir.path;
}

void main() {
  test('Generator playlist import JSON', () async {
    final tmpDir = await Directory.systemTemp.createTemp('pg_import_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tmpDir);
    addTearDown(() async {
      try {
        await tmpDir.delete(recursive: true);
      } catch (_) {}
    });

    final db = AppDatabase.forTesting();
    addTearDown(db.close);

    // 1. Create songs in library
    await db.into(db.songs).insert(SongsCompanion.insert(filePath: 'a.txt', artist: 'Artist A', title: 'Title A'));
    await db.into(db.songs).insert(SongsCompanion.insert(filePath: 'b.txt', artist: 'Artist B', title: 'Title B'));

    // 2. Generate Generator JSON
    final jsonMap = {
      'type': 'playlist',
      'version': 2,
      'name': 'Test Playlist',
      'songs': [
        {'title': 'Title A', 'artist': 'Artist A', 'duration': 210},
        {'title': 'Title B', 'artist': 'Artist B', 'duration': 120},
        {'title': 'Title C', 'artist': 'Artist C', 'duration': 300, 'content': 'Content C'}
      ]
    };

    // 3. Sync
    final result = await db.syncPlaylistFromJson(jsonMap);

    // Písně A a B se shodují v knihovně, C se vytvoří z dodaného obsahu.
    expect(result.matchedCount, 3);
    expect(result.notFound, isEmpty);

    // 4. Verify playlists and songs
    final playlists = await db.getAllPlaylists();
    expect(playlists.length, 1);
    expect(playlists.first.name, 'Test Playlist');

    final songsInPlaylist = await db.getPlaylistSongsWithTempo(playlists.first.id);
    expect(songsInPlaylist.length, 3);

    // Nově vytvořená píseň má uložený soubor s obsahem.
    final created = songsInPlaylist.firstWhere((e) => e.song.title == 'Title C');
    expect(File(created.song.filePath).readAsStringSync(), 'Content C');
  });
}
