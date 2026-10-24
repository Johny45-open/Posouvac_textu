import 'package:flutter_test/flutter_test.dart';
import 'package:posouvac_textu/database.dart';
import 'package:drift/drift.dart' as drift;

void main() {
  group('E1 & E2 Setlist Navigation & Occurrence Row Operations Tests', () {
    test('Duplicate songs in setlist have distinct playlistSongId and occurrenceId', () {
      final entries = [
        PlaylistOccurrenceRef(playlistSongId: 1, songId: 42, occurrenceId: 'uuid-1'),
        PlaylistOccurrenceRef(playlistSongId: 2, songId: 42, occurrenceId: 'uuid-2'),
        PlaylistOccurrenceRef(playlistSongId: 3, songId: 99, occurrenceId: 'uuid-3'),
      ];

      int findIndexByPlaylistSongId(int? psId, String? occId, int fallbackSongId) {
        if (psId != null) {
          final idx = entries.indexWhere((e) => e.playlistSongId == psId);
          if (idx != -1) return idx;
        }
        if (occId != null && occId.isNotEmpty) {
          final idx = entries.indexWhere((e) => e.occurrenceId == occId);
          if (idx != -1) return idx;
        }
        return entries.indexWhere((e) => e.songId == fallbackSongId);
      }

      expect(findIndexByPlaylistSongId(1, null, 42), 0);
      expect(findIndexByPlaylistSongId(2, null, 42), 1);
      expect(findIndexByPlaylistSongId(null, 'uuid-3', 99), 2);
      expect(findIndexByPlaylistSongId(null, null, 42), 0);
    });

    test('E2: Remove specific occurrence leaves other occurrences and song intact', () async {
      final db = AppDatabase.forTesting();
      addTearDown(() => db.close());

      final songId = await db.into(db.songs).insert(SongsCompanion.insert(
        title: 'Shared Song',
        artist: 'Artist',
        filePath: 'dummy.txt',
      ));

      final playlistId = await db.into(db.playlists).insert(PlaylistsCompanion.insert(
        name: 'Test Playlist',
        playlistUid: 'pl-uid-e2-1',
      ));

      // Add two occurrences of the same song
      final psId1 = await db.into(db.playlistSongs).insert(PlaylistSongsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        orderIndex: const drift.Value(0),
        occurrenceId: 'occ-e2-1',
        tempo: const drift.Value(100.0),
      ));

      final psId2 = await db.into(db.playlistSongs).insert(PlaylistSongsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        orderIndex: const drift.Value(1),
        occurrenceId: 'occ-e2-2',
        tempo: const drift.Value(120.0),
      ));

      // Remove first occurrence
      await db.removePlaylistSongRow(psId1);

      final remaining = await db.getPlaylistOccurrences(playlistId);
      expect(remaining.length, 1);
      expect(remaining.first.playlistSongId, psId2);
      expect(remaining.first.occurrenceId, 'occ-e2-2');

      // Song should still exist in library
      final song = await (db.select(db.songs)..where((t) => t.id.equals(songId))).getSingleOrNull();
      expect(song, isNotNull);
    });

    test('E2: Reorder and move row maintains correct unique order and occurrenceId', () async {
      final db = AppDatabase.forTesting();
      addTearDown(() => db.close());

      final songId = await db.into(db.songs).insert(SongsCompanion.insert(
        title: 'Song',
        artist: 'Artist',
        filePath: 'dummy.txt',
      ));

      final playlistId = await db.into(db.playlists).insert(PlaylistsCompanion.insert(
        name: 'Test Playlist 2',
        playlistUid: 'pl-uid-e2-2',
      ));

      final psId1 = await db.into(db.playlistSongs).insert(PlaylistSongsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        orderIndex: const drift.Value(0),
        occurrenceId: 'occ-move-1',
      ));

      final psId2 = await db.into(db.playlistSongs).insert(PlaylistSongsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        orderIndex: const drift.Value(1),
        occurrenceId: 'occ-move-2',
      ));

      // Move row 1 down (or reorder row 1 down)
      await db.reorderPlaylistSongRow(psId1, false);

      final occsAfterReorder = await db.getPlaylistOccurrences(playlistId);
      expect(occsAfterReorder[0].playlistSongId, psId2);
      expect(occsAfterReorder[1].playlistSongId, psId1);
      // occurrenceId must not change during move/reorder
      expect(occsAfterReorder[0].occurrenceId, 'occ-move-2');
      expect(occsAfterReorder[1].occurrenceId, 'occ-move-1');

      // Move psId1 to position 0
      await db.movePlaylistSongRow(psId1, 0);

      final occsAfterMove = await db.getPlaylistOccurrences(playlistId);
      expect(occsAfterMove[0].playlistSongId, psId1);
      expect(occsAfterMove[1].playlistSongId, psId2);
    });
  });
}
