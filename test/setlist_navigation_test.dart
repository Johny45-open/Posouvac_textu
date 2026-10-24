import 'package:flutter_test/flutter_test.dart';
import 'package:posouvac_textu/database.dart';
import 'package:drift/drift.dart' as drift;

void main() {
  group('E3 Per-occurrence scrollSpeed and introDuration Tests', () {
    test('E3: Two occurrences of same song can have different scrollSpeed and introDuration', () async {
      final db = AppDatabase.forTesting();
      addTearDown(() => db.close());

      final songId = await db.into(db.songs).insert(SongsCompanion.insert(
        title: 'Multi-speed Song',
        artist: 'Artist',
        filePath: 'dummy.txt',
        customScrollSpeed: const drift.Value(1.0),
        introDuration: const drift.Value(3.0),
      ));

      final playlistId = await db.into(db.playlists).insert(PlaylistsCompanion.insert(
        name: 'E3 Playlist',
        playlistUid: 'pl-e3-1',
      ));

      // Occ 1: custom speed 1.5, intro 5.0
      final psId1 = await db.into(db.playlistSongs).insert(PlaylistSongsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        orderIndex: const drift.Value(0),
        occurrenceId: 'occ-e3-1',
        scrollSpeed: const drift.Value(1.5),
        introDuration: const drift.Value(5.0),
      ));

      // Occ 2: NULL values (should fallback to song defaults)
      final psId2 = await db.into(db.playlistSongs).insert(PlaylistSongsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        orderIndex: const drift.Value(1),
        occurrenceId: 'occ-e3-2',
        scrollSpeed: const drift.Value.absent(),
        introDuration: const drift.Value.absent(),
      ));

      final row1 = await db.getPlaylistSongRowById(psId1);
      final row2 = await db.getPlaylistSongRowById(psId2);
      final song = await (db.select(db.songs)..where((t) => t.id.equals(songId))).getSingle();

      expect(row1?.scrollSpeed, 1.5);
      expect(row1?.introDuration, 5.0);

      // NULL values test fallback rule
      expect(row2?.scrollSpeed, isNull);
      expect(row2?.introDuration, isNull);
      final effectiveSpeed2 = row2?.scrollSpeed ?? song.customScrollSpeed;
      final effectiveIntro2 = row2?.introDuration ?? song.introDuration;
      expect(effectiveSpeed2, 1.0);
      expect(effectiveIntro2, 3.0);

      // Updating occurrence 1 settings does not change occurrence 2
      await db.updatePlaylistSongSettingsById(psId1, scrollSpeed: 2.0, introDuration: 10.0);
      
      final updatedRow1 = await db.getPlaylistSongRowById(psId1);
      final updatedRow2 = await db.getPlaylistSongRowById(psId2);

      expect(updatedRow1?.scrollSpeed, 2.0);
      expect(updatedRow1?.introDuration, 10.0);
      expect(updatedRow2?.scrollSpeed, isNull);
      expect(updatedRow2?.introDuration, isNull);
    });
  });
}
