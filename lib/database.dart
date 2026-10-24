import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'song_entry.dart';
import 'text_normalizer.dart';
import 'package:sqlite3/sqlite3.dart';

part 'database.g.dart';

class DurationFixCandidate {
  final int songId;
  final String title;
  final String artist;
  final int newDuration;
  const DurationFixCandidate({
    required this.songId,
    required this.title,
    required this.artist,
    required this.newDuration,
  });
}

class DiacriticFixCandidate {
  final int songId;
  final String oldTitle;
  final String oldArtist;
  final String newTitle;
  final String newArtist;
  const DiacriticFixCandidate({
    required this.songId,
    required this.oldTitle,
    required this.oldArtist,
    required this.newTitle,
    required this.newArtist,
  });

  // Kompatibilita pro sjednocené API (A): umožní číst i jako current*
  String get currentTitle => oldTitle;
  String get currentArtist => oldArtist;

  DiacriticRepairCandidate toRepair() => DiacriticRepairCandidate(
        songId: songId,
        currentTitle: oldTitle,
        currentArtist: oldArtist,
        newTitle: newTitle,
        newArtist: newArtist,
      );
}

class DiacriticRepairCandidate {
  final int songId;
  final String currentTitle;
  final String currentArtist;
  final String newTitle;
  final String newArtist;
  const DiacriticRepairCandidate({
    required this.songId,
    required this.currentTitle,
    required this.currentArtist,
    required this.newTitle,
    required this.newArtist,
  });

  // Kompatibilita pro kód očekávající DiacriticFixCandidate (B)
  String get oldTitle => currentTitle;
  String get oldArtist => currentArtist;

  DiacriticFixCandidate toFix() => DiacriticFixCandidate(
        songId: songId,
        oldTitle: currentTitle,
        oldArtist: currentArtist,
        newTitle: newTitle,
        newArtist: newArtist,
      );
}

class PlaylistSyncResult {
  final String playlistName;
  final int matchedCount;
  final List<String> notFound;
  final int totalDurationShared;
  final int unknownShared;
  final List<DurationFixCandidate> durationCandidates;
  final List<DiacriticRepairCandidate> diacriticCandidates;

  /// Přenosová identita setlistu po synchronizaci (u souborů v5 převzatá,
  /// u starších souborů vygenerovaná).
  final String? playlistUid;

  /// True, pokud import vytvořil NOVÝ setlist (žádný existující nebyl
  /// přepsán). U starších souborů bez identit je true vždy – setlist
  /// stejného názvu se totiž nepřepisuje potichu.
  final bool createdNewPlaylist;

  /// Klíče neznámých polí ze souboru, která aplikace v tomto schématu
  /// NEUMÍ uložit (v13 nemá extras) a byla tedy při importu vynechána.
  /// Nejde o tiché zahození – výsledek to hlásí; úplné uložení extras
  /// vyžaduje samostatně schválenou migraci (viz A1.3, sekce 7).
  final List<String> droppedExtrasKeys;

  PlaylistSyncResult({
    required this.playlistName,
    required this.matchedCount,
    required this.notFound,
    this.totalDurationShared = 0,
    this.unknownShared = 0,
    this.durationCandidates = const [],
    this.diacriticCandidates = const [],
    this.playlistUid,
    this.createdNewPlaylist = false,
    this.droppedExtrasKeys = const [],
  });
}

/// Výsledek hromadného importu metadat z CSV.
class CsvImportResult {
  final int updated;
  final int skipped;

  const CsvImportResult({required this.updated, required this.skipped});
}

/// Výsledek importu slovníku diakritiky.
class DiacriticCsvImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;

  const DiacriticCsvImportResult({required this.imported, required this.skipped, this.errors = const []});
}

/// Výsledek hromadné opravy diakritiky včetně volitelného přejmenování souborů.
class DiacriticRepairResult {
  final int dbUpdated;
  final int filesRenamed;
  final int filesFailed;
  final List<String> failedPaths;

  const DiacriticRepairResult({
    required this.dbUpdated,
    this.filesRenamed = 0,
    this.filesFailed = 0,
    this.failedPaths = const [],
  });
}

/// Záznam písně bez návrhu opravy s důvodem (pro výpis 23→21).
class DiacriticUnrepairedEntry {
  final SongEntry song;
  final String reason; // alreadyCorrect, missingInMap, compositeNoMatch
  final String normTitle;
  final String normArtist;
  const DiacriticUnrepairedEntry({
    required this.song,
    required this.reason,
    required this.normTitle,
    required this.normArtist,
  });
}

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Přenosová identita setlistu (UUID v4).
  /// Unikátnost i neprázdnost vynucuje SQL (UNIQUE + CHECK), ne jen kód –
  /// viz schéma v13 (etapa A1.2).
  TextColumn get playlistUid =>
      text()
          .unique()
          .check(playlistUid.length.isBiggerThan(const Constant(0)))();
}

class PlaylistSongs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Stabilní přenosový identifikátor výskytu (UUID v4).
  /// Unikátnost i neprázdnost vynucuje SQL (UNIQUE + CHECK).
  TextColumn get occurrenceId =>
      text()
          .unique()
          .check(occurrenceId.length.isBiggerThan(const Constant(0)))();

  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get songId =>
      integer().references(Songs, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  RealColumn get tempo => real().nullable()(); // Tempo specifické pro setlist (BPM), null = globální z Songs.tempo

  /// Per-výskytové rychlosti posuvu (null = zděděné ze skladby/globální).
  RealColumn get scrollSpeed => real().nullable()();

  /// Per-výskytová délka úvodu v sekundách (null = zděděné ze skladby).
  RealColumn get introDuration => real().nullable()();

  /// Tri-stav výskytových zarážek:
  ///  * null  – zarážky zděděné ze skladby (výchozí stav, stav 1),
  ///  * false – pro daný výskyt výslovně žádné zarážky (stav 3),
  ///  * true  – použít vlastní seznam zarážek daného výskytu,
  ///            seznam může být prázdný nebo obsahovat více položek (stav 2).
  /// Samotná absence řádků v stop_marks první a třetí stav nerozlišuje.
  BoolColumn get stopMarksOverride => boolean().nullable()();
}

/// Odkaz na konkrétní výskyt písně v setlistu (etapa E1).
class PlaylistOccurrenceRef {
  final int playlistSongId;
  final int songId;
  final String occurrenceId;

  const PlaylistOccurrenceRef({
    required this.playlistSongId,
    required this.songId,
    required this.occurrenceId,
  });
}

/// Obálka písně v setlistu včetně per-setlist tempa.
class PlaylistSongWithTempo {
  final int playlistSongId;
  final SongEntry song;
  final double? playlistTempo;
  final int orderIndex;

  /// Přenosová identita výskytu (UUID v4, etapa A1.2/A1.3).
  /// Při přesunu položky ani změně jejího nastavení se nemění.
  final String occurrenceId;

  /// Per-výskytové rychlosti posuvu (null = zděděné ze skladby/globální).
  final double? scrollSpeed;

  /// Per-výskytová délka úvodu v sekundách (null = zděděné ze skladby).
  final double? introDuration;

  /// Tri-stav výskytových zarážek (null = zděděné ze skladby).
  final bool? stopMarksOverride;

  const PlaylistSongWithTempo({
    required this.playlistSongId,
    required this.song,
    this.playlistTempo,
    required this.orderIndex,
    required this.occurrenceId,
    this.scrollSpeed,
    this.introDuration,
    this.stopMarksOverride,
  });

  double? get effectiveTempo => playlistTempo ?? song.tempo;
}

class StopMarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get songId => integer().references(Songs, #id, onDelete: KeyAction.cascade)();
  RealColumn get positionRatio => real()(); // Procentuální pozice (0.0 - 1.0)
  IntColumn get durationBars => integer()(); // Délka pauzy v taktech
  IntColumn get lineIndex => integer().nullable()(); // Index kotevního řádku textu
  TextColumn get lineText => text().nullable()(); // Text kotevního řádku (pro stabilitu)

  /// Konkrétní výskyt písně v setlistu (etapa A1.2).
  ///  * null  – zarážka patří skladbě a je sdílená všemi výskyty (stav po migraci),
  ///  * != null – zarážka patří konkrétnímu výskytu.
  /// Musí zůstat posledním sloupcem – migrace v13 jej přidává přes ALTER TABLE
  /// ADD COLUMN (na konci) a testy porovnávají schéma s čerstvou definicí Driftu.
  IntColumn get playlistSongId =>
      integer().nullable().references(PlaylistSongs, #id, onDelete: KeyAction.cascade)();
}

class CustomStrings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Songs, Playlists, PlaylistSongs, StopMarks, CustomStrings, DiacriticMappings])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();

  AppDatabase._internal() : super(_openConnection());

  factory AppDatabase() => instance;

  /// Testovací databáze v paměti (bez platformních kanálů).
  factory AppDatabase.forTesting() => AppDatabase._testing();

  AppDatabase._testing() : super(NativeDatabase.memory());

  /// Konstruktor nad konkrétním executorem – používají regresní testy migrace
  /// (souborová testovací databáze se skutečným schématem v12, viz
  /// test/database_migration_test.dart).
  AppDatabase.forExecutor(super.executor);

  /// Testovací hák pro simulaci selhání uvnitř migrační transakce v12→v13.
  ///
  /// V produkci zůstává null a chování migrace neovlivňuje. Regresní test
  /// T-12I jej nastaví, aby ověřil rollback (databáze nesmí zůstat v
  /// nekonzistentním částečném stavu).
  static Future<void> Function(String phase)? testMigrationFault;

  @override
  int get schemaVersion => 13;

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
        if (from < 9) {
          await m.addColumn(stopMarks, stopMarks.lineIndex);
          await m.addColumn(stopMarks, stopMarks.lineText);
        }
        if (from < 10) {
          await m.createTable(diacriticMappings);
        }
        if (from < 11) {
          await m.addColumn(playlistSongs, playlistSongs.tempo);
        }
        if (from < 12) {
          // vyčisti otrávené záznamy typu Mladek->Mladdek, ponech jen čistě diakritiku
          final existing = await customSelect('SELECT norm_key, corrected FROM diacritic_mappings', readsFrom: {diacriticMappings}).get();
          for (final row in existing) {
            final normKey = row.read<String>('norm_key');
            final corrected = row.read<String>('corrected');
            if (_normForMatch(corrected) != normKey) {
              await customStatement('DELETE FROM diacritic_mappings WHERE norm_key = ?', [normKey]);
            }
          }
        }
        if (from < 13) {
          await _migrateV12toV13(m);
        }
      },
      beforeOpen: (details) async {
        // pojistka i bez migrace (např. už verze 12 ale starý poisoned obsah) – tiché vyčištění při každém startu
        if (details.wasCreated) return;
        try {
          final existing = await customSelect('SELECT norm_key, corrected FROM diacritic_mappings', readsFrom: {diacriticMappings}).get();
          for (final row in existing) {
            final normKey = row.read<String>('norm_key');
            final corrected = row.read<String>('corrected');
            if (_normForMatch(corrected) != normKey) {
              await customStatement('DELETE FROM diacritic_mappings WHERE norm_key = ?', [normKey]);
            }
          }
        } catch (_) {}
      },
    );
  }

  // --- MIGRACE v12 → v13 (etapa A1.2) ---

  static final Random _secureRandom = Random.secure();

  /// Vygeneruje UUID verze 4 ve tvaru shodném s Pythonem `str(uuid.uuid4())`
  /// (stejný formát používá i PC editor, etapa A1.1) – malá písmena,
  /// tvar 8-4-4-4-12. Bez nové závislosti, jen `dart:math` Random.secure().
  static String _newUuidV4() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // UUID verze 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC 4122
    String hex(int start, int count) => bytes
        .sublist(start, start + count)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 2)}-${hex(6, 2)}-${hex(8, 2)}-${hex(10, 6)}';
  }

  /// Vygeneruje další jedinečné UUID a ověří před přidáním do sady [seen],
  /// že není prázdné a ještě se v sadě nevyskytuje (obrana proti kolizi).
  static String _freshUniqueUid(Set<String> seen) {
    for (var attempt = 0; attempt < 100; attempt++) {
      final uid = _newUuidV4();
      if (uid.isNotEmpty && seen.add(uid)) return uid;
    }
    throw StateError('Nepodařilo se vygenerovat jedinečné UUID (opakovaná kolize).');
  }

  /// Migrace schématu v12 → v13 (etapa A1.2).
  ///
  /// Postup odpovídá skutečným možnostem SQLite:
  ///  * `playlists` a `playlist_songs` nelze převést běžným ALTER TABLE
  ///    (sloupec s UNIQUE/CHECK bez konstantního defaultu nelze přidat,
  ///    kompozitní primární klíč nelze změnit) → přestavba
  ///    RENAME + CREATE + INSERT...SELECT + DROP;
  ///  * `stop_marks` jen přibývá nullable sloupec → postačí ADD COLUMN.
  ///
  /// Všechny kroky včetně závěrečných validací běží v JEDNÉ transakci:
  /// při selhání (včetně validace) dojde k rollbacku celé přestavby a
  /// databáze zůstane konzistentně ve verzi 12 – drift nastaví
  /// `user_version` až po úspěšném dokončení migrace.
  ///
  /// Cizí klíče jsou na dobu přestavby vypnuté MIMO transakci (PRAGMA
  /// foreign_keys nelze měnit uvnitř transakce) a v `finally` se vrátí
  /// předchozí stav, včetně ověření skutečného stavu načtením ze SQLite.
  Future<void> _migrateV12toV13(Migrator m) async {
    final fkBefore =
        (await customSelect('PRAGMA foreign_keys').getSingle()).read<bool>('foreign_keys');
    if (fkBefore) {
      await customStatement('PRAGMA foreign_keys = OFF');
    }
    try {
      await transaction(() async {
        await _v13RebuildPlaylists(m);
        await _v13RebuildPlaylistSongs(m);
        await _v13AddOccurrenceLinkToStopMarks();
        await _v13VerifyMigrationResult();
      });
    } finally {
      // Obnoví předchozí stav i při výjimce (v této aplikaci je výchozí OFF).
      await customStatement('PRAGMA foreign_keys = ${fkBefore ? 'ON' : 'OFF'}');
      // Ověřit skutečný stav podle SQLite, ne jen podle předpokladu.
      final fkAfter =
          (await customSelect('PRAGMA foreign_keys').getSingle()).read<bool>('foreign_keys');
      if (fkAfter != fkBefore) {
        throw StateError('Nepodařilo se obnovit PRAGMA foreign_keys '
            '(před migrací: $fkBefore, po obnovení: $fkAfter).');
      }
    }
  }

  /// Přestavba `playlists`: přidá stabilní přenosové `playlist_uid`.
  /// Lokální `id` se zachovávají beze změny.
  Future<void> _v13RebuildPlaylists(Migrator m) async {
    await testMigrationFault?.call('playlists:beforeCopy');
    await customStatement('ALTER TABLE playlists RENAME TO playlists_v12_old');
    await m.createTable(playlists);
    final oldRows =
        await customSelect('SELECT id, name FROM playlists_v12_old ORDER BY id').get();
    final seenUids = <String>{};
    for (final row in oldRows) {
      // Každý stávající setlist dostane vlastní nové přenosové ID.
      final uid = _freshUniqueUid(seenUids);
      await into(playlists).insert(PlaylistsCompanion.insert(
            id: Value(row.read<int>('id')),
            name: row.read<String>('name'),
            playlistUid: uid,
          ));
    }
    await customStatement('DROP TABLE playlists_v12_old');
    await testMigrationFault?.call('playlists:done');
  }

  /// Přestavba `playlist_songs`: nový lokální primární klíč `id`,
  /// `occurrence_id` a nová volitelná nastavení. Zachovává všechny řádky,
  /// jejich pořadí (`order_index`) i `tempo`; žádné duplicity se nepřidávají.
  Future<void> _v13RebuildPlaylistSongs(Migrator m) async {
    await testMigrationFault?.call('playlistSongs:beforeCopy');
    await customStatement(
        'ALTER TABLE playlist_songs RENAME TO playlist_songs_v12_old');
    await m.createTable(playlistSongs);
    final oldRows = await customSelect(
            'SELECT playlist_id, song_id, order_index, tempo FROM playlist_songs_v12_old '
            'ORDER BY playlist_id, order_index, song_id')
        .get();
    final seenOccurrenceIds = <String>{};
    for (final row in oldRows) {
      // Každý stávající výskyt dostane vlastní nové přenosové ID.
      final occurrenceId = _freshUniqueUid(seenOccurrenceIds);
      await into(playlistSongs).insert(PlaylistSongsCompanion.insert(
            playlistId: row.read<int>('playlist_id'),
            songId: row.read<int>('song_id'),
            orderIndex: Value(row.read<int>('order_index')),
            tempo: Value(row.readNullable<double>('tempo')),
            occurrenceId: occurrenceId,
            // scrollSpeed / introDuration / stopMarksOverride záměrně absent:
            // v13 výchozí stav = zděděné (NULL).
          ));
    }
    await customStatement('DROP TABLE playlist_songs_v12_old');
    await testMigrationFault?.call('playlistSongs:done');
  }

  /// Přidá `stop_marks.playlist_song_id` (nullable). Všechny staré zarážky
  /// zůstávají sdílené (NULL = patří skladbě), ostatní pole se nemění.
  Future<void> _v13AddOccurrenceLinkToStopMarks() async {
    await testMigrationFault?.call('stopMarks:beforeAlter');
    await customStatement(
        'ALTER TABLE stop_marks ADD COLUMN playlist_song_id INTEGER '
        'REFERENCES playlist_songs (id) ON DELETE CASCADE');
    await testMigrationFault?.call('stopMarks:done');
  }

  /// Validace migrace uvnitř migrační transakce – při nesouladu migrace
  /// NEPROBĚHNE (rollback, DB zůstane ve v12).
  Future<void> _v13VerifyMigrationResult() async {
    await testMigrationFault?.call('verify:before');

    // (1) Přenosová identita: neprázdné a unikátní hodnoty.
    Future<void> assertUniqueNonEmpty(String table, String column) async {
      final row = await customSelect(
        'SELECT COUNT(*) AS total, COUNT(DISTINCT "$column") AS uniq, '
        'SUM(CASE WHEN "$column" IS NULL OR length(trim("$column")) = 0 '
        'THEN 1 ELSE 0 END) AS emptyCount FROM "$table"',
      ).getSingle();
      final total = row.read<int>('total');
      final uniq = row.read<int>('uniq');
      final emptyCount = row.read<int?>('emptyCount') ?? 0;
      if (total != uniq || emptyCount != 0) {
        throw StateError('Validace v13 selhala: $table.$column '
            '(řádků: $total, unikátních: $uniq, prázdných: $emptyCount).');
      }
    }

    await assertUniqueNonEmpty('playlists', 'playlist_uid');
    await assertUniqueNonEmpty('playlist_songs', 'occurrence_id');

    // (2) Skutečné schéma vs definice Drift (čerstvá v13 databáze).
    await _v13AssertSchemaMatchesFreshDriftSchema();

    // (3) Integrita databáze.
    final integrity = await customSelect('PRAGMA integrity_check').getSingle();
    final integrityResult = integrity.read<String>('integrity_check');
    if (integrityResult != 'ok') {
      throw StateError('PRAGMA integrity_check selhal: $integrityResult');
    }

    // (4) Cizí klíče – pragma funguje i bez jejich vynucení.
    final violations = await customSelect('PRAGMA foreign_key_check').get();
    if (violations.isNotEmpty) {
      final detail = violations
          .take(5)
          .map((r) => r.data.values.join('/'))
          .join('; ');
      throw StateError(
          'PRAGMA foreign_key_check hlásí ${violations.length} porušení: $detail');
    }

    await testMigrationFault?.call('verify:done');
  }

  /// Porovná skutečné schéma migrované databáze s definicemi Drift
  /// (čerstvě vytvořená v13 databáze z těchže tabulkových tříd).
  /// Porovnává se množina atributů přes PRAGMA (ne text DDL), takže je
  /// nezávislá na pořadí sloupců (historické migrace přidávají sloupce na
  /// konec) – přesto odhalí chybějící sloupce, typy, defaulty i unikátní
  /// omezení.
  Future<void> _v13AssertSchemaMatchesFreshDriftSchema() async {
    // Druhá instance slouží JEN pro porovnání schématu, proto lokálně
    // potlačíme varování driftu o vícenásobném vytvoření databázové třídy.
    final prevDontWarn = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final AppDatabase fresh;
    try {
      fresh = AppDatabase.forExecutor(NativeDatabase.memory());
    } finally {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = prevDontWarn;
    }
    try {
      const tables = [
        'songs',
        'playlists',
        'playlist_songs',
        'stop_marks',
        'custom_strings',
        'diacritic_mappings',
      ];
      Future<String> columns(DatabaseConnectionUser db, String table) async {
        final rows = await db.customSelect('PRAGMA table_info("$table")').get();
        final items = rows
            .map((r) => '${r.data['name']}|${r.data['type']}|${r.data['notnull']}|'
                '${r.data['dflt_value']}|${r.data['pk']}')
            .toList()
          ..sort();
        return items.join('\n');
      }

      Future<String> indexes(DatabaseConnectionUser db, String table) async {
        final idxRows = await db.customSelect('PRAGMA index_list("$table")').get();
        final out = <String>[];
        for (final idx in idxRows) {
          final name = idx.data['name'] as String;
          final cols = await db.customSelect('PRAGMA index_info("$name")').get();
          out.add('${idx.data['unique']}|${idx.data['origin']}|'
              '${idx.data['partial']}|${cols.map((c) => c.data['name']).join(',')}');
        }
        return (out..sort()).join('\n');
      }

      for (final table in tables) {
        final expectedColumns = await columns(fresh, table);
        final actualColumns = await columns(this, table);
        if (expectedColumns != actualColumns) {
          throw StateError('Schéma "$table" po migraci neodpovídá definici Driftu.\n'
              'Očekáváno (čerstvá v13):\n$expectedColumns\n'
              'Skutečnost (migrovaná):\n$actualColumns');
        }
        final expectedIndexes = await indexes(fresh, table);
        final actualIndexes = await indexes(this, table);
        if (expectedIndexes != actualIndexes) {
          throw StateError(
              'Indexy/omezení "$table" po migraci neodpovídají definici Driftu.\n'
              'Očekáváno:\n$expectedIndexes\nSkutečnost:\n$actualIndexes');
        }
      }
    } finally {
      await fresh.close();
    }
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

  Future<int> updateSongPath(int id, String newPath) =>
      (update(songs)..where((s) => s.id.equals(id))).write(SongsCompanion(filePath: Value(newPath)));

  Future<int> updateSongDuration(int id, int? seconds) =>
      (update(songs)..where((s) => s.id.equals(id))).write(SongsCompanion(duration: Value(seconds)));

  Future<int> updateSongSettings(int id, double? bpm, double? introDuration, double? fontSize, double scrollMultiplier) =>
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

  Future<int> addStopMarkAtLine(int songId, int lineIndex, String lineText, int bars) {
    return into(stopMarks).insert(StopMarksCompanion.insert(
      songId: songId,
      positionRatio: 0,
      durationBars: bars,
      lineIndex: Value(lineIndex),
      lineText: Value(lineText),
    ));
  }
  
  Future<List<StopMark>> getStopMarksForSong(int songId) =>
      (select(stopMarks)..where((t) => t.songId.equals(songId))).get();

  Future<int> deleteStopMark(int id) => (delete(stopMarks)..where((t) => t.id.equals(id))).go();

  Future<int> deleteSong(int id) => (delete(songs)..where((t) => t.id.equals(id))).go();

  /// Vrátí seřazené IDs písní v setlistu podle orderIndex.
  Future<List<int>> getPlaylistSongIds(int playlistId) async {
    final rows = await (select(playlistSongs)..where((t) => t.playlistId.equals(playlistId))..orderBy([(t) => OrderingTerm(expression: t.orderIndex)])).get();
    return rows.map((r) => r.songId).toList();
  }

  /// Upsert písně s parametry – v2 balíček. Vrací songId (nové nebo aktualizované).
  /// Pokud píseň existuje (norm match title+artist), přepíše soubor + aktualizuje DB.
  Future<int?> importOrUpdateSongPackage({
    required String title,
    required String artist,
    required String content,
    double? tempo,
    double? scrollSpeed,
    double? fontSize,
    double? introDuration,
    int? duration,
    int? transpose,
    List<Map<String, dynamic>>? stopMarksParam,
  }) async {
    // Zkusit najít existující via přesná shoda nebo norm shoda (diakritika-insensitive)
    SongEntry? existing;
    final exact = await (select(songs)..where((t) => t.title.equals(title) & t.artist.equals(artist))).getSingleOrNull();
    if (exact != null) {
      existing = exact;
    } else {
      // fallback norm match
      final all = await select(songs).get();
      final normWanted = _normForMatch('$artist|$title');
      final normTitleWanted = _normForMatch(title);
      for (final s in all) {
        final normFull = _normForMatch('${s.artist}|${s.title}');
        final normTitle = _normForMatch(s.title);
        if (normFull == normWanted && normWanted.isNotEmpty) { existing = s; break; }
        if (existing == null && normTitle == normTitleWanted && normTitleWanted.isNotEmpty) {
          // only fallback if artist empty or single match – pick first title match
          existing = s;
        }
      }
      // pokud našlo více titulů se stejným normTitle, exact už by selhal – bereme první
    }

    if (existing != null) {
      // Aktualizovat soubor
      try {
        final file = File(existing.filePath);
        await file.writeAsString(content, encoding: utf8);
      } catch (_) {
        // pokud soubor chybí, vytvořit nový v imported_songs
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final songsDir = Directory(p.join(appDir.path, 'imported_songs'));
          if (!await songsDir.exists()) await songsDir.create(recursive: true);
          final safeArtist = artist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
          final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
          var fileName = '${safeArtist.isNotEmpty ? '$safeArtist - ' : ''}$safeTitle.txt';
          var filePath = p.join(songsDir.path, fileName);
          await File(filePath).writeAsString(content, encoding: utf8);
          await updateSongPath(existing.id, filePath);
        } catch (_) {}
      }
      // Aktualizovat DB parametry (null = ponechat původní, ale pokud přijde hodnota, přepsat)
      final upd = SongsCompanion(
        artist: Value(artist),
        title: Value(title),
        tempo: tempo != null ? Value(tempo) : const Value.absent(),
        customScrollSpeed: scrollSpeed != null ? Value(scrollSpeed) : const Value.absent(),
        customFontSize: fontSize != null ? Value(fontSize) : const Value.absent(),
        introDuration: introDuration != null ? Value(introDuration) : const Value.absent(),
        duration: duration != null ? Value(duration) : const Value.absent(),
      );
      if (upd.tempo.present || upd.customScrollSpeed.present || upd.customFontSize.present || upd.introDuration.present || upd.duration.present) {
        await (update(songs)..where((t) => t.id.equals(existing!.id))).write(upd);
      } else {
        // alespoň title/artist
        await updateSong(existing!.id, artist, title);
        if (duration != null) await updateSongDuration(existing!.id, duration);
      }
      // Zarážky – přepsat pokud přišly (včetně prázdného = smazat)
      if (stopMarksParam != null) {
        await (delete(stopMarks)..where((t) => t.songId.equals(existing!.id))).go();
        for (final m in stopMarksParam) {
          final bars = (m['bars'] is int) ? m['bars'] as int : int.tryParse(m['bars']?.toString() ?? '2') ?? 2;
          final clamped = bars.clamp(1, 16).toInt();
          final lt = (m['lineText'] ?? '').toString();
          final li = m['lineIndex'] is int ? m['lineIndex'] as int : int.tryParse(m['lineIndex']?.toString() ?? '');
          if (li != null) {
            await into(stopMarks).insert(StopMarksCompanion.insert(songId: existing!.id, positionRatio: 0, durationBars: clamped, lineIndex: Value(li), lineText: Value(lt.isEmpty ? null : lt)));
          } else if (lt.isNotEmpty) {
            await into(stopMarks).insert(StopMarksCompanion.insert(songId: existing!.id, positionRatio: 0, durationBars: clamped, lineText: Value(lt)));
          } else if (stopMarksParam.isNotEmpty) {
            await into(stopMarks).insert(StopMarksCompanion.insert(songId: existing!.id, positionRatio: 0, durationBars: clamped));
          }
        }
      }
      // transpose se neukládá do DB per-song globálně – ignorujeme (přehrávač si ho vezme z balíčku při otevření)
      return existing!.id;
    }

    // Nová píseň
    final appDir = await getApplicationDocumentsDirectory();
    final songsDir = Directory(p.join(appDir.path, 'imported_songs'));
    if (!await songsDir.exists()) {
      await songsDir.create(recursive: true);
    }
    final safeArtist = artist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    var fileName = '${safeArtist.isNotEmpty ? '$safeArtist - ' : ''}$safeTitle.txt';
    var filePath = p.join(songsDir.path, fileName);
    var counter = 1;
    while (await File(filePath).exists()) {
      final base = fileName.replaceAll('.txt', '');
      filePath = p.join(songsDir.path, '${base}_$counter.txt');
      counter++;
    }
    await File(filePath).writeAsString(content, encoding: utf8);
    final id = await into(songs).insert(SongsCompanion.insert(
      filePath: filePath,
      artist: artist,
      title: title,
      tempo: Value(tempo),
      customScrollSpeed: Value(scrollSpeed),
      customFontSize: Value(fontSize),
      introDuration: Value(introDuration),
      duration: Value(duration),
    ));
    if (stopMarksParam != null && stopMarksParam.isNotEmpty) {
      for (final m in stopMarksParam) {
        final bars = (m['bars'] is int) ? m['bars'] as int : int.tryParse(m['bars']?.toString() ?? '2') ?? 2;
        final clamped = bars.clamp(1, 16).toInt();
        final lt = (m['lineText'] ?? '').toString();
        final li = m['lineIndex'] is int ? m['lineIndex'] as int : int.tryParse(m['lineIndex']?.toString() ?? '');
        if (li != null) {
          await into(stopMarks).insert(StopMarksCompanion.insert(songId: id, positionRatio: 0, durationBars: clamped, lineIndex: Value(li), lineText: Value(lt.isEmpty ? null : lt)));
        } else if (lt.isNotEmpty) {
          await into(stopMarks).insert(StopMarksCompanion.insert(songId: id, positionRatio: 0, durationBars: clamped, lineText: Value(lt)));
        } else {
          await into(stopMarks).insert(StopMarksCompanion.insert(songId: id, positionRatio: 0, durationBars: clamped));
        }
      }
    }
    return id;
  }

  /// Naimportuje přijatý balíček písně (text + metadata) do knihovny.
  /// Obsah zapíše do nového souboru v aplikačním adresáři a vloží záznam.
  /// Vrací true, pokud byla píseň nově přidána, false pokud už existuje.
  Future<bool> importSongPackage({
    required String title,
    required String artist,
    required String content,
  }) async {
    final existing = await (select(songs)
          ..where((t) => t.title.equals(title) & t.artist.equals(artist)))
        .getSingleOrNull();
    if (existing != null) return false;

    final appDir = await getApplicationDocumentsDirectory();
    final songsDir = Directory(p.join(appDir.path, 'imported_songs'));
    if (!await songsDir.exists()) {
      await songsDir.create(recursive: true);
    }

    final safeArtist = artist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    var fileName = '${safeArtist.isNotEmpty ? '$safeArtist - ' : ''}$safeTitle.txt';
    var filePath = p.join(songsDir.path, fileName);
    var counter = 1;
    while (await File(filePath).exists()) {
      final base = fileName.replaceAll('.txt', '');
      filePath = p.join(songsDir.path, '${base}_$counter.txt');
      counter++;
    }

    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);

    await into(songs).insert(
      SongsCompanion.insert(
        filePath: filePath,
        artist: artist,
        title: title,
      ),
    );
    return true;
  }

  Future<String> exportSongsToCsv() async {
    final songs = await select(this.songs).get();
    final buffer = StringBuffer();
    // Přidání UTF-8 BOM pro správnou interpretaci v Excelu
    buffer.write('\uFEFF');
    buffer.writeln("id,artist,title,duration,filePath");
    for (final song in songs) {
      // Bezpečné escapování uvozovek pro CSV
      String escape(String? s) => (s ?? '').replaceAll('"', '""');
      buffer.writeln(
          "${song.id},\"${escape(song.artist)}\",\"${escape(song.title)}\",${song.duration ?? 0},\"${escape(song.filePath)}\"");
    }
    return buffer.toString();
  }

  /// Rozparsuje jeden řádek CSV – respektuje čárky uvnitř uvozovek.
  static List<String> _parseCsvLine(String line) {
    final pattern = RegExp(r',(?=(?:(?:[^"]*"){2})*[^"]*$)');
    return line
        .split(pattern)
        .map((p) => p.trim().replaceAll(RegExp(r'^"|"$'), '').replaceAll('""', '"').trim())
        .toList();
  }

  /// Rozparsuje jeden řádek CSV slovníku – respektuje čárky i středníky (český Excel)
  /// uvnitř uvozovek. Zkouší čárku, pak středník.
  static List<String> _parseDiacriticCsvLine(String line) {
    var parts = _parseCsvLine(line);
    if (parts.length >= 2) return parts;
    if (line.contains(';')) {
      final semiPattern = RegExp(r';(?=(?:(?:[^"]*"){2})*[^"]*$)');
      parts = line
          .split(semiPattern)
          .map((p) => p.trim().replaceAll(RegExp(r'^"|"$'), '').replaceAll('""', '"').trim())
          .toList();
    }
    return parts;
  }

  /// Normalizuje cestu pro porovnání (oddělovače a velikost písmen).
  static String _normalizePath(String path) =>
      path.replaceAll('\\', '/').trim().toLowerCase();

  /// Odstraní diakritiku pro porovnání názvů souborů bez háčků/čárek.
  static String _stripDiacritics(String input) => TextNormalizer.stripDiacritics(input);

  static String _normForMatch(String input) => TextNormalizer.normForSearch(input);

  /// Povolena je pouze změna diakritiky – po strip musí být řetězce shodné.
  /// Odmítá překlepy typu "Mladek" -> "Mladdek" (vložení písmene).
  static bool _isDiacriticOnly(String raw, String corrected) =>
      TextNormalizer.isDiacriticOnly(raw, corrected);

  /// Výsledek hromadného importu metadat z CSV.
  /// [skipped] obsahuje řádky, které se nepodařilo bezpečně spárovat
  /// (id existuje, ale filePath nesedí) – ty se záměrně nepřepisují,
  /// aby se metadata nezapsala špatné písni.
  Future<CsvImportResult> importSongsFromCsv(String csvContent) async {
    final content = csvContent.startsWith('\uFEFF') ? csvContent.substring(1) : csvContent;
    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.length < 2) return const CsvImportResult(updated: 0, skipped: 0);

    int updatedCount = 0;
    int skippedCount = 0;
    await transaction(() async {
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = _parseCsvLine(line);
        if (parts.length < 3) continue;

        final idStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '').trim();
        final id = int.tryParse(idStr);
        if (id == null) continue;

        final song = await (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (song == null) continue;

        // Ověření identity řádku: pokud CSV obsahuje filePath a nesedí
        // s uloženou cestou, jde nejspíš o zastaralé CSV z jiného stavu
        // knihovny – takový řádek přeskočíme.
        if (parts.length > 4 && parts[4].isNotEmpty) {
          if (_normalizePath(parts[4]) != _normalizePath(song.filePath)) {
            skippedCount++;
            continue;
          }
        }

        final artist = parts[1].trim();
        final title = parts[2].trim();
        final duration = parts.length > 3 ? int.tryParse(parts[3].trim()) ?? 0 : 0;

        final result = await (update(songs)..where((t) => t.id.equals(id))).write(
          SongsCompanion(
            artist: Value(artist),
            title: Value(title),
            duration: Value(duration > 0 ? duration : null),
          ),
        );
        if (result > 0) updatedCount++;
      }
    });
    return CsvImportResult(updated: updatedCount, skipped: skippedCount);
  }

  Future<List<Map<String, dynamic>>> previewSongsFromCsv(String csvContent) async {
    final content = csvContent.startsWith('\uFEFF') ? csvContent.substring(1) : csvContent;
    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.length < 2) return [];

    final preview = <Map<String, dynamic>>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = _parseCsvLine(line);

      if (parts.isEmpty || parts[0].isEmpty) continue;

      final idStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '').trim();
      final id = int.tryParse(idStr);

      if (id != null) {
        final song = await (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (song != null) {
          final pathMismatch =
              parts.length > 4 && parts[4].isNotEmpty && _normalizePath(parts[4]) != _normalizePath(song.filePath);
          preview.add({
            'id': id,
            'oldArtist': song.artist,
            'newArtist': parts.length > 1 ? parts[1].trim() : song.artist,
            'oldTitle': song.title,
            'newTitle': parts.length > 2 ? parts[2].trim() : song.title,
            'newDuration': parts.length > 3 ? int.tryParse(parts[3].trim()) ?? 0 : song.duration ?? 0,
            'pathMismatch': pathMismatch,
          });
        }
      }
    }
    return preview;
  }

  /// Export setlistu včetně časů, tempa a zarážek pro sdílení (v4 – přidává scrollSpeed/fontSize/introDuration). Vrací mapu připravenou pro jsonEncode.
  Future<Map<String, dynamic>> exportPlaylistToJson(int playlistId, {bool includeContents = false}) async {
    final playlist = await (select(playlists)..where((t) => t.id.equals(playlistId))).getSingle();
    final items = await getPlaylistSongsWithTempo(playlistId);
    int totalDuration = 0;
    int unknownCount = 0;
    for (final w in items) {
      final s = w.song;
      if (s.duration != null && s.duration! > 0) {
        totalDuration += s.duration!;
      } else {
        unknownCount++;
      }
    }
    final songsJson = <Map<String, dynamic>>[];
    for (final w in items) {
      final s = w.song;
      // Per-výskytové nastavení má přednost; globální nastavení skladby je
      // jen fallback, když výskyt vlastní hodnotu nemá. Nikdy se tak
      // hodnoty nezaměňují mezi úrovněmi.
      final entry = <String, dynamic>{
        // Přenosová identita výskytu – povinná součást exportu v5.
        'occurrenceId': w.occurrenceId,
        'title': s.title,
        'artist': s.artist,
        'duration': s.duration,
        if (w.playlistTempo != null) 'tempo': w.playlistTempo,
        if (w.playlistTempo == null && s.tempo != null) 'tempo': s.tempo,
        if ((w.scrollSpeed ?? s.customScrollSpeed) != null)
          'scrollSpeed': w.scrollSpeed ?? s.customScrollSpeed,
        if (s.customFontSize != null) 'fontSize': s.customFontSize,
        if ((w.introDuration ?? s.introDuration) != null)
          'introDuration': w.introDuration ?? s.introDuration,
        if (w.stopMarksOverride != null)
          'stopMarksOverride': w.stopMarksOverride,
      };
      // Pokud obě tempa null, tempo neuvádíme (zůstane null na importu)
      if (entry['tempo'] == null) entry.remove('tempo');
      if (entry['scrollSpeed'] == null) entry.remove('scrollSpeed');
      if (entry['fontSize'] == null) entry.remove('fontSize');
      if (entry['introDuration'] == null) entry.remove('introDuration');
      // Zarážky – DB kotvy + direktivy v content se přenesou s obsahem, ale pro DB sync posíláme i stopMarks
      try {
        final marks = await getStopMarksForSong(s.id);
        if (marks.isNotEmpty) {
          entry['stopMarks'] = [
            for (final m in marks)
              {
                if (m.lineText != null && m.lineText!.isNotEmpty) 'lineText': m.lineText,
                if (m.lineIndex != null) 'lineIndex': m.lineIndex,
                'bars': m.durationBars,
              }
          ];
        }
      } catch (_) {}
      if (includeContents) {
        try {
          final file = File(s.filePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            String content;
            try {
              content = utf8.decode(bytes);
            } catch (_) {
              content = latin1.decode(bytes);
            }
            entry['content'] = content;
          }
        } catch (_) {}
      }
      songsJson.add(entry);
    }
    return {
      'type': 'playlist',
      'version': 5,
      'playlistUid': playlist.playlistUid,
      'name': playlist.name,
      'exportedAt': DateTime.now().toIso8601String(),
      'totalDuration': totalDuration,
      'unknownCount': unknownCount,
      'songs': songsJson,
    };
  }

  Future<PlaylistSyncResult> syncPlaylistFromJson(Map<String, dynamic> data) async {
    final playlistName = (data['name'] as String?)?.trim() ?? '';
    if (playlistName.isEmpty) {
      throw const FormatException('Chybějící název playlistu.');
    }
    // Přenosová identita setlistu (v5+). Soubory bez ní jsou starší
    // formát (v2–v4) a nesmějí potichu přepisovat existující setlisty.
    final playlistUidRaw = (data['playlistUid'] ?? '').toString().trim();
    final isIdentifiedFormat = playlistUidRaw.isNotEmpty;
    // Sběr neznámých horní-úrovňových polí (schéma v13 nemá extras –
    // neukládáme je, ale NEZAHAZUJEME potichu: viz droppedExtrasKeys).
    // ttsEngine/ttsVoice jsou sice kanonická pole kontraktu v5, ale app
    // pro ně nemá sloupec → rovněž se hlásí jako neuložená.
    const canonicalTopKeys = {
      'type', 'version', 'name', 'exportedAt', 'totalDuration',
      'unknownCount', 'songs', 'playlistUid',
    };
    final droppedKeys = <String>{};
    for (final key in data.keys) {
      if (!canonicalTopKeys.contains(key) && !key.startsWith('_')) {
        droppedKeys.add(key);
      }
    }
    final rawSongs = data['songs'] as List<dynamic>? ?? const [];
    // V2: List<Map> s title/artist/duration, zpětně kompatibilní List<String>
    final List<Map<String, dynamic>> parsedSongs = [];
    final List<String> notFoundLabels = [];
    int totalDurationShared = 0;
    int unknownShared = 0;
    // Spočítat sdílený čas pro hlášku (pokud je v exportu)
    if (data.containsKey('totalDuration') && data['totalDuration'] is int) {
      totalDurationShared = data['totalDuration'] as int;
    }
    if (data.containsKey('unknownCount') && data['unknownCount'] is int) {
      unknownShared = data['unknownCount'] as int;
    }
    for (final raw in rawSongs) {
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        final title = (m['title'] ?? m['name'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        final artist = (m['artist'] ?? '').toString().trim();
        final duration = m['duration'] is int ? m['duration'] as int : int.tryParse(m['duration']?.toString() ?? '');
        double? tempo;
        if (m.containsKey('tempo') && m['tempo'] != null) {
          if (m['tempo'] is num) tempo = (m['tempo'] as num).toDouble();
          else tempo = double.tryParse(m['tempo'].toString());
          if (tempo != null && (tempo < 30 || tempo > 300)) tempo = null;
        }
        double? scrollSpeed;
        if (m.containsKey('scrollSpeed') && m['scrollSpeed'] != null) {
          if (m['scrollSpeed'] is num) scrollSpeed = (m['scrollSpeed'] as num).toDouble();
          else scrollSpeed = double.tryParse(m['scrollSpeed'].toString());
          if (scrollSpeed != null) scrollSpeed = scrollSpeed.clamp(0.1, 5.0).toDouble();
        }
        double? fontSize;
        if (m.containsKey('fontSize') && m['fontSize'] != null) {
          if (m['fontSize'] is num) fontSize = (m['fontSize'] as num).toDouble();
          else fontSize = double.tryParse(m['fontSize'].toString());
          if (fontSize != null) fontSize = fontSize.clamp(10, 100).toDouble();
        }
        double? introDuration;
        if (m.containsKey('introDuration') && m['introDuration'] != null) {
          if (m['introDuration'] is num) introDuration = (m['introDuration'] as num).toDouble();
          else introDuration = double.tryParse(m['introDuration'].toString());
        }
        // v3: stopMarks volitelné [{lineText,lineIndex,bars}]
        List<Map<String, dynamic>> stopMarks = [];
        bool hasStopMarksKey = m.containsKey('stopMarks');
        if (m['stopMarks'] is List) {
          for (final sm in (m['stopMarks'] as List)) {
            if (sm is! Map) continue;
            final mm = Map<String, dynamic>.from(sm as Map);
            int? bars = mm['bars'] is int ? mm['bars'] as int : int.tryParse(mm['bars']?.toString() ?? '');
            if (bars == null || bars <= 0) continue;
            bars = bars.clamp(1, 16).toInt();
            final lt = (mm['lineText'] ?? mm['line_text'] ?? mm['line'] ?? '').toString().trim();
            int? li;
            if (mm.containsKey('lineIndex') && mm['lineIndex'] != null) {
              li = mm['lineIndex'] is int ? mm['lineIndex'] as int : int.tryParse(mm['lineIndex'].toString());
            }
            stopMarks.add({'lineText': lt, 'lineIndex': li, 'bars': bars});
          }
        }
        // v5: přenosová identita výskytu; null u starších souborů.
        final occurrenceIdRaw = (m['occurrenceId'] ?? '').toString().trim();
        // v5: tri-stav výskytových zarážek (null = zděděné ze skladby).
        final override = m['stopMarksOverride'] is bool
            ? (m['stopMarksOverride'] as bool)
            : null;
        // Neznámá per-item pole (extras) – schéma v13 je neumí uložit,
        // proto se jen hlásí (viz droppedExtrasKeys), neukládají se.
        const canonicalItemKeys = {
          'title', 'name', 'artist', 'duration', 'tempo', 'scrollSpeed',
          'fontSize', 'introDuration', 'content', 'stopMarks', 'filePath',
          'occurrenceId', 'stopMarksOverride', 'extras',
        };
        for (final key in m.keys) {
          if (!canonicalItemKeys.contains(key) && !key.startsWith('_')) {
            droppedKeys.add(key);
          }
        }
        if (m['extras'] is Map) {
          for (final key in (m['extras'] as Map).keys) {
            final k = key.toString();
            if (!k.startsWith('_')) droppedKeys.add(k);
          }
        }
        parsedSongs.add({'title': title, 'artist': artist, 'duration': duration, 'tempo': tempo, 'scrollSpeed': scrollSpeed, 'fontSize': fontSize, 'introDuration': introDuration, 'content': m['content'], 'stopMarks': stopMarks, 'hasStopMarksKey': hasStopMarksKey, 'occurrenceId': occurrenceIdRaw, 'stopMarksOverride': override});
        if (duration != null && duration > 0) {
          if (totalDurationShared == 0) totalDurationShared += duration;
        } else {
          if (unknownShared == 0 && data['totalDuration'] == null) unknownShared++;
        }
      } else {
        final rawTitle = raw.toString().trim();
        if (rawTitle.isEmpty) continue;
        // Fallback pro staré Generator soubory: "Interpret - Název" jako jeden string
        var artist = '';
        var title = rawTitle;
        final sep = RegExp(r'\s+[-–—]\s+').firstMatch(rawTitle);
        if (sep != null) {
          final a = rawTitle.substring(0, sep.start).trim();
          final t = rawTitle.substring(sep.end).trim();
          if (a.isNotEmpty && t.isNotEmpty) {
            artist = a;
            title = t;
          }
        } else {
          final all = RegExp(r'\s*[-–—]\s*').allMatches(rawTitle).toList();
          if (all.isNotEmpty) {
            final last = all.last;
            final a = rawTitle.substring(0, last.start).trim();
            final t = rawTitle.substring(last.end).trim();
            if (a.isNotEmpty && t.isNotEmpty) {
              artist = a;
              title = t;
            }
          }
        }
        parsedSongs.add({'title': title, 'artist': artist, 'duration': null, 'tempo': null, 'stopMarks': <Map<String, dynamic>>[], 'hasStopMarksKey': false, 'occurrenceId': '', 'stopMarksOverride': null});
        unknownShared++;
      }
    }
    // Pokud totalDuration nebyl v exportu, spočítat z parsed
    if (!data.containsKey('totalDuration')) {
      totalDurationShared = parsedSongs.fold<int>(0, (sum, e) => sum + ((e['duration'] as int?) ?? 0));
      unknownShared = parsedSongs.where((e) => (e['duration'] as int?) == null || (e['duration'] as int) == 0).length;
    }

    // Slovníky pro match: norm(artist|title) primárně, norm(title) jen pokud
    // soubor nemá interpreta a shoda je jednoznačná. Nikdy se nevybírá
    // „první shoda“ – u vícenásobných kandidátů je párování nejednoznačné
    // a položka se spáruje (T-13H, sekce 6 schválení A1.3).
    final allSongs = await select(songs).get();
    final byNormFull = <String, List<SongEntry>>{};
    final byNormTitle = <String, List<SongEntry>>{};
    for (final song in allSongs) {
      final fullKey = _normForMatch('${song.artist}|${song.title}');
      final titleKey = _normForMatch(song.title);
      if (fullKey.isNotEmpty) byNormFull.putIfAbsent(fullKey, () => []).add(song);
      if (titleKey.isNotEmpty) byNormTitle.putIfAbsent(titleKey, () => []).add(song);
    }
    // Vrátí shodu jen pokud je právě jedna; 0 i ≥2 kandidátů = neshoda,
    // aby se nikdy náhodně nevybrala špatná píseň.
    SongEntry? uniqueMatch(Map<String, List<SongEntry>> index, String key) {
      if (key.isEmpty) return null;
      final list = index[key];
      if (list == null || list.length != 1) return null;
      return list.first;
    }

    final notFound = <String>[];
    final matchedIds = <int>[];
    final matchedEntries = <SongEntry>[];
    // Písně už vložené do tohoto setlistu – nahrazuje starou deduplikaci
    // přes InsertMode.insertOrIgnore nad kompozitním PK (v13 PK je id).
    final insertedSongIds = <int>{};
    // Kandidáti na doplnění budou spočítáni až po transakci, kdy máme matchedEntries
    final Map<int, int> sharedDurationBySongId = {};
    final Map<int, Map<String, String>> sharedDiacriticBySongId = {};
    final Map<int, List<Map<String, dynamic>>> sharedStopMarksBySongId = {};
    final Map<int, double?> sharedTempoBySongId = {};
    final Map<int, double?> sharedScrollSpeedBySongId = {};
    final Map<int, double?> sharedFontSizeBySongId = {};
    final Map<int, double?> sharedIntroBySongId = {};
    final Map<int, String> sharedContentBySongId = {};

    var matchedCount = 0;

    // Výsledek párování setlistu z transakce (pro PlaylistSyncResult).
    int? syncCreatedPlaylistId;
    String? syncPlaylistUid;

    // Validace ještě před zápisem: soubor nesmí obsahovat occurrenceId
    // dvakrát (nejednoznačný import → chyba, žádná data se nezmění).
    if (isIdentifiedFormat) {
      final seenOcc = <String>{};
      for (final entry in parsedSongs) {
        final occ = (entry['occurrenceId'] as String? ?? '').trim();
        if (occ.isNotEmpty && !seenOcc.add(occ)) {
          throw FormatException(
              'Soubor obsahuje occurrenceId "$occ" dvakrát – '
              'nejednoznačný import, data nebyla změněna.');
        }
      }
    }

    await transaction(() async {
      // --- Párování setlistu -----------------------------------------------
      // Identifikovaný soubor (v5): párovat POUZE podle playlistUid, nikdy
      // podle jména. Setlist stejného jména s jiným uid se nepřepisuje.
      // Starší soubor bez uid: setlist stejného jména se potichu nepřepisuje
      // (nelze bezpečně rozlišit aktualizaci od kopie) → srozumitelná chyba.
      Playlist playlist;
      bool createdNewPlaylist = false;
      if (isIdentifiedFormat) {
        final existingByUid = await (select(playlists)
              ..where((t) => t.playlistUid.equals(playlistUidRaw)))
            .getSingleOrNull();
        if (existingByUid != null) {
          playlist = existingByUid;
        } else {
          final id = await into(playlists).insert(PlaylistsCompanion.insert(
              name: playlistName, playlistUid: playlistUidRaw));
          createdNewPlaylist = true;
          playlist = await (select(playlists)..where((t) => t.id.equals(id)))
              .getSingle();
        }
      } else {
        final existingByName = await (select(playlists)
              ..where((t) => t.name.equals(playlistName)))
            .getSingleOrNull();
        if (existingByName != null) {
          throw FormatException(
              'Setlist "$playlistName" už existuje a soubor neobsahuje '
              'přenosové ID (playlistUid). Aktualizaci ani bezpečnou kopii '
              'nerozliším – import zastaven, data zůstala beze změny. '
              'Pro opakovanou synchronizaci použij soubor formátu v5.');
        }
        final id = await into(playlists).insert(PlaylistsCompanion.insert(
            name: playlistName, playlistUid: _newUuidV4()));
        createdNewPlaylist = true;
        playlist = await (select(playlists)..where((t) => t.id.equals(id)))
            .getSingle();
      }
      final int playlistId = playlist.id;

      // --- Párování výskytů (jen identified režim) ------------------------
      // Výskyty se párují podle occurrenceId, NE podle songId. Žádný řádek
      // se nemaže – opakovaný import je deterministický (UPDATE/INSERT).
      final existingRows = await (select(playlistSongs)
            ..where((t) => t.playlistId.equals(playlistId)))
          .get();
      final rowByOccurrence = <String, PlaylistSong>{
        for (final r in existingRows)
          if (r.occurrenceId.isNotEmpty) r.occurrenceId: r,
      };
      final consumedRowIds = <int>{};

      int order = 0;
      for (final entry in parsedSongs) {
        final title = entry['title'] as String;
        final artist = entry['artist'] as String? ?? '';
        final duration = entry['duration'] as int?;
        final tempo = entry['tempo'] as double?;
        final scrollSpeed = entry['scrollSpeed'] as double?;
        final fontSize = entry['fontSize'] as double?;
        final introDuration = entry['introDuration'] as double?;
        final content = entry['content'] as String?;
        final occurrenceIdRaw = (entry['occurrenceId'] as String? ?? '').trim();
        final stopMarksOverride = entry['stopMarksOverride'] as bool?;
        final fullKey = artist.isNotEmpty ? _normForMatch('$artist|$title') : '';
        final titleKey = _normForMatch(title);
        // Interpret ve zdroji souhlasí → párovat dle (interpret|název);
        // bez interpreta ve zdroji → dle názvu. Vždy jen při právě jednom
        // kandidátu. Shodný název s jiným interpretem se NESPÁRUJE
        // (žádná potichu přepsaná cizí píseň – T-13H).
        final SongEntry? song = artist.isNotEmpty
            ? uniqueMatch(byNormFull, fullKey)
            : uniqueMatch(byNormTitle, titleKey);
        final label = artist.isNotEmpty ? '$artist - $title' : title;
        if (song != null) {
          matchedCount++;
          matchedIds.add(song.id);
          matchedEntries.add(song);
          if (duration != null && duration > 0) {
            sharedDurationBySongId[song.id] = duration;
          }
          if (tempo != null) sharedTempoBySongId[song.id] = tempo;
          if (scrollSpeed != null) sharedScrollSpeedBySongId[song.id] = scrollSpeed;
          if (fontSize != null) sharedFontSizeBySongId[song.id] = fontSize;
          if (introDuration != null) sharedIntroBySongId[song.id] = introDuration;
          if (content != null && content.trim().isNotEmpty) sharedContentBySongId[song.id] = content;
          // Kandidát na diakritiku: norm shodný ale přesný string se liší
          final normLocalTitle = _normForMatch(song.title);
          final normSharedTitle = _normForMatch(title);
          final normLocalArtist = _normForMatch(song.artist);
          final normSharedArtist = _normForMatch(artist);
          final needsDiacritic = (normLocalTitle == normSharedTitle && song.title != title) ||
              (artist.isNotEmpty && normLocalArtist == normSharedArtist && song.artist != artist);
          if (needsDiacritic && title.isNotEmpty) {
            sharedDiacriticBySongId[song.id] = {'newTitle': title, 'newArtist': artist.isNotEmpty ? artist : song.artist};
          }
          // v3: zarážky – uložit pro pozdější zápis do DB (pouze pokud klíč existoval v JSON)
          final hasKey = (entry['hasStopMarksKey'] as bool?) ?? false;
          if (hasKey) {
            final marks = (entry['stopMarks'] as List<Map<String, dynamic>>?) ?? const [];
            sharedStopMarksBySongId[song.id] = List<Map<String, dynamic>>.from(marks);
          }
          final currentOrder = order++;

          if (isIdentifiedFormat) {
            // 1) Párování výskytu dle occurrenceId – UPDATE bez změny identity.
            PlaylistSong? target;
            String? occurrenceId;
            if (occurrenceIdRaw.isNotEmpty) {
              final existing = rowByOccurrence[occurrenceIdRaw];
              if (existing != null && !consumedRowIds.contains(existing.id)) {
                target = existing;
                occurrenceId = existing.occurrenceId; // identity se NEMĚNÍ
                consumedRowIds.add(existing.id);
              }
            } else {
              // Fallback pro položky bez uid: první dosud nevyužitý řádek
              // stejného songId v rámci tohoto setlistu.
              for (final r in existingRows) {
                if (r.songId == song.id && !consumedRowIds.contains(r.id)) {
                  target = r;
                  occurrenceId = r.occurrenceId;
                  consumedRowIds.add(r.id);
                  break;
                }
              }
            }
            if (target != null) {
              // id si uložíme předem – uvnitř closure se typ target
              // nepropaguje (Dart flow analysis).
              final targetId = target.id;
              await (update(playlistSongs)..where((t) => t.id.equals(targetId)))
                  .write(PlaylistSongsCompanion(
                songId: Value(song.id),
                orderIndex: Value(currentOrder),
                tempo: Value(tempo),
                scrollSpeed: Value(scrollSpeed),
                introDuration: Value(introDuration),
                stopMarksOverride: Value(stopMarksOverride),
              ));
            } else {
              final newOcc =
                  occurrenceIdRaw.isNotEmpty ? occurrenceIdRaw : _newUuidV4();
              await into(playlistSongs).insert(PlaylistSongsCompanion.insert(
                playlistId: playlistId,
                songId: song.id,
                orderIndex: Value(currentOrder),
                tempo: Value(tempo),
                scrollSpeed: Value(scrollSpeed),
                introDuration: Value(introDuration),
                stopMarksOverride: Value(stopMarksOverride),
                occurrenceId: newOcc,
              ));
            }
          } else {
            // Legacy v3/v4 bez identit: vložit první výskyt téže písně
            // (staré chování insertOrIgnore – druhý výskyt bez identity
            // by byl nejednoznačný).
            if (insertedSongIds.add(song.id)) {
              await into(playlistSongs).insert(PlaylistSongsCompanion.insert(
                playlistId: playlistId,
                songId: song.id,
                orderIndex: Value(currentOrder),
                tempo: Value(tempo),
                scrollSpeed: Value(scrollSpeed),
                introDuration: Value(introDuration),
                stopMarksOverride: Value(stopMarksOverride),
                occurrenceId: _newUuidV4(),
              ));
            }
          }
          // content pro existující aktualizujeme po transakci (aktualizovat case 2)
        } else {
          notFound.add(label);
          notFoundLabels.add(label);
        }
      }
      syncCreatedPlaylistId = createdNewPlaylist ? playlistId : null;
      syncPlaylistUid = playlist.playlistUid;
      // Pokud export obsahoval nové písně s content a nenašly se, vytvořit je (volitelně)
      for (final entry in parsedSongs) {
        final label = (entry['artist'] as String).isNotEmpty ? "${entry['artist']} - ${entry['title']}" : entry['title'] as String;
        if (notFound.contains(label) && entry['content'] != null && (entry['content'] as String).trim().isNotEmpty) {
          final title = entry['title'] as String;
          final artist = (entry['artist'] as String).isNotEmpty ? entry['artist'] as String : 'Neznámý interpret';
          final content = entry['content'] as String;
          final duration = entry['duration'] as int?;
          final tempo = entry['tempo'] as double?;
          final scrollSpeed = entry['scrollSpeed'] as double?;
          final fontSize = entry['fontSize'] as double?;
          final introDuration = entry['introDuration'] as double?;
          final occurrenceIdRaw = (entry['occurrenceId'] as String? ?? '').trim();
          final stopMarksOverride = entry['stopMarksOverride'] as bool?;
          // Zkusit vytvořit píseň přes importSongPackage logiku (bez duplikace)
          final created = await _importSongWithContent(title: title, artist: artist, content: content, duration: duration, tempo: tempo, scrollSpeed: scrollSpeed, fontSize: fontSize, introDuration: introDuration);
          if (created != null) {
            final currentOrder = order++;
            if (isIdentifiedFormat) {
              // Stejné párování výskytu jako v první smyčce: occurrenceId
              // v souboru → UPDATE existujícího řádku, jinak INSERT.
              PlaylistSong? target;
              if (occurrenceIdRaw.isNotEmpty) {
                final existing = rowByOccurrence[occurrenceIdRaw];
                if (existing != null && !consumedRowIds.contains(existing.id)) {
                  target = existing;
                  consumedRowIds.add(existing.id);
                }
              }
              if (target != null) {
                final targetId = target.id;
                await (update(playlistSongs)..where((t) => t.id.equals(targetId)))
                    .write(PlaylistSongsCompanion(
                  songId: Value(created.id),
                  orderIndex: Value(currentOrder),
                  tempo: Value(tempo),
                  scrollSpeed: Value(scrollSpeed),
                  introDuration: Value(introDuration),
                  stopMarksOverride: Value(stopMarksOverride),
                ));
              } else {
                final newOcc = occurrenceIdRaw.isNotEmpty
                    ? occurrenceIdRaw
                    : _newUuidV4();
                await into(playlistSongs).insert(PlaylistSongsCompanion.insert(
                  playlistId: playlistId,
                  songId: created.id,
                  orderIndex: Value(currentOrder),
                  tempo: Value(tempo),
                  scrollSpeed: Value(scrollSpeed),
                  introDuration: Value(introDuration),
                  stopMarksOverride: Value(stopMarksOverride),
                  occurrenceId: newOcc,
                ));
              }
            } else {
              if (insertedSongIds.add(created.id)) {
                await into(playlistSongs).insert(PlaylistSongsCompanion.insert(
                    playlistId: playlistId,
                    songId: created.id,
                    orderIndex: Value(currentOrder),
                    tempo: Value(tempo),
                    scrollSpeed: Value(scrollSpeed),
                    introDuration: Value(introDuration),
                    stopMarksOverride: Value(stopMarksOverride),
                    occurrenceId: _newUuidV4()),
                    mode: InsertMode.insertOrIgnore);
              }
            }
            notFound.remove(label);
            matchedCount++;
            matchedIds.add(created.id);
            matchedEntries.add(created);
            // v3: zarážky pro nově vytvořenou píseň
            final hasKey = (entry['hasStopMarksKey'] as bool?) ?? false;
            if (hasKey) {
              final marks = (entry['stopMarks'] as List<Map<String, dynamic>>?) ?? const [];
              for (final m in marks) {
                final lt = (m['lineText'] ?? '').toString();
                final li = m['lineIndex'] as int?;
                final bars = (m['bars'] as int?) ?? 2;
                if (li != null) {
                  await into(stopMarks).insert(StopMarksCompanion.insert(songId: created.id, positionRatio: 0, durationBars: bars, lineIndex: Value(li), lineText: Value(lt.isEmpty ? null : lt)));
                } else if (lt.isNotEmpty) {
                  await into(stopMarks).insert(StopMarksCompanion.insert(songId: created.id, positionRatio: 0, durationBars: bars, lineText: Value(lt)));
                }
              }
            }
          }
        }
      }
    });

    // v3: zapsat zarážky pro již existující písně (přepsat – pokud PC poslal stopMarks, považuje se za zdroj pravdy)
    for (final e in sharedStopMarksBySongId.entries) {
      final songId = e.key;
      final marks = e.value;
      await (delete(stopMarks)..where((t) => t.songId.equals(songId))).go();
      for (final m in marks) {
        final lt = (m['lineText'] ?? '').toString();
        final li = m['lineIndex'] as int?;
        final bars = (m['bars'] as int?) ?? 2;
        if (li != null) {
          await into(stopMarks).insert(StopMarksCompanion.insert(songId: songId, positionRatio: 0, durationBars: bars.clamp(1, 16).toInt(), lineIndex: Value(li), lineText: Value(lt.isEmpty ? null : lt)));
        } else if (lt.isNotEmpty) {
          await into(stopMarks).insert(StopMarksCompanion.insert(songId: songId, positionRatio: 0, durationBars: bars.clamp(1, 16).toInt(), lineText: Value(lt)));
        } else if (marks.isNotEmpty) {
          await into(stopMarks).insert(StopMarksCompanion.insert(songId: songId, positionRatio: 0, durationBars: bars.clamp(1, 16).toInt()));
        }
      }
    }

    // Aktualizovat: přepsat obsah + parametry u existujících písní pokud sdílený balíček obsahuje content/parametry (case 2)
    for (final e in sharedContentBySongId.entries) {
      final songId = e.key;
      final content = e.value;
      try {
        final song = await (select(songs)..where((t) => t.id.equals(songId))).getSingleOrNull();
        if (song != null) {
          await File(song.filePath).writeAsString(content, encoding: utf8);
        }
      } catch (_) {}
    }
    for (final s in matchedEntries) {
      final tempo = sharedTempoBySongId[s.id];
      final ss = sharedScrollSpeedBySongId[s.id];
      final fs = sharedFontSizeBySongId[s.id];
      final intro = sharedIntroBySongId[s.id];
      final dur = sharedDurationBySongId[s.id];
      // tempo zde je playlistTempo – ale pokud byl per-song tempo sdílen a není to override, chceme ho uložit do Songs.tempo pokud dosud null
      // pro aktualizovat chování: pokud sdílené tempo existuje a lokální tempo == null, uložit; pokud už existuje, nepřepisovat tempo pokud byl playlist override?
      // Zjednodušeně: pokud sdílené tempo != null a lokální song.tempo == null, uložit do song.tempo; playlist tempo už je v playlistSongs
      final needSongUpdate = (tempo != null && s.tempo == null) || ss != null || fs != null || intro != null || dur != null;
      if (needSongUpdate) {
        await (update(songs)..where((t) => t.id.equals(s.id))).write(SongsCompanion(
          tempo: tempo != null && s.tempo == null ? Value(tempo) : const Value.absent(),
          customScrollSpeed: ss != null ? Value(ss) : const Value.absent(),
          customFontSize: fs != null ? Value(fs) : const Value.absent(),
          introDuration: intro != null ? Value(intro) : const Value.absent(),
          duration: dur != null ? Value(dur) : const Value.absent(),
        ));
      }
    }

    // Sestavit kandidáty na doplnění
    final durationCandidates = <DurationFixCandidate>[];
    final diacriticCandidates = <DiacriticRepairCandidate>[];
    for (final song in matchedEntries) {
      final sharedDur = sharedDurationBySongId[song.id];
      if (sharedDur != null && (song.duration == null || song.duration == 0)) {
        durationCandidates.add(DurationFixCandidate(
          songId: song.id,
          title: song.title,
          artist: song.artist,
          newDuration: sharedDur,
        ));
      }
      final dia = sharedDiacriticBySongId[song.id];
      if (dia != null) {
        diacriticCandidates.add(DiacriticRepairCandidate(
          songId: song.id,
          currentTitle: song.title,
          currentArtist: song.artist,
          newTitle: dia['newTitle']!,
          newArtist: dia['newArtist']!,
        ));
      }
    }

    return PlaylistSyncResult(
      playlistName: playlistName,
      matchedCount: matchedCount,
      notFound: notFound,
      totalDurationShared: totalDurationShared,
      unknownShared: unknownShared,
      durationCandidates: durationCandidates,
      diacriticCandidates: diacriticCandidates,
      playlistUid: syncPlaylistUid,
      createdNewPlaylist: syncCreatedPlaylistId != null,
      droppedExtrasKeys: droppedKeys.toList()..sort(),
    );
  }

  Future<SongEntry?> _importSongWithContent({required String title, required String artist, required String content, int? duration, double? tempo, double? scrollSpeed, double? fontSize, double? introDuration}) async {
    final existing = await (select(songs)..where((t) => t.title.equals(title) & t.artist.equals(artist))).getSingleOrNull();
    if (existing != null) return null;
    final appDir = await getApplicationDocumentsDirectory();
    final songsDir = Directory(p.join(appDir.path, 'imported_songs'));
    if (!await songsDir.exists()) await songsDir.create(recursive: true);
    final safeArtist = artist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    var fileName = '${safeArtist.isNotEmpty ? '$safeArtist - ' : ''}$safeTitle.txt';
    var filePath = p.join(songsDir.path, fileName);
    var counter = 1;
    while (await File(filePath).exists()) {
      final base = fileName.replaceAll('.txt', '');
      filePath = p.join(songsDir.path, '${base}_$counter.txt');
      counter++;
    }
    await File(filePath).writeAsString(content, encoding: utf8);
    final id = await into(songs).insert(SongsCompanion.insert(
      filePath: filePath,
      artist: artist,
      title: title,
      duration: Value(duration != null && duration > 0 ? duration : null),
      tempo: Value(tempo),
      customScrollSpeed: Value(scrollSpeed),
      customFontSize: Value(fontSize),
      introDuration: Value(introDuration),
    ));
    return (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> applyMissingDurations(List<DurationFixCandidate> candidates) async {
    var count = 0;
    await transaction(() async {
      for (final c in candidates) {
        final res = await (update(songs)..where((t) => t.id.equals(c.songId))).write(SongsCompanion(duration: Value(c.newDuration)));
        if (res > 0) count++;
      }
    });
    return count;
  }

  // --- SLOVNÍK DIAKRITIKY ---
  /// Oddělovače pro kompozitního interpreta: ", ", " a ", " & ", ";", "/", " feat. ", " ft. ", " featuring "
  static final RegExp _artistDelimiter = RegExp(
    r'(\s*,\s*|\s+a\s+|\s+&\s+|\s*;\s*|\s*/\s*|\s+feat\.?\s+|\s+ft\.?\s+|\s+featuring\s+)',
    caseSensitive: false,
  );

  /// Pattern pro "Artist (feat. Host)" – závorková verze
  static final RegExp _featParenPattern = RegExp(
    r'^(.*)\s*\(\s*(feat\.?|ft\.?|featuring)\s+(.+?)\s*\)\s*$',
    caseSensitive: false,
  );

  /// Pattern pro "Artist feat. Host" – bez závorek
  static final RegExp _featBarePattern = RegExp(
    r'^(.*)\s+(feat\.?|ft\.?|featuring)\s+(.+)$',
    caseSensitive: false,
  );

  static String? _lookupSingle(String part, Map<String, String> map) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) return null;
    final key = _normForMatch(trimmed);
    final corrected = map[key];
    if (corrected != null && corrected != trimmed) {
      // obrana proti otrávenému záznamu: např. "Ivan Mladek" -> "Ivan Mladdek"
      if (_normForMatch(corrected) != key) return null;
      return corrected;
    }
    return null;
  }

  /// Aplikuje slovník na kompozitní řetězec (např. "Hana Hegerova, Karel Gott a Waldemar Matuska").
  /// Zachovává původní oddělovače, opravuje jen sub-části nalezené v [map].
  /// Podporuje i "feat." varianty: "Ivan Mladek (feat. Ludek Sobota)" -> "Ivan Mládek (feat. Luděk Sobota)"
  static String? _resolveComposite(String raw, Map<String, String> map) {
    if (raw.trim().isEmpty) return null;
    // rychlá cesta – celý řetězec přímo v mapě (s validací diakritiky)
    final direct = map[_normForMatch(raw)];
    if (direct != null && direct != raw) {
      if (_normForMatch(direct) == _normForMatch(raw)) return direct;
      // otrávený záznam – nebrat v úvahu, pokračovat kompozitní logikou
    }

    // 1) Závorková feat verze: "Hlavní (feat. Host)" – oprav obě části i když host je kompozitní
    final parenMatch = _featParenPattern.firstMatch(raw);
    if (parenMatch != null) {
      final mainPart = parenMatch.group(1)!.trim();
      final featTag = parenMatch.group(2)!.trim(); // "feat." / "ft." / "featuring"
      final featPart = parenMatch.group(3)!.trim();
      if (mainPart.isNotEmpty && featPart.isNotEmpty) {
        // hlavní interpret může být sám kompozitní (",", " a ", atd.)
        String? fixedMain = _lookupSingle(mainPart, map) ?? _resolveCompositeInner(mainPart, map);
        String? fixedFeat = _lookupSingle(featPart, map) ?? _resolveCompositeInner(featPart, map);
        // pokud ani jedno neopravitelné, zkus rekurzi na celé části
        fixedMain ??= (mainPart != raw ? null : null); // placeholder, fixedMain již je null pokud neopraveno
        // efektivně: pokud nenalezeno, ponech původní
        final newMain = fixedMain ?? mainPart;
        final newFeat = fixedFeat ?? featPart;
        if (newMain != mainPart || newFeat != featPart) {
          // normalizuj tag na "feat." pro konzistenci, ale zachovej původní variantu pokud je "featuring"
          final normalizedTag = featTag.toLowerCase().startsWith('featuring') ? 'featuring' : featTag.toLowerCase().contains('ft') && !featTag.toLowerCase().contains('fea') ? 'ft.' : 'feat.';
          // zachovej původní tečku? použij normalizedTag
          return '$newMain ($normalizedTag $newFeat)';
        }
      }
    }

    // 2) Bare feat verze bez závorek: "Hlavní feat. Host" – zachytí i delimiter fallback
    final bareMatch = _featBarePattern.firstMatch(raw);
    if (bareMatch != null) {
      final mainPart = bareMatch.group(1)!.trim();
      final featTag = bareMatch.group(2)!.trim();
      final featPart = bareMatch.group(3)!.trim();
      if (mainPart.isNotEmpty && featPart.isNotEmpty) {
        String? fixedMain = _lookupSingle(mainPart, map) ?? _resolveCompositeInner(mainPart, map);
        String? fixedFeat = _lookupSingle(featPart, map) ?? _resolveCompositeInner(featPart, map);
        final newMain = fixedMain ?? mainPart;
        final newFeat = fixedFeat ?? featPart;
        if (newMain != mainPart || newFeat != featPart) {
          final normalizedTag = featTag.toLowerCase().startsWith('featuring') ? 'featuring' : featTag.toLowerCase().contains('ft') && !featTag.toLowerCase().contains('fea') ? 'ft.' : 'feat.';
          return '$newMain $normalizedTag $newFeat';
        }
      }
    }

    if (!_artistDelimiter.hasMatch(raw)) return direct;
    final resolved = raw.splitMapJoin(
      _artistDelimiter,
      onMatch: (m) => m.group(0)!,
      onNonMatch: (part) {
        if (part.trim().isEmpty) return part;
        // zkus přímý lookup, jinak rekurzi pro feat uvnitř části (např. "A (feat. B)")
        final subFeat = _resolveComposite(part.trim(), map);
        if (subFeat != null) return subFeat;
        final corrected = map[_normForMatch(part)];
        if (corrected != null && corrected != part) {
          if (_normForMatch(corrected) != _normForMatch(part)) return part;
          return corrected;
        }
        return part;
      },
    );
    return resolved != raw ? resolved : null;
  }

  /// Vnitřní helper pro kompozit bez feat-paren rekurze (zabrání cyklu).
  static String? _resolveCompositeInner(String raw, Map<String, String> map) {
    if (raw.trim().isEmpty) return null;
    if (!_artistDelimiter.hasMatch(raw)) return null;
    final resolved = raw.splitMapJoin(
      _artistDelimiter,
      onMatch: (m) => m.group(0)!,
      onNonMatch: (part) {
        if (part.trim().isEmpty) return part;
        final corrected = map[_normForMatch(part)];
        if (corrected != null && corrected != part) {
          if (_normForMatch(corrected) != _normForMatch(part)) return part;
          return corrected;
        }
        return part;
      },
    );
    return resolved != raw ? resolved : null;
  }

  /// Vyhledá opravený zápis ve slovníku (podle textu bez diakritiky).
  /// Podporuje kompozitní interprety – opraví po částech, včetně "feat.".
  Future<String?> lookupDiacritic(String rawText) async {
    final key = _normForMatch(rawText);
    if (key.isEmpty) return null;
    final row = await (select(diacriticMappings)..where((t) => t.normKey.equals(key))).getSingleOrNull();
    if (row != null) {
      if (_normForMatch(row.corrected) != key) return null;
      return row.corrected;
    }
    // kompozit: "Hana Hegerova, Karel Gott a Waldemar Matuska" nebo "Ivan Mladek (feat. Ludek Sobota)"
    final isComposite = _artistDelimiter.hasMatch(rawText) ||
        _featParenPattern.hasMatch(rawText) ||
        _featBarePattern.hasMatch(rawText);
    if (!isComposite) return null;
    final mappings = await select(diacriticMappings).get();
    final map = {for (final m in mappings) m.normKey: m.corrected};
    if (map.isEmpty) return null;
    return _resolveComposite(rawText, map);
  }

  /// Naučí slovník dvojici [raw] -> [corrected] (např. z ruční opravy písně).
  /// Pro kompozitní interprety ("A, B a C") učí po částech, včetně "feat.".
  /// Odmítá páry, kde se liší i písmena (překlep), nejen diakritika – např. Mladek -> Mladdek.
  Future<void> learnDiacritic(String raw, String corrected) async {
    if (!_isDiacriticOnly(raw, corrected) && !_artistDelimiter.hasMatch(raw) && !_featParenPattern.hasMatch(raw) && !_featBarePattern.hasMatch(raw)) {
      // rychlá validace pro jednoduchý případ – pokud mění i písmena, odmítnout
      // kompozitní případy se validují po rozdělení níže
      final simpleKey = _normForMatch(raw);
      final simpleValNorm = _normForMatch(corrected);
      if (simpleKey.isNotEmpty && simpleValNorm.isNotEmpty && simpleKey != simpleValNorm) {
        // může to být kompozit s různými oddělovači – nech projít k další logice, která rozseká
        if (!_artistDelimiter.hasMatch(corrected) && !_featParenPattern.hasMatch(corrected) && !_featBarePattern.hasMatch(corrected)) {
          return;
        }
      }
    }
    // Speciálně pro feat závorkovou verzi: uč hlavní a hosta zvlášť
    final rawFeatParen = _featParenPattern.firstMatch(raw);
    final corrFeatParen = _featParenPattern.firstMatch(corrected);
    if (rawFeatParen != null && corrFeatParen != null) {
      final rMain = rawFeatParen.group(1)!.trim();
      final cMain = corrFeatParen.group(1)!.trim();
      final rFeat = rawFeatParen.group(3)!.trim();
      final cFeat = corrFeatParen.group(3)!.trim();
      if (rMain.isNotEmpty && cMain.isNotEmpty && rMain != cMain) {
        await learnDiacritic(rMain, cMain);
      } else if (rMain.isNotEmpty && cMain.isNotEmpty && _artistDelimiter.hasMatch(rMain)) {
        await learnDiacritic(rMain, cMain);
      }
      if (rFeat.isNotEmpty && cFeat.isNotEmpty && rFeat != cFeat) {
        await learnDiacritic(rFeat, cFeat);
      } else if (rFeat.isNotEmpty && cFeat.isNotEmpty && _artistDelimiter.hasMatch(rFeat)) {
        await learnDiacritic(rFeat, cFeat);
      }
      // pokud obě části naučeny, není třeba učit celek
      if (rMain != cMain || rFeat != cFeat) return;
    }
    final rawFeatBare = _featBarePattern.firstMatch(raw);
    final corrFeatBare = _featBarePattern.firstMatch(corrected);
    if (rawFeatBare != null && corrFeatBare != null) {
      final rMain = rawFeatBare.group(1)!.trim();
      final cMain = corrFeatBare.group(1)!.trim();
      final rFeat = rawFeatBare.group(3)!.trim();
      final cFeat = corrFeatBare.group(3)!.trim();
      if (rMain.isNotEmpty && cMain.isNotEmpty && rMain != cMain) {
        await learnDiacritic(rMain, cMain);
      }
      if (rFeat.isNotEmpty && cFeat.isNotEmpty && rFeat != cFeat) {
        await learnDiacritic(rFeat, cFeat);
      }
      if (rMain != cMain || rFeat != cFeat) return;
    }

    // Pokud oba obsahují stejný počet delimiterů, uč po částech
    if (_artistDelimiter.hasMatch(raw) || _artistDelimiter.hasMatch(corrected)) {
      final rawParts = raw.split(_artistDelimiter);
      final corrParts = corrected.split(_artistDelimiter);
      if (rawParts.length == corrParts.length && rawParts.length > 1) {
        for (var i = 0; i < rawParts.length; i++) {
          final r = rawParts[i].trim();
          final c = corrParts[i].trim();
          if (r.isEmpty || c.isEmpty) continue;
          if (!_isDiacriticOnly(r, c)) continue;
          final k = _normForMatch(r);
          if (k.isEmpty || k == c.toLowerCase().trim()) continue;
          // přeskočit "Karel Gott" -> "Karel Gott" beze změny
          if (r == c) continue;
          await into(diacriticMappings).insert(
            DiacriticMappingsCompanion.insert(normKey: k, corrected: c),
            mode: InsertMode.insertOrReplace,
          );
        }
        return;
      }
    }
    final key = _normForMatch(raw);
    final value = corrected.trim();
    if (key.isEmpty || value.isEmpty || key == value.toLowerCase().trim()) return;
    if (!_isDiacriticOnly(raw, value)) return;
    if (raw.trim() == value) return;
    await into(diacriticMappings).insert(
      DiacriticMappingsCompanion.insert(normKey: key, corrected: value),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<int> getDiacriticCount() async {
    final countExp = diacriticMappings.normKey.count();
    final query = selectOnly(diacriticMappings)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Smaže otrávené záznamy, kde se liší i písmena (ne jen diakritika).
  /// Vrací počet smazaných.
  Future<int> purgeInvalidDiacriticMappings() async {
    final all = await select(diacriticMappings).get();
    var deleted = 0;
    for (final m in all) {
      if (_normForMatch(m.corrected) != m.normKey) {
        await (delete(diacriticMappings)..where((t) => t.normKey.equals(m.normKey))).go();
        deleted++;
      }
    }
    return deleted;
  }

  /// Najde písně, jejichž název/interpret má ve slovníku opravenou verzi.
  /// Podporuje kompozitní interprety (",", " a ", " & ", ";", "/") pouze pro interpreta.
  Future<List<DiacriticRepairCandidate>> findDiacriticRepairs() async {
    final all = await select(songs).get();
    final mappings = await select(diacriticMappings).get();
    // filtruj otrávené záznamy, aby se nikdy nenavrhla oprava typu Mladek->Mladdek
    final map = <String, String>{};
    for (final m in mappings) {
      if (_normForMatch(m.corrected) != m.normKey) continue;
      map[m.normKey] = m.corrected;
    }
    if (map.isEmpty) return const [];
    final result = <DiacriticRepairCandidate>[];
    for (final s in all) {
      final directTitleRaw = map[_normForMatch(s.title)];
      final compositeArtist = _resolveComposite(s.artist, map);
      final directArtistRaw = map[_normForMatch(s.artist)];
      // tituly se opravují pouze přímou shodou; kompozitní logika jen pro interpreta
      // validace: navržená oprava musí být diakriticky shodná
      final resolvedTitle = (directTitleRaw != null && _normForMatch(directTitleRaw) == _normForMatch(s.title)) ? directTitleRaw : null;
      String? resolvedArtist;
      if (compositeArtist != null && _normForMatch(compositeArtist) == _normForMatch(s.artist)) {
        resolvedArtist = compositeArtist;
      } else if (directArtistRaw != null && _normForMatch(directArtistRaw) == _normForMatch(s.artist)) {
        resolvedArtist = directArtistRaw;
      }
      final changedTitle = resolvedTitle != null && resolvedTitle != s.title;
      final changedArtist = resolvedArtist != null && resolvedArtist != s.artist;
      if (!changedTitle && !changedArtist) continue;
      result.add(DiacriticRepairCandidate(
        songId: s.id,
        currentTitle: s.title,
        currentArtist: s.artist,
        newTitle: changedTitle ? resolvedTitle! : s.title,
        newArtist: changedArtist ? resolvedArtist! : s.artist,
      ));
    }
    return result;
  }

  /// Vrátí písně bez návrhu opravy s důvodem (pro výpis 23→21).
  Future<List<DiacriticUnrepairedEntry>> getDiacriticUnrepairedWithReason() async {
    final all = await select(songs).get();
    final mappings = await select(diacriticMappings).get();
    final map = {for (final m in mappings) m.normKey: m.corrected};
    final repairedIds = (await findDiacriticRepairs()).map((e) => e.songId).toSet();
    final result = <DiacriticUnrepairedEntry>[];
    for (final s in all) {
      if (repairedIds.contains(s.id)) continue;
      final normTitle = _normForMatch(s.title);
      final normArtist = _normForMatch(s.artist);
      final hasTitleDiacritic = _stripDiacritics(s.title) != s.title;
      final hasArtistDiacritic = _stripDiacritics(s.artist) != s.artist;
      final titleInMap = map.containsKey(normTitle);
      final artistInMap = map.containsKey(normArtist) || _resolveComposite(s.artist, map) != null;
      String reason;
      if ((hasTitleDiacritic || hasArtistDiacritic) && !titleInMap && !artistInMap) {
        // má háčky, ale není v mapě – považujeme za už správně (nebo chybí jiný tvar)
        // pokud map neobsahuje norm, ale text už má diakritiku, nespravujeme
        reason = 'alreadyCorrect';
      } else if (!titleInMap && !artistInMap) {
        // bez háčků a není v mapě
        final isComposite = _artistDelimiter.hasMatch(s.artist) ||
            _featParenPattern.hasMatch(s.artist) ||
            _featBarePattern.hasMatch(s.artist);
        reason = isComposite ? 'compositeNoMatch' : 'missingInMap';
      } else {
        // v mapě je, ale current == corrected (už opraveno)
        reason = 'alreadyCorrect';
      }
      // upřesnění: pokud už má diakritiku a map by vracel stejný text, je to alreadyCorrect
      result.add(DiacriticUnrepairedEntry(
        song: s,
        reason: reason,
        normTitle: normTitle,
        normArtist: normArtist,
      ));
    }
    return result;
  }

  /// Aplikuje potvrzené hromadné opravy diakritiky.
  /// Pokud [renameFiles] je true, pokusí se přejmenovat i soubory na disku (volitelně kvůli Windows).
  Future<DiacriticRepairResult> applyDiacriticRepairs(
    List<DiacriticRepairCandidate> candidates, {
    bool renameFiles = false,
  }) async {
    var dbCount = 0;
    // Uložit původní cesty před transakcí pro případné přejmenování
    final Map<int, SongEntry> byId = {};
    if (renameFiles && candidates.isNotEmpty) {
      final all = await select(songs).get();
      for (final s in all) {
        byId[s.id] = s;
      }
    }
    await transaction(() async {
      for (final c in candidates) {
        final res = await (update(songs)..where((t) => t.id.equals(c.songId))).write(
          SongsCompanion(title: Value(c.newTitle), artist: Value(c.newArtist)),
        );
        if (res > 0) dbCount++;
      }
    });
    if (!renameFiles) {
      return DiacriticRepairResult(dbUpdated: dbCount);
    }
    // Volitelné přejmenování souborů – mimo transakci, odolné vůči Windows zámkům
    var renamed = 0;
    var failed = 0;
    final failedPaths = <String>[];
    for (final c in candidates) {
      final song = byId[c.songId];
      if (song == null) continue;
      // přeskočit pokud se název nezměnil (nemělo by nastat, ale defenzivně)
      if (c.newTitle == song.title && c.newArtist == song.artist) continue;
      try {
        final oldFile = File(song.filePath);
        if (!await oldFile.exists()) continue;
        final dir = p.dirname(song.filePath);
        final safeArtist = c.newArtist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
        final safeTitle = c.newTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
        var newFileName = '${safeArtist.isNotEmpty ? '$safeArtist - ' : ''}$safeTitle.txt';
        var newPath = p.join(dir, newFileName);
        // Windows MAX_PATH ochrana – ořez názvu
        if (newPath.length > 240) {
          final ext = '.txt';
          final maxBase = 240 - dir.length - ext.length - 1;
          if (maxBase > 10) {
            newFileName = newFileName.substring(0, maxBase) + ext;
            newPath = p.join(dir, newFileName);
          }
        }
        var counter = 1;
        while (newPath != song.filePath && await File(newPath).exists()) {
          final base = newFileName.replaceAll('.txt', '');
          newPath = p.join(dir, '${base}_$counter.txt');
          counter++;
        }
        if (newPath != song.filePath) {
          await oldFile.rename(newPath);
          await (update(songs)..where((t) => t.id.equals(c.songId))).write(SongsCompanion(filePath: Value(newPath)));
          renamed++;
        }
      } catch (_) {
        failed++;
        failedPaths.add(song.filePath);
      }
    }
    return DiacriticRepairResult(
      dbUpdated: dbCount,
      filesRenamed: renamed,
      filesFailed: failed,
      failedPaths: failedPaths,
    );
  }

  /// (B) Kompatibilita: aplikace oprav z playlist syncu (DiacriticFixCandidate).
  Future<DiacriticRepairResult> applyDiacriticFixes(
    List<DiacriticFixCandidate> candidates, {
    bool renameFiles = false,
  }) async {
    // Deleguje na Repair variantu přes konverzi - sjednocené chování (A+B)
    return applyDiacriticRepairs(candidates.map((c) => c.toRepair()).toList(), renameFiles: renameFiles);
  }

  /// Zpětná kompatibilita pro volání očekávající int (vrací dbUpdated).
  Future<int> applyDiacriticRepairsLegacy(List<DiacriticRepairCandidate> candidates) async {
    final r = await applyDiacriticRepairs(candidates);
    return r.dbUpdated;
  }

  Future<String> exportDiacriticCsv() async {
    final rows = await select(diacriticMappings).get();
    final buffer = StringBuffer();
    // Přidání UTF-8 BOM pro správnou interpretaci v Excelu
    buffer.write('\uFEFF');
    buffer.writeln('bezDiakritiky,sDiakritikou');
    String escape(String s) => s.replaceAll('"', '""');
    for (final r in rows) {
      buffer.writeln('"${escape(r.normKey)}","${escape(r.corrected)}"');
    }
    return buffer.toString();
  }

  Future<DiacriticCsvImportResult> importDiacriticCsv(String csvContent) async {
    final content = csvContent.startsWith('\uFEFF') ? csvContent.substring(1) : csvContent;
    final lines = content.split(RegExp(r'\r?\n'));
    int count = 0;
    int skipped = 0;
    final errors = <String>[];
    await transaction(() async {
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = _parseDiacriticCsvLine(line);
        if (parts.length < 2) {
          skipped++;
          errors.add('ř.${i + 1}: $line');
          continue;
        }
        final key = _normForMatch(parts[0].split(';').first.trim());
        var rawValue = parts[1].trim();
        // Defenzivně ořež trailing artefakty z českého Excelu (oddělovač ; a zbytečné ))
        // a případný duplicitní obsah za středníkem: "Ivan Mládek;Ivan Mládek" -> "Ivan Mládek"
        if (rawValue.contains(';')) rawValue = rawValue.split(';').first.trim();
        rawValue = rawValue.replaceAll(RegExp(r'[;\)]+$'), '').trim();
        rawValue = rawValue.replaceAll(RegExp(r'^"+|"+$'), '').trim();
        final value = rawValue;
        if (key.isEmpty || value.isEmpty || key == value.toLowerCase().trim()) {
          skipped++;
          continue;
        }
        if (_normForMatch(value) != key) {
          skipped++;
          errors.add('ř.${i + 1}: odmítnuto (překlep, liší se písmena) $key -> $value');
          continue;
        }
        await into(diacriticMappings).insert(
          DiacriticMappingsCompanion.insert(normKey: key, corrected: value),
          mode: InsertMode.insertOrReplace,
        );
        count++;
      }
    });
    return DiacriticCsvImportResult(imported: count, skipped: skipped, errors: errors);
  }

  Future<int> createPlaylist(String name) => into(playlists).insert(
      PlaylistsCompanion.insert(name: name, playlistUid: _newUuidV4()));
  
  Future<List<Playlist>> getAllPlaylists() => select(playlists).get();
  Future<int> deletePlaylist(int id) => (delete(playlists)..where((t) => t.id.equals(id))).go();
  Future<int> renamePlaylist(int id, String newName) =>
      (update(playlists)..where((t) => t.id.equals(id))).write(PlaylistsCompanion(name: Value(newName)));
  Future<int> addSongToPlaylist(int playlistId, int songId) async {
    // Zachování starého chování (dříve InsertMode.insertOrIgnore nad
    // kompozitním PK): píseň, která už v setlistu je, se znovu nepřidá.
    final alreadyThere = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId)))
        .getSingleOrNull();
    if (alreadyThere != null) return 0;
    final lastEntry = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.desc(t.orderIndex)])
          ..limit(1))
        .getSingleOrNull();
    final nextIndex = (lastEntry?.orderIndex ?? -1) + 1;
    return into(playlistSongs).insert(
        PlaylistSongsCompanion.insert(
            playlistId: playlistId,
            songId: songId,
            orderIndex: Value(nextIndex),
            occurrenceId: _newUuidV4()),
        mode: InsertMode.insertOrIgnore);
  }

  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    final lastEntry = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.desc(t.orderIndex)])
          ..limit(1))
        .getSingleOrNull();
    
    int nextIndex = (lastEntry?.orderIndex ?? -1) + 1;

    // Zachování starého chování (dříve insertOrIgnore nad kompozitním PK):
    // duplicity proti stávajícím řádkům i uvnitř vstupu se přeskočí.
    final present = (await (select(playlistSongs)
              ..where((t) => t.playlistId.equals(playlistId)))
            .get())
        .map((r) => r.songId)
        .toSet();

    await batch((batch) {
      for (final songId in songIds) {
        final order = nextIndex++;
        if (!present.add(songId)) continue;
        batch.insert(
          playlistSongs,
          PlaylistSongsCompanion.insert(
            playlistId: playlistId,
            songId: songId,
            orderIndex: Value(order),
            occurrenceId: _newUuidV4(),
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

  Future<void> clearCustomStrings() async {
    await delete(customStrings).go();
  }

  Future<void> movePlaylistSong(int playlistId, int songId, int newOrderIndex) async {
    await transaction(() async {
      final all = await (select(playlistSongs)
            ..where((t) => t.playlistId.equals(playlistId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();
      final curIdx = all.indexWhere((e) => e.songId == songId);
      if (curIdx == -1) return;
      final item = all.removeAt(curIdx);
      final target = newOrderIndex.clamp(0, all.length).toInt();
      all.insert(target, item);
      for (var i = 0; i < all.length; i++) {
        await (update(playlistSongs)
              ..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(all[i].songId)))
            .write(PlaylistSongsCompanion(orderIndex: Value(i)));
      }
    });
  }

  /// Vrátí seřazené odkazy na výskyty písní v setlistu (etapa E1).
  Future<List<PlaylistOccurrenceRef>> getPlaylistOccurrences(int playlistId) async {
    final rows = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
        .get();
    return rows.map((r) => PlaylistOccurrenceRef(
          playlistSongId: r.id,
          songId: r.songId,
          occurrenceId: r.occurrenceId,
        )).toList();
  }

  Stream<List<SongEntry>> watchSongsInPlaylist(int playlistId) {

    final query = select(songs).join([innerJoin(playlistSongs, playlistSongs.songId.equalsExp(songs.id))])
      ..where(playlistSongs.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistSongs.orderIndex)]);
    return query.watch().map((rows) => rows.map((row) => row.readTable(songs)).toList());
  }

  /// Stream pro setlist včetně per-song tempa (null = globální).
  Stream<List<PlaylistSongWithTempo>> watchSongsWithTempoInPlaylist(int playlistId) {
    final query = select(songs).join([innerJoin(playlistSongs, playlistSongs.songId.equalsExp(songs.id))])
      ..where(playlistSongs.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistSongs.orderIndex)]);
    return query.watch().map((rows) => rows.map((row) {
          final song = row.readTable(songs);
          final ps = row.readTable(playlistSongs);
          return PlaylistSongWithTempo(
            playlistSongId: ps.id,
            song: song,
            playlistTempo: ps.tempo,
            orderIndex: ps.orderIndex,
            occurrenceId: ps.occurrenceId,
            scrollSpeed: ps.scrollSpeed,
            introDuration: ps.introDuration,
            stopMarksOverride: ps.stopMarksOverride,
          );
        }).toList());
  }

  Future<List<PlaylistSongWithTempo>> getPlaylistSongsWithTempo(int playlistId) async {
    final query = select(songs).join([innerJoin(playlistSongs, playlistSongs.songId.equalsExp(songs.id))])
      ..where(playlistSongs.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistSongs.orderIndex)]);
    final rows = await query.get();
    return rows.map((row) {
      final song = row.readTable(songs);
      final ps = row.readTable(playlistSongs);
      return PlaylistSongWithTempo(
        playlistSongId: ps.id,
        song: song,
        playlistTempo: ps.tempo,
        orderIndex: ps.orderIndex,
        occurrenceId: ps.occurrenceId,
        scrollSpeed: ps.scrollSpeed,
        introDuration: ps.introDuration,
        stopMarksOverride: ps.stopMarksOverride,
      );
    }).toList();
  }

  /// Odstraní konkrétní výskyt písně v setlistu podle playlistSongs.id (etapa E2).
  Future<int> removePlaylistSongRow(int playlistSongId) async {
    return transaction(() async {
      // 1. Zjistíme playlistId a orderIndex mazaného řádku, abychom mohli znormalizovat zbytek
      final row = await (select(playlistSongs)..where((t) => t.id.equals(playlistSongId))).getSingleOrNull();
      if (row == null) return 0;
      final pid = row.playlistId;

      final count = await (delete(playlistSongs)..where((t) => t.id.equals(playlistSongId))).go();

      // Normalizace orderIndex zbývajících položek
      await _normalizePlaylistOrder(pid);
      return count;
    });
  }

  /// Prohodí nebo posune konkrétní řádek nahoru/dolů (etapa E2).
  Future<void> reorderPlaylistSongRow(int playlistSongId, bool moveUp) async {
    return transaction(() async {
      final rows = await (select(playlistSongs)
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .get();
      
      final index = rows.indexWhere((r) => r.id == playlistSongId);
      if (index == -1) return;
      final targetIndex = moveUp ? index - 1 : index + 1;
      if (targetIndex < 0 || targetIndex >= rows.length) return;

      // Prohodíme položky v lokálním seznamu
      final temp = rows[index];
      rows[index] = rows[targetIndex];
      rows[targetIndex] = temp;

      // Uložíme nový deterministický orderIndex (0, 1, 2, ...)
      for (int i = 0; i < rows.length; i++) {
        await (update(playlistSongs)..where((t) => t.id.equals(rows[i].id)))
            .write(PlaylistSongsCompanion(orderIndex: Value(i)));
      }
    });
  }

  /// Přesune konkrétní řádek na novou pozici [newOrderIndex] (etapa E2).
  Future<void> movePlaylistSongRow(int playlistSongId, int newOrderIndex) async {
    return transaction(() async {
      final rows = await (select(playlistSongs)
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .get();

      final index = rows.indexWhere((r) => r.id == playlistSongId);
      if (index == -1) return;

      final item = rows.removeAt(index);
      final clampedIndex = newOrderIndex.clamp(0, rows.length);
      rows.insert(clampedIndex, item);

      for (int i = 0; i < rows.length; i++) {
        await (update(playlistSongs)..where((t) => t.id.equals(rows[i].id)))
            .write(PlaylistSongsCompanion(orderIndex: Value(i)));
      }
    });
  }

  Future<double?> getPlaylistSongTempoById(int playlistSongId) async {
    final row = await (select(playlistSongs)..where((t) => t.id.equals(playlistSongId))).getSingleOrNull();
    return row?.tempo;
  }

  Future<int> updatePlaylistSongTempoById(int playlistSongId, double? tempo) =>
      (update(playlistSongs)..where((t) => t.id.equals(playlistSongId)))
          .write(PlaylistSongsCompanion(tempo: Value(tempo)));

  /// Pomocná metoda pro normalizaci orderIndex v playlistu (etapa E2).
  Future<void> _normalizePlaylistOrder(int playlistId) async {
    final rows = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
        .get();

    for (int i = 0; i < rows.length; i++) {
      if (rows[i].orderIndex != i) {
        await (update(playlistSongs)..where((t) => t.id.equals(rows[i].id)))
            .write(PlaylistSongsCompanion(orderIndex: Value(i)));
      }
    }
  }

  Future<double?> getPlaylistSongTempo(int playlistId, int songId) async {
    final row = await (select(playlistSongs)..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId))).getSingleOrNull();
    return row?.tempo;
  }

  Future<Map<int, double?>> getPlaylistTemposMap(int playlistId) async {
    final rows = await (select(playlistSongs)..where((t) => t.playlistId.equals(playlistId))).get();
    return {for (final r in rows) r.songId: r.tempo};
  }

  Future<int> updatePlaylistSongTempo(int playlistId, int songId, double? tempo) =>
      (update(playlistSongs)..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId)))
          .write(PlaylistSongsCompanion(tempo: Value(tempo)));

  // --- ZÁLOHA A OBNOVENÍ ---
  Future<Map<String, dynamic>> exportToJson() async {
    final allSongs = await getAllSongs();
    final allPlaylists = await getAllPlaylists();
    final allStopMarks = await select(stopMarks).get();
    final allPlaylistSongs = await select(playlistSongs).get();
    final allDiacritic = await select(diacriticMappings).get();
    final allCustom = await select(customStrings).get();

    return {
      'version': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'songs': allSongs.map((s) => s.toJson()).toList(),
      'playlists': allPlaylists.map((p) => p.toJson()).toList(),
      'stopMarks': allStopMarks.map((sm) => sm.toJson()).toList(),
      'playlistSongs': allPlaylistSongs.map((ps) => ps.toJson()).toList(),
      'diacriticMappings': allDiacritic.map((r) => r.toJson()).toList(),
      'customStrings': allCustom.map((r) => r.toJson()).toList(),
    };
  }

  /// Export včetně obsahu txt souborů pro úplnou obnovu po vyčištění.
  Future<Map<String, dynamic>> exportToJsonWithContents() async {
    final base = await exportToJson();
    final List songs = base['songs'] as List;
    for (final s in songs) {
      if (s is Map<String, dynamic>) {
        final path = (s['filePath'] ?? '').toString();
        if (path.isNotEmpty) {
          try {
            final file = File(path);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              String content;
              try {
                content = utf8.decode(bytes);
              } catch (_) {
                content = latin1.decode(bytes);
              }
              s['content'] = content;
            }
          } catch (_) {}
        }
      }
    }
    return base;
  }

  Future<void> importFromJson(Map<String, dynamic> data) async {
    // Ochrana proti záměně formátů (T-13F): importFromJson je PLNÁ záloha
    // (v12/v13) a v transakci maže celou knihovnu. Setlist (formát v5,
    // `type: playlist`) se takto importovat NESMÍ – jinak by smazal songs
    // i playlists a místo setlistu vytvořil prázdnou databázi.
    if (data['type'] == 'playlist' || data['playlists'] == null) {
      throw const FormatException(
          'Nejde o plnou zálohu databáze (chybí seznam playlists). '
          'Toto je soubor setlistu – importuj jej v PlaylistsPage '
          '(synchronizace setlistu), nikoli jako zálohu.');
    }
    // Zachytit cesty pro obnovu souborů před transakcí
    final List<dynamic> rawSongs = (data['songs'] as List?) ?? const [];
    await transaction(() async {
      await delete(playlistSongs).go();
      await delete(stopMarks).go();
      await delete(playlists).go();
      await delete(songs).go();
      try { await delete(diacriticMappings).go(); } catch (_) {}
      try { await delete(customStrings).go(); } catch (_) {}

      for (final s in data['songs']) {
        final map = Map<String, dynamic>.from(s as Map);
        map.remove('content');
        await into(songs).insert(SongEntry.fromJson(map));
      }
      for (final p in data['playlists'] ?? const []) {
        final map = Map<String, dynamic>.from(p as Map);
        // Zálohy v12 neobsahují playlistUid – doplníme nové, aby obnova
        // staré zálohy po migraci fungovala (v13 již jinak nelze řádek vložit).
        final rawUid =
            (map['playlistUid'] ?? map['playlist_uid'] ?? '').toString().trim();
        await into(playlists).insert(PlaylistsCompanion.insert(
              id: map['id'] is int ? Value(map['id'] as int) : const Value.absent(),
              name: (map['name'] ?? '').toString(),
              playlistUid: rawUid.isEmpty ? _newUuidV4() : rawUid,
            ));
      }
      for (final sm in data['stopMarks'] ?? const []) {
        await into(stopMarks).insert(StopMark.fromJson(Map<String, dynamic>.from(sm as Map)));
      }
      for (final ps in data['playlistSongs'] ?? const []) {
        final map = Map<String, dynamic>.from(ps as Map);
        // Zálohy v12 nemají id/occurrenceId – id přidělí SQLite (autoincrement),
        // occurrenceId vygenerujeme; nové zálohy si zachovají oba údaje.
        final rawOcc =
            (map['occurrenceId'] ?? map['occurrence_id'] ?? '').toString().trim();
        await into(playlistSongs).insert(PlaylistSongsCompanion.insert(
              id: map['id'] is int ? Value(map['id'] as int) : const Value.absent(),
              playlistId: (map['playlistId'] as num).toInt(),
              songId: (map['songId'] as num).toInt(),
              orderIndex: Value((map['orderIndex'] as num?)?.toInt() ?? 0),
              tempo: Value((map['tempo'] as num?)?.toDouble()),
              occurrenceId: rawOcc.isEmpty ? _newUuidV4() : rawOcc,
            ));
      }
      if (data['diacriticMappings'] is List) {
        for (final r in data['diacriticMappings'] as List) {
          try {
            await into(diacriticMappings).insert(DiacriticMappingEntry.fromJson(Map<String, dynamic>.from(r as Map)), mode: InsertMode.insertOrReplace);
          } catch (_) {}
        }
      }
      if (data['customStrings'] is List) {
        for (final r in data['customStrings'] as List) {
          try {
            await into(customStrings).insert(CustomString.fromJson(Map<String, dynamic>.from(r as Map)), mode: InsertMode.insertOrReplace);
          } catch (_) {}
        }
      }
    });
    // Obnova souborů mimo transakci - obsah je v původních rawSongs
    for (final s in rawSongs) {
      if (s is! Map) continue;
      final map = Map<String, dynamic>.from(s as Map);
      final content = map['content'] as String?;
      final path = (map['filePath'] ?? '').toString();
      if (content == null || path.isEmpty) continue;
      try {
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsString(content, encoding: utf8);
      } catch (_) {}
    }
  }

  /// Vyčistí celou knihovnu (vše dle požadavku). Volitelně smaže i soubory.
  Future<void> clearLibrary({bool deleteFiles = true}) async {
    List<String> filePaths = [];
    if (deleteFiles) {
      try {
        final all = await getAllSongs();
        filePaths = all.map((s) => s.filePath).toList();
      } catch (_) {}
    }
    await transaction(() async {
      await delete(playlistSongs).go();
      await delete(stopMarks).go();
      await delete(playlists).go();
      await delete(songs).go();
      try { await delete(diacriticMappings).go(); } catch (_) {}
      try { await delete(customStrings).go(); } catch (_) {}
    });
    if (deleteFiles) {
      for (final pth in filePaths) {
        try {
          final f = File(pth);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  // --- UNDO ZÁLOHA PRO VYČIŠTĚNÍ (7 dní) ---
  static const _clearBackupDirName = 'backups';
  static const _clearBackupPrefix = 'undo_clear_';
  static const _clearBackupRetentionDays = 7;

  Future<Directory> _getClearBackupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _clearBackupDirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> createClearUndoBackup(Map<String, dynamic> data) async {
    final dir = await _getClearBackupDir();
    final ts = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${ts.year}${two(ts.month)}${two(ts.day)}_${two(ts.hour)}${two(ts.minute)}${two(ts.second)}';
    final file = File(p.join(dir.path, '$_clearBackupPrefix$stamp.json'));
    await file.writeAsString(jsonEncode(data), encoding: utf8);
    await purgeExpiredClearBackups();
    // rotace: držet max 5 souborů
    try {
      final files = (await dir.list().toList()).whereType<File>().where((f) => p.basename(f.path).startsWith(_clearBackupPrefix)).toList();
      files.sort((a, b) => b.path.compareTo(a.path));
      for (var i = 5; i < files.length; i++) {
        try { await files[i].delete(); } catch (_) {}
      }
    } catch (_) {}
    return file.path;
  }

  Future<Map<String, dynamic>?> loadLastClearBackup() async {
    try {
      final dir = await _getClearBackupDir();
      if (!await dir.exists()) return null;
      final files = (await dir.list().toList()).whereType<File>().where((f) => p.basename(f.path).startsWith(_clearBackupPrefix)).toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      if (files.isEmpty) return null;
      final latest = files.first;
      final stat = await latest.stat();
      final age = DateTime.now().difference(stat.modified);
      if (age.inDays >= _clearBackupRetentionDays) {
        await purgeExpiredClearBackups();
        // po purge zkusit znovu - pokud nejnovější expiroval, je smazán
        final remaining = (await dir.list().toList()).whereType<File>().where((f) => p.basename(f.path).startsWith(_clearBackupPrefix)).toList()
          ..sort((a, b) => b.path.compareTo(a.path));
        if (remaining.isEmpty) return null;
        // vrátit nový nejnovější (už v limitu)
        final content = await remaining.first.readAsString(encoding: utf8);
        return jsonDecode(content) as Map<String, dynamic>;
      }
      final content = await latest.readAsString(encoding: utf8);
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<File?> getLastClearBackupFile() async {
    try {
      final dir = await _getClearBackupDir();
      if (!await dir.exists()) return null;
      final files = (await dir.list().toList()).whereType<File>().where((f) => p.basename(f.path).startsWith(_clearBackupPrefix)).toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      if (files.isEmpty) return null;
      final stat = await files.first.stat();
      if (DateTime.now().difference(stat.modified).inDays >= _clearBackupRetentionDays) return null;
      return files.first;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteLastClearBackup() async {
    try {
      final f = await getLastClearBackupFile();
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> purgeExpiredClearBackups() async {
    try {
      final dir = await _getClearBackupDir();
      if (!await dir.exists()) return;
      final files = (await dir.list().toList()).whereType<File>().where((f) => p.basename(f.path).startsWith(_clearBackupPrefix)).toList();
      for (final f in files) {
        try {
          final stat = await f.stat();
          if (DateTime.now().difference(stat.modified).inDays >= _clearBackupRetentionDays) {
            await f.delete();
          }
        } catch (_) {}
      }
    } catch (_) {}
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));

    if (Platform.isAndroid) {
      sqlite3.tempDirectory = dbFolder.path;
    }

    return NativeDatabase(file);
  });
}
