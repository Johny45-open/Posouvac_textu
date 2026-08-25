import 'package:flutter_test/flutter_test.dart';
import 'package:posouvac_textu/database.dart';
import 'dart:convert';

void main() {
  test('Generator playlist import JSON', () async {
    final db = AppDatabase.forTesting();
    
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

    expect(result.matchedCount, 2);
    expect(result.notFound.length, 1);
    expect(result.notFound.first, 'Artist C - Title C');

    // 4. Verify playlists and songs
    final playlists = await db.getAllPlaylists();
    expect(playlists.length, 1);
    expect(playlists.first.name, 'Test Playlist');

    final songsInPlaylist = await db.getPlaylistSongsWithTempo(playlists.first.id);
    expect(songsInPlaylist.length, 2);
  });
}
