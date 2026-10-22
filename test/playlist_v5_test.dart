import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:posouvac_textu/database.dart';

/// Regresní testy etapy A1.3 – JSON v5 (playlistUid + occurrenceId).
/// Všechny testy volají reálné produkční metody AppDatabase
/// (exportPlaylistToJson, syncPlaylistFromJson, importFromJson, exportToJson).
///
/// T-13I (stop_marks_resolution_test) a T-13J (database_migration_test)
/// jsou samostatné soubory – ověřují se plnou testovou sadou.
void main() {
  // T-13F záměrně vytváří dvě instance AppDatabase pro ověření oddělení
  // formátů – varování Driftu o vícenásobném otevření není relevantní.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  /// Naplní knihovnu písněmi a vrátí id (songId 1., 2., ...).
  Future<List<int>> seedSongs(AppDatabase db, List<List<String>> artistTitle) async {
    final ids = <int>[];
    var i = 0;
    for (final at in artistTitle) {
      i++;
      ids.add(await db.into(db.songs).insert(SongsCompanion.insert(
          filePath: 'song$i.txt', artist: at[0], title: at[1])));
    }
    return ids;
  }

  /// Sestaví v5 soubor kontraktu PC editoru (kanonická pole + occurrenceId).
  Map<String, dynamic> v5File({
    required String name,
    required String uid,
    required List<Map<String, dynamic>> songs,
    Map<String, dynamic> extraTop = const {},
  }) =>
      {
        'type': 'playlist',
        'version': 5,
        'playlistUid': uid,
        'name': name,
        'totalDuration': 0,
        'unknownCount': 0,
        'songs': songs,
        ...extraTop,
      };

  // ------------------------------------------------------------------ T-13A
  test('T-13A: Export setlistu obsahuje version 5, playlistUid a occurrenceId', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final ids = await seedSongs(db, [
      ['Interpret A', 'Píseň A'],
      ['Interpret B', 'Píseň B'],
    ]);
    final plId = await db.createPlaylist('Můj setlist');
    await db.addSongsToPlaylist(plId, ids);

    final json = await db.exportPlaylistToJson(plId);

    expect(json['version'], 5);
    final uid = json['playlistUid'] as String?;
    expect(uid, isNotNull);
    expect(uid, isNotEmpty);
    // UUID v4 ve tvaru Python str(uuid.uuid4()).
    expect(uid, matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));

    final songs = (json['songs'] as List).cast<Map<String, dynamic>>();
    expect(songs.length, 2);
    final occIds = <String>{};
    for (final s in songs) {
      final occ = s['occurrenceId'] as String?;
      expect(occ, isNotNull);
      expect(occ, isNotEmpty);
      expect(occIds.add(occ!), isTrue, reason: 'occurrenceId musí být unikátní');
    }
  });

  // ------------------------------------------------------------------ T-13B
  test('T-13B: Opakovaný export zachová playlistUid i všechna occurrenceId', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final ids = await seedSongs(db, [
      ['Interpret A', 'Píseň A'],
      ['Interpret B', 'Píseň B'],
    ]);
    final plId = await db.createPlaylist('Setlist');
    await db.addSongsToPlaylist(plId, ids);

    final first = await db.exportPlaylistToJson(plId);
    final second = await db.exportPlaylistToJson(plId);

    expect(first['playlistUid'], second['playlistUid']);
    List<String> occ(Map<String, dynamic> j) => (j['songs'] as List)
        .map((s) => (s as Map)['occurrenceId'] as String)
        .toList();
    expect(occ(second), occ(first));
  });

  // ------------------------------------------------------------------ T-13C
  test('T-13C: Dvě položky téže písně s různými occurrenceId zůstanou dvěma položkami', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    await seedSongs(db, [
      ['Interpret A', 'Píseň A'],
    ]);

    final file = v5File(
      name: 'Opakované',
      uid: '11111111-2222-4333-8444-555555555555',
      songs: [
        {
          'occurrenceId': 'aaaaaaaa-1111-4222-8333-bbbbbbbbbbbb',
          'title': 'Píseň A',
          'artist': 'Interpret A',
          'duration': 100,
          'tempo': 90.0,
        },
        {
          'occurrenceId': 'cccccccc-1111-4222-8333-dddddddddddd',
          'title': 'Píseň A',
          'artist': 'Interpret A',
          'duration': 100,
          'tempo': 120.0,
        },
      ],
    );
    final result = await db.syncPlaylistFromJson(file);
    expect(result.matchedCount, 2);
    expect(result.notFound, isEmpty);

    final playlists = await db.getAllPlaylists();
    expect(playlists.length, 1);
    final items = await db.getPlaylistSongsWithTempo(playlists.first.id);
    expect(items.length, 2, reason: 'stejná píseň + různé occurrenceId = 2 výskyty');
    expect(items.map((e) => e.occurrenceId).toSet(), {
      'aaaaaaaa-1111-4222-8333-bbbbbbbbbbbb',
      'cccccccc-1111-4222-8333-dddddddddddd',
    });
    // Per-výskytová tempo zůstala odlišná.
    expect(items.map((e) => e.playlistTempo).toSet(), {90.0, 120.0});

    // Po exportu zůstávají dvě položky s týmiž identitami.
    final exported = await db.exportPlaylistToJson(playlists.first.id);
    final songs = (exported['songs'] as List).cast<Map<String, dynamic>>();
    expect(songs.length, 2);
    expect(songs.map((s) => s['occurrenceId']).toSet(), {
      'aaaaaaaa-1111-4222-8333-bbbbbbbbbbbb',
      'cccccccc-1111-4222-8333-dddddddddddd',
    });
  });

  // ------------------------------------------------------------------ T-13D
  test('T-13D: Opakovaný import v5 je idempotentní (stejné počty i identity)', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    await seedSongs(db, [
      ['Interpret A', 'Píseň A'],
      ['Interpret B', 'Píseň B'],
    ]);

    final file = v5File(
      name: 'Idempotentní',
      uid: '99999999-8888-4777-8666-555555555555',
      songs: [
        {
          'occurrenceId': 'eeeeeeee-1111-4222-8333-ffffffffffff',
          'title': 'Píseň A',
          'artist': 'Interpret A',
          'duration': 100,
        },
        {
          'occurrenceId': 'abcdefab-1111-4222-8333-000000000000',
          'title': 'Píseň B',
          'artist': 'Interpret B',
          'duration': 200,
        },
      ],
    );

    final first = await db.syncPlaylistFromJson(file);
    expect(first.createdNewPlaylist, isTrue);
    expect(first.playlistUid, '99999999-8888-4777-8666-555555555555');

    final second = await db.syncPlaylistFromJson(file);
    expect(second.createdNewPlaylist, isFalse,
        reason: 'setlist s tímto uid už existuje – nesmí se vytvořit kopie');

    final playlists = await db.getAllPlaylists();
    expect(playlists.length, 1, reason: 'žádná kopie setlistu');
    final items = await db.getPlaylistSongsWithTempo(playlists.first.id);
    expect(items.length, 2, reason: 'žádné zdvojení výskytů');
    expect(items.map((e) => e.occurrenceId).toSet(), {
      'eeeeeeee-1111-4222-8333-ffffffffffff',
      'abcdefab-1111-4222-8333-000000000000',
    });
    // Pořadí podle souboru zůstalo deterministické.
    expect(items.map((e) => e.orderIndex).toList(), [0, 1]);
  });

  // ------------------------------------------------------------------ T-13E
  test('T-13E: Legacy v3/v4 bez identit – nové lokální identity, žádné potichu přepsání', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    await seedSongs(db, [
      ['Interpret A', 'Píseň A'],
    ]);

    // v4 soubor bez playlistUid/occurrenceId (starý kontrakt).
    Map<String, dynamic> legacyFile() => {
          'type': 'playlist',
          'version': 4,
          'name': 'Starý setlist',
          'totalDuration': 100,
          'unknownCount': 0,
          'songs': [
            {'title': 'Píseň A', 'artist': 'Interpret A', 'duration': 100},
          ],
        };

    // První import: nový setlist s vygenerovanými identitami.
    final first = await db.syncPlaylistFromJson(legacyFile());
    expect(first.createdNewPlaylist, isTrue);
    expect(first.playlistUid, isNotEmpty);
    final playlists = await db.getAllPlaylists();
    expect(playlists.length, 1);
    final items = await db.getPlaylistSongsWithTempo(playlists.first.id);
    expect(items.single.occurrenceId, isNotEmpty);
    final originalOcc = items.single.occurrenceId;

    // Opakovaný import téhož souboru bez identit: setlist stejného jména
    // existuje → srozumitelná chyba, žádné potichu přepsání ani kopie.
    await expectLater(
        db.syncPlaylistFromJson(legacyFile()), throwsA(isA<FormatException>()));
    final after = await db.getAllPlaylists();
    expect(after.length, 1, reason: 'žádná kopie ani smazání');
    final itemsAfter = await db.getPlaylistSongsWithTempo(after.first.id);
    expect(itemsAfter.single.occurrenceId, originalOcc,
        reason: 'data zůstala beze změny');
  });

  // ------------------------------------------------------------------ T-13F
  test('T-13F: Plná záloha a setlist v5 jsou oddělené formáty', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final ids = await seedSongs(db, [
      ['Interpret A', 'Píseň A'],
    ]);
    final plId = await db.createPlaylist('Setlist');
    await db.addSongsToPlaylist(plId, ids);

    // Plná záloha: version = schéma databáze (13), ne verze setlistu (5),
    // a obsahuje playlists.
    final backup = await db.exportToJson();
    expect(backup['version'], 13);
    expect(backup['playlists'], isA<List>());
    expect(backup.containsKey('type'), isFalse);

    // Simulace starší zálohy v12 (bez playlistUid) – musí zůstat importovatelná.
    final v12 = Map<String, dynamic>.from(backup);
    v12['version'] = 12;
    v12['playlists'] = [
      for (final p in (backup['playlists'] as List))
        Map<String, dynamic>.from(p as Map)..remove('playlistUid'),
    ];
    final db2 = AppDatabase.forTesting();
    addTearDown(db2.close);
    await db2.importFromJson(v12);
    final restored = await db2.getAllPlaylists();
    expect(restored.length, 1);
    expect(restored.single.playlistUid, isNotEmpty,
        reason: 'v12 záloha dostane doplněný lokální uid');

    // Setlist v5 se nesmí importovat jako záloha – jinak by smazal knihovnu.
    final setlist = await db.exportPlaylistToJson(plId);
    await expectLater(db2.importFromJson(setlist), throwsA(isA<FormatException>()));
    final songsLeft = await db2.getAllSongs();
    expect(songsLeft.length, 1, reason: 'knihovna nesmí být smazána');
    expect((await db2.getAllPlaylists()).length, 1);
  });

  // ------------------------------------------------------------------ T-13G
  test('T-13G: Round-trip známých polí (tempo, scrollSpeed, fontSize, introDuration, duration, stopMarks)', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final songId = (await seedSongs(db, [
      ['Interpret A', 'Píseň A'],
    ])).single;
    // Zdílené zarážky skladby (stav po B3 – per skladbu).
    await db.into(db.stopMarks).insert(StopMarksCompanion.insert(
        songId: songId, positionRatio: 0.5, durationBars: 4));

    final file = v5File(
      name: 'Round trip',
      uid: '12345678-1234-4234-8345-123456789012',
      songs: [
        {
          'occurrenceId': 'aaaabbbb-1111-4222-8333-cccccccccccc',
          'title': 'Píseň A',
          'artist': 'Interpret A',
          'duration': 210,
          'tempo': 105.0,
          'scrollSpeed': 1.5,
          'fontSize': 24.0,
          'introDuration': 3.0,
          'stopMarks': [
            {'lineText': 'nějaký řádek', 'lineIndex': 2, 'bars': 4},
          ],
        },
      ],
    );
    final result = await db.syncPlaylistFromJson(file);
    expect(result.matchedCount, 1);
    expect(result.droppedExtrasKeys, isEmpty);

    final plId = (await db.getAllPlaylists()).single.id;
    final exported = await db.exportPlaylistToJson(plId);
    final entry = (exported['songs'] as List).single as Map<String, dynamic>;

    expect(entry['duration'], 210);
    expect(entry['tempo'], 105.0);
    expect(entry['scrollSpeed'], 1.5);
    expect(entry['fontSize'], 24.0);
    expect(entry['introDuration'], 3.0);
    expect(entry['stopMarks'], isA<List>());
    expect((entry['stopMarks'] as List), isNotEmpty);
    // Per-výskytové hodnoty jsou uloženy i na úrovni výskytu.
    final items = await db.getPlaylistSongsWithTempo(plId);
    expect(items.single.scrollSpeed, 1.5);
    expect(items.single.introDuration, 3.0);
  });

  // ------------------------------------------------------------------ T-13H
  test('T-13H: Nejednoznačné párování – shodný název s jiným interpretem se nespáruje', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final songId = (await seedSongs(db, [
      ['Interpret X', 'Společný název'],
    ])).single;
    await (db.update(db.songs)..where((t) => t.id.equals(songId)))
        .write(const SongsCompanion(duration: Value(555)));

    final file = v5File(
      name: 'Nejednoznačné',
      uid: '87654321-4321-4432-8543-210987654321',
      songs: [
        {
          'occurrenceId': 'dddddddd-1111-4222-8333-eeeeeeeeeeee',
          'title': 'Společný název',
          'artist': 'Interpret Y',
          'duration': 300,
        },
      ],
    );
    final result = await db.syncPlaylistFromJson(file);
    expect(result.matchedCount, 0);
    expect(result.notFound, ['Interpret Y - Společný název']);

    // Píseň Interpret X zůstala beze změny (žádný potichu přepsaný přepis).
    final x = await (db.select(db.songs)..where((t) => t.id.equals(songId)))
        .getSingle();
    expect(x.duration, 555);
  });

  // ------------------------------------------------------------------ extras
  test('Extras: neznámá pole jsou hlášena, neukládána potichu (sekce 7)', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    await seedSongs(db, [
      ['Interpret A', 'Píseň A'],
    ]);

    final file = v5File(
      name: 'S extras',
      uid: 'abababab-1234-4567-89ab-abababababab',
      extraTop: {
        'ttsEngine': 'edge',
        'ttsVoice': 'cz-CZ-A',
        'mojePole': 42,
      },
      songs: [
        {
          'occurrenceId': '1111aaaa-2222-4333-8444-555566667777',
          'title': 'Píseň A',
          'artist': 'Interpret A',
          'duration': 100,
          'extras': {'barva': 'modrá'},
        },
      ],
    );
    final result = await db.syncPlaylistFromJson(file);

    // Schéma v13 extras neumí uložit → nesmí to být potichu; výsledek hlásí.
    expect(result.droppedExtrasKeys,
        containsAll(['ttsEngine', 'ttsVoice', 'mojePole', 'barva']));

    // Round-trip: export extras neobsahuje (app je nevytváří ani neukládá).
    final plId = (await db.getAllPlaylists()).single.id;
    final exported = await db.exportPlaylistToJson(plId);
    expect(exported.containsKey('ttsEngine'), isFalse);
    expect((exported['songs'] as List).single, isNot(contains('extras')));
  });

  // --------------------------------------------------- duplicitní occurrenceId
  test('Duplicitní occurrenceId v souboru = FormatException, data nedotčena', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    await seedSongs(db, [
      ['Interpret A', 'Píseň A'],
      ['Interpret B', 'Píseň B'],
    ]);

    final file = v5File(
      name: 'Duplicita',
      uid: '77777777-6666-4555-8444-333333333333',
      songs: [
        {
          'occurrenceId': 'same-occurrence-0000-4000-8000-000000000000',
          'title': 'Píseň A',
          'artist': 'Interpret A',
          'duration': 100,
        },
        {
          'occurrenceId': 'same-occurrence-0000-4000-8000-000000000000',
          'title': 'Píseň B',
          'artist': 'Interpret B',
          'duration': 200,
        },
      ],
    );
    await expectLater(db.syncPlaylistFromJson(file), throwsA(isA<FormatException>()));
    expect(await db.getAllPlaylists(), isEmpty,
        reason: 'žádná data se nesmí zapsat před chybou');
  });
}
