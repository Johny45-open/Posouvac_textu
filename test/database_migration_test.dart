// Regresní testy migrace databáze v12 → v13 (etapa A1.2).
//
// Fixture je souborová databáze vytvořená ze SKUTEČNÉHO DDL schématu v12
// (odečteno z sqlite_master před změnou schématu, výchozí stav commitu
// 238e73a) a označená PRAGMA user_version = 12. Před každým otevřením se
// navíc ověřuje, že fixture skutečně v12 je (jinak test selže). Každý test
// tak spouští produkční AppDatabase.migration (onUpgrade 12→13), nikoli
// ručně napodobený výsledek.
//
// Používají se výhradně testovací data v dočasném adresáři, nikdy
// uživatelská databáze.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:posouvac_textu/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// UUID verze 4 v tvaru Python `str(uuid.uuid4())` (formát PC editoru).
final RegExp _uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

/// DDL skutečného schématu v12 – převzato beze změny z výpisu
/// `SELECT type, name, sql FROM sqlite_master` nad databází vytvořenou
/// produkčním onCreate před úpravou schématu (etapa A1.2, v12).
const List<String> _v12Ddl = [
  'CREATE TABLE "songs" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"file_path" TEXT NOT NULL UNIQUE, "artist" TEXT NOT NULL, "title" TEXT NOT NULL, '
      '"tempo" REAL NULL, "intro_duration" REAL NULL, '
      '"is_favorite" INTEGER NOT NULL DEFAULT 0 CHECK ("is_favorite" IN (0, 1)), '
      '"is_played" INTEGER NOT NULL DEFAULT 0 CHECK ("is_played" IN (0, 1)), '
      '"custom_font_size" REAL NULL, "custom_scroll_speed" REAL NULL, '
      '"duration" INTEGER NULL)',
  'CREATE TABLE "playlists" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"name" TEXT NOT NULL)',
  'CREATE TABLE "playlist_songs" ("playlist_id" INTEGER NOT NULL '
      'REFERENCES playlists (id) ON DELETE CASCADE, "song_id" INTEGER NOT NULL '
      'REFERENCES songs (id) ON DELETE CASCADE, "order_index" INTEGER NOT NULL '
      'DEFAULT 0, "tempo" REAL NULL, PRIMARY KEY ("playlist_id", "song_id"))',
  'CREATE TABLE "stop_marks" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"song_id" INTEGER NOT NULL REFERENCES songs (id) ON DELETE CASCADE, '
      '"position_ratio" REAL NOT NULL, "duration_bars" INTEGER NOT NULL, '
      '"line_index" INTEGER NULL, "line_text" TEXT NULL)',
  'CREATE TABLE "custom_strings" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, '
      'PRIMARY KEY ("key"))',
  'CREATE TABLE "diacritic_mappings" ("norm_key" TEXT NOT NULL, '
      '"corrected" TEXT NOT NULL, PRIMARY KEY ("norm_key"))',
];

const List<String> _allTables = [
  'songs',
  'playlists',
  'playlist_songs',
  'stop_marks',
  'custom_strings',
  'diacritic_mappings',
];

/// Snímek stavu fixture – čte se přes raw SQLite (před i po migraci stejným
/// způsobem, aby porovnání nebylo ovlivněno drift API).
class _Snapshot {
  final Map<String, int> counts;
  final List<Map<String, Object?>> playlists;
  final List<Map<String, Object?>> items;
  final List<Map<String, Object?>> marks;
  final List<Map<String, Object?>> customStrings;

  _Snapshot({
    required this.counts,
    required this.playlists,
    required this.items,
    required this.marks,
    required this.customStrings,
  });
}

Map<String, Object?> _rowToMap(sqlite.Row r) =>
    {for (final name in r.keys) name: r[name]};

Future<List<Map<String, Object?>>> _query(
    sqlite.Database db, String sql) async =>
    db.select(sql).map(_rowToMap).toList();

Future<_Snapshot> _snapshot(File file) async {
  final db = sqlite.sqlite3.open(file.path);
  try {
    final counts = <String, int>{};
    for (final table in _allTables) {
      counts[table] =
          db.select('SELECT COUNT(*) AS c FROM "$table"').first['c'] as int;
    }
    return _Snapshot(
      counts: counts,
      playlists: await _query(db, 'SELECT id, name FROM playlists ORDER BY id'),
      items: await _query(
          db,
          'SELECT playlist_id, song_id, order_index, tempo '
          'FROM playlist_songs ORDER BY playlist_id, song_id'),
      marks: await _query(
          db,
          'SELECT id, song_id, position_ratio, duration_bars, line_index, line_text '
          'FROM stop_marks ORDER BY id'),
      customStrings:
          await _query(db, 'SELECT key, value FROM custom_strings ORDER BY key'),
    );
  } finally {
    db.close();
  }
}

/// Ověří, že fixture JE skutečná databáze v12 (nikoli v13 převlečená za v12).
void _assertRealV12Fixture(sqlite.Database db) {
  final uv = db.select('PRAGMA user_version').first['user_version'] as int;
  expect(uv, 12,
      reason: 'Fixture musí mít skutečnou verzi schématu 12.');

  final plSql = db
      .select("SELECT sql FROM sqlite_master WHERE name = 'playlists'")
      .first['sql'] as String;
  expect(plSql, isNot(contains('playlist_uid')));
  expect(
      db.select("PRAGMA table_info('playlists')").map((r) => r['name']).toList(),
      ['id', 'name']);

  final psSql = db
      .select("SELECT sql FROM sqlite_master WHERE name = 'playlist_songs'")
      .first['sql'] as String;
  expect(psSql, contains('PRIMARY KEY ("playlist_id", "song_id")'),
      reason: 'v12 musí mít kompozitní primární klíč.');
  expect(psSql, isNot(contains('occurrence_id')));
  expect(
      db
          .select("PRAGMA table_info('playlist_songs')")
          .map((r) => r['name'])
          .toList(),
      ['playlist_id', 'song_id', 'order_index', 'tempo']);

  expect(
      db
          .select("PRAGMA table_info('stop_marks')")
          .map((r) => r['name'])
          .toList(),
      isNot(contains('playlist_song_id')));
  expect(db.select('PRAGMA foreign_key_check').length, 0,
      reason: 'Fixture musí být referenčně konzistentní.');
}

/// Vytvoří souborový fixture: skutečné schéma v12 + reprezentativní data
/// (4 písně, 3 setlisty, 8 položek vč. mezer v pořadí a různých temp,
/// 4 zarážky s i bez kotev, 1 vlastní řetězec).
Future<File> _createV12Fixture(Directory dir) async {
  final file = File(p.join(dir.path, 'fixture_v12.sqlite'));
  final db = sqlite.sqlite3.open(file.path);
  try {
    for (final ddl in _v12Ddl) {
      db.execute(ddl);
    }

    final song = db.prepare(
        'INSERT INTO songs (id, file_path, artist, title, tempo, intro_duration, '
        'is_favorite, is_played, custom_font_size, custom_scroll_speed, duration) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    song.execute([1, '/tmp/a.txt', 'Interpret A', 'Píseň jedna', 120.0, 8.5, 1, 0, 22.0, 1.2, 210]);
    song.execute([2, '/tmp/b.txt', 'Interpret B', 'Píseň dva', null, null, 0, 1, null, null, null]);
    song.execute([3, '/tmp/c.txt', 'Interpret C', 'Píseň tři', 95.5, null, 0, 0, null, 1.0, 180]);
    song.execute([4, '/tmp/d.txt', 'Interpret D', 'Píseň čtyři', 140.0, 12.0, 1, 1, 30.0, null, 240]);
    song.close();

    final playlist = db.prepare('INSERT INTO playlists (id, name) VALUES (?, ?)');
    playlist.execute([1, 'Koncert A']);
    playlist.execute([2, 'Koncert B']);
    playlist.execute([3, 'Zkouška']);
    playlist.close();

    // Položky: mezera v orderIndex (1,2,5) i různá/null tempa.
    final ps = db.prepare(
        'INSERT INTO playlist_songs (playlist_id, song_id, order_index, tempo) '
        'VALUES (?, ?, ?, ?)');
    ps.execute([1, 1, 0, 128.0]);
    ps.execute([1, 2, 1, null]);
    ps.execute([1, 3, 5, 100.5]);
    ps.execute([2, 1, 0, null]);
    ps.execute([2, 4, 1, 133.0]);
    ps.execute([3, 2, 0, 90.0]);
    ps.execute([3, 3, 1, null]);
    ps.execute([3, 4, 2, null]);
    ps.close();

    // Zarážky: bez kotevního řádku i s kotvou (lineIndex + lineText).
    final sm = db.prepare(
        'INSERT INTO stop_marks (id, song_id, position_ratio, duration_bars, '
        'line_index, line_text) VALUES (?, ?, ?, ?, ?, ?)');
    sm.execute([1, 1, 0.25, 2, null, null]);
    sm.execute([2, 1, 0.0, 4, 3, 'Refrén']);
    sm.execute([3, 3, 0.5, 1, 7, 'Sloka 2']);
    sm.execute([4, 4, 0.75, 3, null, 'Finále']);
    sm.close();

    final cs = db.prepare('INSERT INTO custom_strings (key, value) VALUES (?, ?)');
    cs.execute(['testKey', 'testValue']);
    cs.close();

    db.execute('PRAGMA user_version = 12');
    _assertRealV12Fixture(db);
  } finally {
    db.close();
  }
  return file;
}

class _Fixture {
  final Directory dir;
  final File file;
  final AppDatabase db;
  final _Snapshot before;

  _Fixture(this.dir, this.file, this.db, this.before);

  Future<void> closeDb() => db.close();

  Future<void> cleanup() async {
    try {
      await db.close();
    } catch (_) {}
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}

/// Vytvoří fixture v12, ověří její původní stav a otevře ji produkční
/// AppDatabase (tím se spustí reálná migrace onUpgrade 12→13).
Future<_Fixture> _prepare() async {
  final dir = await Directory.systemTemp.createTemp('posouvac_a12_');
  final file = await _createV12Fixture(dir);
  final before = await _snapshot(file);
  final db = AppDatabase.forExecutor(NativeDatabase(file));
  await db.customSelect('SELECT 1 AS x').get(); // spustí migraci
  final fixture = _Fixture(dir, file, db, before);
  addTearDown(fixture.cleanup);
  return fixture;
}

/// Otevře raw spojení na soubor pro kontroly mimo drift.
sqlite.Database _openRaw(File file) => sqlite.sqlite3.open(file.path);

void main() {
  tearDown(() {
    // Havarijní hák musí být po každém testu vynulován.
    AppDatabase.testMigrationFault = null;
  });

  group('T-12A — základní migrace', () {
    test('všechny setlisty, položky, zarážky i řetězce přežijí migraci', () async {
      final f = await _prepare();

      // Fixture měla obsahovat alespoň 3 setlisty a několik položek.
      expect(f.before.counts['playlists'], greaterThanOrEqualTo(3));
      expect(f.before.counts['playlist_songs'], greaterThanOrEqualTo(3));
      expect(f.before.counts['songs'], 4);
      expect(f.before.counts['stop_marks'], 4);

      await f.closeDb();
      final after = await _snapshot(f.file);

      expect(after.counts, f.before.counts,
          reason: 'Počty všech řádků se po migraci nesmí změnit.');
      expect(after.playlists, f.before.playlists,
          reason: 'Setlisty (id i názvy) musí zůstat stejné.');
      expect(after.items, f.before.items,
          reason: 'Všechny položky setlistů musí zůstat stejné.');
      expect(after.marks, f.before.marks,
          reason: 'Všechny zarážky musí zůstat stejné.');
      expect(after.customStrings, f.before.customStrings);
    });
  });

  group('T-12B — přenosová identita', () {
    test('každý setlist má neprázdné jedinečné playlistUid', () async {
      final f = await _prepare();
      await f.closeDb();

      final raw = _openRaw(f.file);
      try {
        final uids = raw
            .select('SELECT playlist_uid FROM playlists')
            .map((r) => r.columnAt(0) as String)
            .toList();
        expect(uids.length, f.before.counts['playlists']);
        for (final uid in uids) {
          expect(uid, matches(_uuidV4),
              reason: 'playlistUid musí být neprázdné UUID v4.');
        }
        expect(uids.toSet().length, uids.length,
            reason: 'playlistUid musí být unikátní.');
      } finally {
        raw.close();
      }
    });

    test('každý výskyt má neprázdné jedinečné occurrenceId', () async {
      final f = await _prepare();
      await f.closeDb();

      final raw = _openRaw(f.file);
      try {
        final occs = raw
            .select('SELECT occurrence_id FROM playlist_songs')
            .map((r) => r.columnAt(0) as String)
            .toList();
        expect(occs.length, f.before.counts['playlist_songs']);
        for (final occ in occs) {
          expect(occ, matches(_uuidV4),
              reason: 'occurrenceId musí být neprázdné UUID v4.');
        }
        expect(occs.toSet().length, occs.length,
            reason: 'occurrenceId musí být unikátní.');
      } finally {
        raw.close();
      }
    });
  });

  group('T-12C — pořadí a tempo', () {
    test('všechny položky zachovají orderIndex i tempo', () async {
      final f = await _prepare();
      await f.closeDb();
      final after = await _snapshot(f.file);

      expect(after.items, f.before.items,
          reason: 'Dvojice (playlistId, songId) musí mít stejné pořadí i tempo.');
      // Konkrétní známé hodnoty fixture – tempo 128.0 u (1,1), null u (1,2).
      final first = after.items.first;
      expect(first['tempo'], 128.0);
      expect(first['order_index'], 0);
    });
  });

  group('T-12D — zarážky', () {
    test('zachovají všechna pole a mají playlistSongId = NULL', () async {
      final f = await _prepare();
      await f.closeDb();
      final after = await _snapshot(f.file);

      // Původní pole beze změny (pole playlist_song_id se do porovnání
      // záměrně nebere – před migrací neexistuje).
      expect(after.marks, f.before.marks);

      final raw = _openRaw(f.file);
      try {
        final withLink = raw
            .select(
                'SELECT COUNT(*) AS c FROM stop_marks WHERE playlist_song_id IS NOT NULL')
            .first['c'] as int;
        expect(withLink, 0,
            reason: 'Všechny původní zarážky musí zůstat sdílené (NULL).');
        final sql = raw
            .select("SELECT sql FROM sqlite_master WHERE name = 'stop_marks'")
            .first['sql'] as String;
        expect(sql, contains('playlist_song_id'));
        expect(sql, contains('ON DELETE CASCADE'));
      } finally {
        raw.close();
      }
    });
  });

  group('T-12E — výchozí nastavení výskytů', () {
    test('nová pole jsou NULL (zděděný stav), ne vymyšlené hodnoty', () async {
      final f = await _prepare();
      await f.closeDb();

      final raw = _openRaw(f.file);
      try {
        final rows = raw.select(
            'SELECT scroll_speed, intro_duration, stop_marks_override '
            'FROM playlist_songs');
        expect(rows.length, f.before.counts['playlist_songs']);
        for (final row in rows) {
          expect(row.columnAt(0), isNull, reason: 'scrollSpeed musí být NULL.');
          expect(row.columnAt(1), isNull,
              reason: 'introDuration musí být NULL.');
          expect(row.columnAt(2), isNull,
              reason: 'stopMarksOverride musí být NULL = zděděné zarážky.');
        }
      } finally {
        raw.close();
      }
    });
  });

  group('T-12F — cizí klíče a integrita', () {
    test('integrity_check, foreign_key_check i vynucení FK po migraci', () async {
      final f = await _prepare();
      await f.closeDb();

      final raw = _openRaw(f.file);
      try {
        // Integrita a platnost cizích klíčů (ne jen „otevřelo se to").
        expect(raw.select('PRAGMA integrity_check').first.columnAt(0), 'ok');
        expect(raw.select('PRAGMA foreign_key_check'), isEmpty);

        // Vynucení cizích klíčů (se zapnutým foreign_keys):
        raw.execute('PRAGMA foreign_keys = ON');
        expect(
            () => raw.execute(
                "INSERT INTO playlist_songs (occurrence_id, playlist_id, song_id) "
                "VALUES ('bad-foreign-key', 999, 1)"),
            throwsA(anything),
            reason: 'FK na playlist musí odmítnout neexistující rodič.');

        // Kaskádní akce: výskyt i jeho výskytová zarážka mizí s setlistem,
        // sdílené zarážky skladby zůstávají.
        raw.execute(
            "INSERT INTO playlist_songs (occurrence_id, playlist_id, song_id, order_index) "
            "VALUES ('t12f-occurrence', 1, 1, 99)");
        final psId = raw
            .select(
                "SELECT id FROM playlist_songs WHERE occurrence_id = 't12f-occurrence'")
            .first
            .columnAt(0) as int;
        raw.execute(
            'INSERT INTO stop_marks (song_id, position_ratio, duration_bars, playlist_song_id) '
            'VALUES (1, 0.1, 2, $psId)');
        raw.execute('DELETE FROM playlists WHERE id = 1');
        expect(
            raw
                .select(
                    "SELECT COUNT(*) FROM playlist_songs WHERE occurrence_id = 't12f-occurrence'")
                .first
                .columnAt(0),
            0,
            reason: 'Smazání setlistu musí kaskádou smazat jeho výskyty.');
        expect(
            raw
                .select('SELECT COUNT(*) FROM stop_marks WHERE playlist_song_id = $psId')
                .first
                .columnAt(0),
            0,
            reason: 'Smazání výskytu musí kaskádou smazat jeho zarážky.');
        expect(
            raw.select('SELECT COUNT(*) FROM stop_marks').first.columnAt(0),
            4,
            reason: 'Sdílené zarážky nesmí být dotčeny.');
      } finally {
        raw.close();
      }
    });

    test('schéma migrované databáze odpovídá čerstvé definici Drift v13', () async {
      final f = await _prepare();

      // Čerstvá v13 (in-memory) – stejné tabulkové třídy jako produkce.
      final fresh = AppDatabase.forTesting();
      addTearDown(fresh.close);
      await fresh.customSelect('SELECT 1 AS x').get();

      Future<String> columns(AppDatabase db, String table) async {
        final rows = await db.customSelect('PRAGMA table_info("$table")').get();
        final items = rows
            .map((r) => '${r.data['name']}|${r.data['type']}|${r.data['notnull']}|'
                '${r.data['dflt_value']}|${r.data['pk']}')
            .toList()
          ..sort();
        return items.join('\n');
      }

      Future<String> indexes(AppDatabase db, String table) async {
        final idxRows =
            await db.customSelect('PRAGMA index_list("$table")').get();
        final out = <String>[];
        for (final idx in idxRows) {
          final name = idx.data['name'] as String;
          final cols =
              await db.customSelect('PRAGMA index_info("$name")').get();
          out.add('${idx.data['unique']}|${idx.data['origin']}|'
              '${idx.data['partial']}|${cols.map((c) => c.data['name']).join(',')}');
        }
        return (out..sort()).join('\n');
      }

      for (final table in _allTables) {
        expect(await columns(f.db, table), await columns(fresh, table),
            reason: 'Sloupce "$table" musí odpovídat definici Driftu.');
        expect(await indexes(f.db, table), await indexes(fresh, table),
            reason: 'Indexy/omezení "$table" musí odpovídat definici Driftu.');
      }

      // Uživatelská verze je po migraci 13.
      final uv = await f.db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(uv.read<int>('user_version'), 13);
    });
  });

  group('T-12G — druhé otevření', () {
    test('migrace se neopakuje a ID se nemění', () async {
      final f = await _prepare();

      Future<List<String>> uids(AppDatabase db) async => (await db
              .customSelect('SELECT playlist_uid FROM playlists ORDER BY id')
              .get())
          .map((r) => r.read<String>('playlist_uid'))
          .toList();
      Future<List<String>> occs(AppDatabase db) async => (await db
              .customSelect('SELECT occurrence_id FROM playlist_songs ORDER BY id')
              .get())
          .map((r) => r.read<String>('occurrence_id'))
          .toList();

      final uidsFirst = await uids(f.db);
      final occsFirst = await occs(f.db);
      final idsFirst = (await f.db.getPlaylistSongIds(3)).join(',');
      await f.closeDb();

      // Druhé otevření téhož souboru:
      final db2 = AppDatabase.forExecutor(NativeDatabase(f.file));
      addTearDown(db2.close);
      await db2.customSelect('SELECT 1 AS x').get(); // nesmí vyhodit

      final uv = await db2.customSelect('PRAGMA user_version').getSingle();
      expect(uv.read<int>('user_version'), 13,
          reason: 'Verze se nesmí změnit opakovaným otevřením.');
      expect(await uids(db2), uidsFirst,
          reason: 'playlistUid se nesmí při druhém otevření měnit.');
      expect(await occs(db2), occsFirst,
          reason: 'occurrenceId se nesmí při druhém otevření měnit.');
      expect((await db2.getPlaylistSongIds(3)).join(','), idsFirst,
          reason: 'Lokální id položek se nesmí měnit.');
    });
  });

  group('T-12H — zachování existujícího chování', () {
    test('čtení a změna tempa u setlistu bez duplicit funguje jako dřív', () async {
      final f = await _prepare();
      final db = f.db;

      // Čtení setlistu v pořadí dle orderIndex (fixture má 0, 1, 5).
      final items = await db.getPlaylistSongsWithTempo(1);
      expect(items.map((e) => e.song.id).toList(), [1, 2, 3]);
      expect(items.map((e) => e.playlistTempo).toList(), [128.0, null, 100.5]);
      // effectiveTempo: vlastní tempo setlistu, jinde zděděné z písně.
      expect(items[0].effectiveTempo, 128.0);
      expect(items[1].effectiveTempo, items[1].song.tempo);

      // Změna tempa dvojicí (playlistId, songId) – jako v přehrávači.
      await db.updatePlaylistSongTempo(1, 1, 140.0);
      expect(await db.getPlaylistSongTempo(1, 1), 140.0);
      final map = await db.getPlaylistTemposMap(1);
      expect(map[1], 140.0);
      // Druhá položka beze změny.
      expect(await db.getPlaylistSongTempo(1, 2), isNull);

      // Opakované přidání téže písně se dál ignoruje (staré insertOrIgnore).
      final countBefore = (await db.getPlaylistSongIds(1)).length;
      final again = await db.addSongToPlaylist(1, 1);
      expect(again, 0);
      expect((await db.getPlaylistSongIds(1)).length, countBefore);

      // Nová píseň jde přidat, dostane occurrenceId, override zůstane NULL.
      await db.addSongToPlaylist(1, 4);
      final rows = await db
          .customSelect('SELECT occurrence_id, stop_marks_override, tempo '
              'FROM playlist_songs WHERE playlist_id = 1 AND song_id = 4')
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.read<String>('occurrence_id'), matches(_uuidV4));
      expect(rows.single.read<bool?>('stop_marks_override'), isNull);
      expect(rows.single.read<double?>('tempo'), isNull);

      // Zrušení přidání funguje jako dřív.
      await db.removeSongFromPlaylist(1, 4);
      expect((await db.getPlaylistSongIds(1)).length, countBefore);

      // Sdílené zarážky skladby čtené přes getStopMarksForSong beze změny.
      final marks = await db.getStopMarksForSong(1);
      expect(marks, hasLength(2));
      expect(marks.map((m) => m.id).toList(), [1, 2]);
    });

    test('duplicitní (playlistId, songId) lze po migraci uložit – základ pro '
        'budoucí etapy, ale nic je automaticky nevytváří', () async {
      final f = await _prepare();
      // Migrace nesmí přidat žádné duplicity:
      final dupRows = await f.db.customSelect(
          'SELECT playlist_id, song_id, COUNT(*) AS c FROM playlist_songs '
          'GROUP BY playlist_id, song_id HAVING c > 1')
          .get();
      expect(dupRows, isEmpty,
          reason: 'Migrace nesmí vytvářet opakované výskyty.');

      // Schéma však stejnou dvojici POVOLOVAT musí (žádné unikátní omezení).
      await f.closeDb();
      final raw = _openRaw(f.file);
      try {
        raw.execute(
            "INSERT INTO playlist_songs (occurrence_id, playlist_id, song_id, order_index) "
            "VALUES ('dup-occ-1', 3, 2, 50)");
        raw.execute(
            "INSERT INTO playlist_songs (occurrence_id, playlist_id, song_id, order_index) "
            "VALUES ('dup-occ-2', 3, 2, 51)");
        expect(
            raw
                .select('SELECT COUNT(*) FROM playlist_songs WHERE playlist_id = 3 '
                    'AND song_id = 2')
                .first
                .columnAt(0),
            3,
            reason: 'Stejná dvojice (playlistId, songId) musí být uložitelná '
                'dvakrát – unikátní omezení nesmí existovat.');
      } finally {
        raw.close();
      }
    });
  });

  group('T-12I — selhání migrace', () {
    test('selhání uprostřed přestavby = rollback do konzistentního v12', () async {
      final dir = await Directory.systemTemp.createTemp('posouvac_a12_fail_');
      final file = await _createV12Fixture(dir);
      final before = await _snapshot(file);
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });

      // Havarijní hák: hodí chybu až PO přestavbě playlists,
      // tj. uvnitř transakce uprostřed migrace.
      AppDatabase.testMigrationFault = (phase) async {
        if (phase == 'playlistSongs:beforeCopy') {
          throw StateError('T-12I: simulované selhání uprostřed přestavby');
        }
      };

      final db = AppDatabase.forExecutor(NativeDatabase(file));
      await expectLater(
        db.customSelect('SELECT 1 AS x').get(),
        throwsA(isA<StateError>()),
        reason: 'Selhání migrace se musí propojit k volajícímu.',
      );
      AppDatabase.testMigrationFault = null;
      await db.close();

      // --- Rollback: databáze musí být stále konzistentní v12 ---
      final raw = _openRaw(file);
      try {
        expect(raw.select('PRAGMA user_version').first.columnAt(0), 12,
            reason: 'user_version se nesmí při selhání změnit.');
        expect(raw.select('PRAGMA integrity_check').first.columnAt(0), 'ok');
        expect(raw.select('PRAGMA foreign_key_check'), isEmpty);

        final psSql = raw
            .select("SELECT sql FROM sqlite_master WHERE name = 'playlist_songs'")
            .first['sql'] as String;
        expect(psSql, contains('PRIMARY KEY ("playlist_id", "song_id")'),
            reason: 'playlist_songs musí po rollbacku zůstat ve tvaru v12.');
        expect(psSql, isNot(contains('occurrence_id')));

        final plSql = raw
            .select("SELECT sql FROM sqlite_master WHERE name = 'playlists'")
            .first['sql'] as String;
        expect(plSql, isNot(contains('playlist_uid')),
            reason: 'Přestavba playlists se musí vrátit celá.');

        final after = await _snapshot(file);
        expect(after.counts, before.counts);
        expect(after.playlists, before.playlists);
        expect(after.items, before.items);
        expect(after.marks, before.marks);
      } finally {
        raw.close();
      }

      // --- Druhý průchod (bez havárie) migraci dokončí ---
      final db2 = AppDatabase.forExecutor(NativeDatabase(file));
      addTearDown(db2.close);
      await db2.customSelect('SELECT 1 AS x').get();

      final uv = await db2.customSelect('PRAGMA user_version').getSingle();
      expect(uv.read<int>('user_version'), 13);
      await db2.close();

      final raw2 = _openRaw(file);
      try {
        expect(raw2.select('PRAGMA integrity_check').first.columnAt(0), 'ok');
        expect(raw2.select('PRAGMA foreign_key_check'), isEmpty);
        final after = await _snapshot(file);
        expect(after.counts, before.counts,
            reason: 'Dokončená migrace musí zachovat všechna data.');
        expect(after.items, before.items);
        expect(after.marks, before.marks);
        final occs = raw2
            .select('SELECT occurrence_id FROM playlist_songs')
            .map((r) => r.columnAt(0) as String)
            .toList();
        expect(occs.toSet().length, occs.length);
        expect(occs.every((o) => _uuidV4.hasMatch(o)), isTrue);
      } finally {
        raw2.close();
      }
    });
  });

  group('Vynucení identity ve schématu', () {
    test('uid/occurrenceId: neprázdné a unikátní; id je PK; žádné UNIQUE '
        '(playlist_id, song_id)', () async {
      final f = await _prepare();
      await f.closeDb();

      final raw = _openRaw(f.file);
      try {
        final existingUid =
            raw.select('SELECT playlist_uid FROM playlists').first.columnAt(0);
        final existingOcc = raw
            .select('SELECT occurrence_id FROM playlist_songs')
            .first
            .columnAt(0);

        // playlist_uid: prázdný zakázán, duplicitní zakázána.
        expect(
            () => raw.execute(
                "INSERT INTO playlists (name, playlist_uid) VALUES ('X', '')"),
            throwsA(anything));
        expect(
            () => raw.execute(
                "INSERT INTO playlists (name, playlist_uid) VALUES ('X', '$existingUid')"),
            throwsA(anything));

        // occurrence_id: prázdné zakázáno, duplicitní zakázáno.
        expect(
            () => raw.execute(
                "INSERT INTO playlist_songs (occurrence_id, playlist_id, song_id) "
                "VALUES ('', 3, 2)"),
            throwsA(anything));
        expect(
            () => raw.execute(
                "INSERT INTO playlist_songs (occurrence_id, playlist_id, song_id) "
                "VALUES ('$existingOcc', 3, 2)"),
            throwsA(anything));

        // Lokální primární klíč id je unikátní.
        final firstId =
            raw.select('SELECT id FROM playlist_songs').first.columnAt(0);
        expect(
            () => raw.execute(
                "INSERT INTO playlist_songs (id, occurrence_id, playlist_id, song_id) "
                "VALUES ($firstId, 'some-other-occ', 3, 2)"),
            throwsA(anything));

        // Ale stejná dvojice (playlist_id, song_id) JE povolena dvakrát:
        raw.execute(
            "INSERT INTO playlist_songs (occurrence_id, playlist_id, song_id, order_index) "
            "VALUES ('perm-occ-1', 3, 2, 60)");
        raw.execute(
            "INSERT INTO playlist_songs (occurrence_id, playlist_id, song_id, order_index) "
            "VALUES ('perm-occ-2', 3, 2, 61)");
        expect(
            raw
                .select('SELECT COUNT(*) FROM playlist_songs WHERE playlist_id = 3 '
                    'AND song_id = 2')
                .first
                .columnAt(0),
            3);
      } finally {
        raw.close();
      }
    });
  });

  group('Kompatibilita záloh', () {
    test('importFromJson zvládne starou zálohu v12 bez uid/occurrenceId', () async {
      final f = await _prepare();

      await f.db.importFromJson({
        'version': 12,
        'songs': [
          {
            'id': 1,
            'filePath': '/tmp/old.txt',
            'artist': 'Starý interpret',
            'title': 'Stará píseň',
            'tempo': null,
            'introDuration': null,
            'isFavorite': false,
            'isPlayed': false,
            'customFontSize': null,
            'customScrollSpeed': null,
            'duration': null,
          },
        ],
        // Starý tvar zálohy: bez playlistUid.
        'playlists': [
          {'id': 10, 'name': 'Stará záloha'},
        ],
        'stopMarks': [],
        // Starý tvar zálohy: bez id i occurrenceId.
        'playlistSongs': [
          {'playlistId': 10, 'songId': 1, 'orderIndex': 0, 'tempo': 100.0},
        ],
        'diacriticMappings': [],
        'customStrings': [],
      });

      final pl = await f.db
          .customSelect('SELECT id, name, playlist_uid FROM playlists')
          .get();
      expect(pl, hasLength(1));
      expect(pl.single.read<String>('name'), 'Stará záloha');
      expect(pl.single.read<String>('playlist_uid'), matches(_uuidV4),
          reason: 'Obnova staré zálohy musí doplnit chybějící playlistUid.');

      final ps = await f.db.customSelect(
          'SELECT playlist_id, song_id, order_index, tempo, occurrence_id, '
          'stop_marks_override FROM playlist_songs')
          .get();
      expect(ps, hasLength(1));
      expect(ps.single.read<int>('playlist_id'), 10);
      expect(ps.single.read<int>('order_index'), 0);
      expect(ps.single.read<double?>('tempo'), 100.0);
      expect(ps.single.read<String>('occurrence_id'), matches(_uuidV4),
          reason: 'Obnova staré zálohy musí doplnit occurrenceId.');
      expect(ps.single.read<bool?>('stop_marks_override'), isNull);
    });
  });
}
