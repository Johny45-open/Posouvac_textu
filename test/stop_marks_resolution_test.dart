import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:posouvac_textu/chord_pro_parser.dart';
import 'package:posouvac_textu/database.dart';
import 'package:posouvac_textu/player_page.dart';

/// Regresní testy deduplikace cílů pauz (etapa B3, nálezy F-02 a F-08).
///
/// Pravidlo: jedna logická zarážka (direktiva {stop:N} v textu a/nebo
/// databázový záznam pro tutéž pozici) smí vytvořit právě jeden cíl pauzy.
///
/// Důležité – vintáže dat (prostor `orderedLines` = „dirty“, včetně řádků pauz):
///  * telefon-native DB záznam: lineIndex = dirty index řádku, lineText = jeho text;
///  * starý PC export (před B1): lineIndex = index DIRECTIVY v dirty prostoru,
///    lineText = text NÁSLEDUJÍCÍHO řádku;
///  * nový PC export (po B1): lineIndex = index cílového řádku v CLEAN prostoru
///    (bez direktiv), lineText = text tohoto řádku.
///
/// Testy volají přímo produkční funkce `buildStopMarkTargets` a
/// `resolveStopMarkAnchor` z player_page.dart.

StopMark _db(
  int id, {
  int? lineIndex,
  String? lineText,
  int bars = 2,
  double ratio = 0.0,
}) =>
    StopMark(
      id: id,
      songId: 1,
      positionRatio: ratio,
      durationBars: bars,
      lineIndex: lineIndex,
      lineText: lineText,
    );

/// Načte zarážky z reprezentativního JSON dokumentu PC exportu v3 tak, jak
/// to dělá produkční import v database.dart (syncPlaylistFromJson): mapování
/// polí {lineText, lineIndex, bars} → StopMark(lineIndex, lineText,
/// durationBars) se zrcadlí zde, protože přímé volání produkčního importu
/// vyžaduje inicializaci testovacího bindingu a databázového driveru
/// (omezení testové úrovně – viz zpráva k etapě B3).
List<StopMark> _marksFromPackageJson(String packageJson) {
  final doc = jsonDecode(packageJson) as Map<String, dynamic>;
  final songs = (doc['songs'] as List).cast<Map<String, dynamic>>();
  final raw = (songs.first['stopMarks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  var id = 0;
  return [
    for (final m in raw)
      StopMark(
        id: ++id,
        songId: 1,
        positionRatio: 0,
        durationBars: ((m['bars'] as int?) ?? 2).clamp(1, 16).toInt(),
        lineIndex: m['lineIndex'] is int
            ? m['lineIndex'] as int
            : int.tryParse(m['lineIndex']?.toString() ?? ''),
        lineText: ((m['lineText'] ?? '').toString().isEmpty)
            ? null
            : (m['lineText'] ?? '').toString(),
      ),
  ];
}

void main() {
  group('T-4A direktiva v textu + odpovídající DB záznam → 1 cíl pauzy', () {
    // dirty: [A(0), Pauza(1), B(2), C(3), D(4)]
    const content = 'A\n{stop:2}\nB\nC\nD';

    test('nový export po B1 (clean lineIndex=1, text=B) → právě 1 cíl', () {
      final targets = buildStopMarkTargets(
        content: content,
        dbMarks: [_db(1, lineIndex: 1, lineText: 'B', bars: 2)],
      );
      expect(targets, hasLength(1), reason: 'jedna logická zarážka = jedna pauza');
      final t = targets.single;
      expect(t.fromDirective, isTrue, reason: 'pozici určuje direktiva');
      expect(t.lineIndex, 1, reason: 'spouštěcím řádkem je řádek direktivy (jako dřív)');
      expect(t.bars, 2, reason: 'délka pauzy v taktech zůstává 2');
      expect(t.visualAnchor, 2, reason: 'ikona kotvy na textovém řádku B');
      expect(t.dbMark, isNotNull, reason: 'DB záznam zůstává navázán pro správu pauz');
    });

    test('starý export před B1 (lineIndex=direktiva, text=B) → právě 1 cíl', () {
      // Starý export měl lineIndex = pozice direktivy; u jediné direktivy
      // shodná s novým, ale textová kontrola vede přes unikátní text.
      final targets = buildStopMarkTargets(
        content: content,
        dbMarks: [_db(1, lineIndex: 1, lineText: 'B', bars: 2)],
      );
      expect(targets, hasLength(1));
    });

    test('starý export bez lineText (jen lineIndex=direktiva) → 1 cíl', () {
      final targets = buildStopMarkTargets(
        content: content,
        dbMarks: [_db(1, lineIndex: 1, bars: 2)],
      );
      expect(targets, hasLength(1));
      expect(targets.single.lineIndex, 1);
    });

    test('telefon-native záznam na řádku direktivy → 1 cíl', () {
      // Uživatel přidal pauzu právě na řádek, kde už direktiva stojí.
      final targets = buildStopMarkTargets(
        content: content,
        dbMarks: [_db(1, lineIndex: 1, lineText: 'Pauza', bars: 2)],
      );
      expect(targets, hasLength(1));
    });

    test('při konfliktu délek vítězí direktiva v textu', () {
      // PC regeneruje direktivy ze svého seznamu zarážek – obsah souboru
      // je kanonický. DB záznam se nemaže, jen se neslučuje druhá pauza.
      final targets = buildStopMarkTargets(
        content: content,
        dbMarks: [_db(1, lineIndex: 2, lineText: 'B', bars: 5)],
      );
      expect(targets, hasLength(1));
      expect(targets.single.bars, 2, reason: 'direktiva {stop:2} má přednost');
    });
  });

  group('T-4B pouze textová direktiva', () {
    test('právě 1 cíl na řádku direktivy, bez DB záznamu', () {
      final targets = buildStopMarkTargets(
        content: 'A\n{stop:2}\nB\nC\nD',
        dbMarks: const [],
      );
      expect(targets, hasLength(1));
      final t = targets.single;
      expect(t.fromDirective, isTrue);
      expect(t.lineIndex, 1, reason: 'spouštěcí řádek = řádek direktivy');
      expect(t.bars, 2);
      expect(t.dbMark, isNull);
    });
  });

  group('T-4C pouze databázová zarážka', () {
    test('řádková kotva (telefon-native) → 1 cíl na správném řádku', () {
      final targets = buildStopMarkTargets(
        content: 'A\nB\nC\nD',
        dbMarks: [_db(1, lineIndex: 1, lineText: 'B', bars: 4)],
      );
      expect(targets, hasLength(1));
      final t = targets.single;
      expect(t.fromDirective, isFalse);
      expect(t.lineIndex, 1, reason: 'kotva na řádku B');
      expect(t.bars, 4, reason: 'délka pauzy z DB zůstává 4 takty');
      expect(t.ratio, isNull);
      expect(t.visualAnchor, 1);
    });

    test('procentová kotva (bez textu i indexu) → cíl přes ratio', () {
      final targets = buildStopMarkTargets(
        content: 'A\nB\nC\nD',
        dbMarks: [_db(1, ratio: 0.5, bars: 3)],
      );
      expect(targets, hasLength(1));
      expect(targets.single.ratio, 0.5);
      expect(targets.single.lineIndex, isNull);
      expect(targets.single.bars, 3);
    });
  });

  group('T-4D různé zarážky → každá přesně jednou', () {
    test('dvě odlišné zarážky (directiva i DB) → 2 cíle na správných řádcích', () {
      // dirty: [A(0), Pauza(1), B(2), C(3), Pauza(4), D(5)]
      // clean (nový export): [A(0), B(1), C(2), D(3)]
      const content = 'A\n{stop:2}\nB\nC\n{stop:4}\nD';
      final targets = buildStopMarkTargets(
        content: content,
        dbMarks: [
          _db(1, lineIndex: 1, lineText: 'B', bars: 2), // nový vintáž: clean 1
          _db(2, lineIndex: 3, lineText: 'D', bars: 4), // nový vintáž: clean 3
        ],
      );
      expect(targets, hasLength(2), reason: 'dvě logické zarážky = dvě pauzy');
      expect(targets[0].lineIndex, 1);
      expect(targets[0].bars, 2);
      expect(targets[1].lineIndex, 4);
      expect(targets[1].bars, 4);
      expect(targets.every((t) => t.dbMark != null), isTrue, reason: 'oba DB záznamy navázány');
    });

    test('řádková DB zarážka bez direktivy + direktiva bez záznamu → 2 cíle', () {
      final targets = buildStopMarkTargets(
        content: 'A\n{stop:2}\nB\nC',
        dbMarks: [_db(1, lineIndex: 3, lineText: 'C', bars: 6)],
      );
      expect(targets, hasLength(2));
      expect(targets[0].lineIndex, 1, reason: 'direktiva na řádku 1');
      expect(targets[1].lineIndex, 3, reason: 'DB zarážka na řádku C');
      expect(targets[1].bars, 6);
    });
  });

  group('T-4E opakované řádky', () {
    // dirty: [Refrén(0), Pauza(1), Refrén(2), A(3), Refrén(4)]
    const content = 'Refrén\n{stop:2}\nRefrén\nA\nRefrén';

    test('nejednoznačná kotva se nepřesune na první shodu, pauza zůstává na direktivě', () {
      final warnings = <String>[];
      final targets = buildStopMarkTargets(
        content: content,
        dbMarks: [_db(1, lineIndex: 1, lineText: 'Refrén', bars: 2)],
        onWarning: warnings.add,
      );
      expect(targets, hasLength(1), reason: 'bez dvojité pauzy');
      final t = targets.single;
      expect(t.fromDirective, isTrue);
      expect(t.lineIndex, 1);
      expect(t.visualAnchor, 2,
          reason: 'ikona na DRUHÉM výskytu (za direktivou), ne na prvním');
      expect(warnings, hasLength(1), reason: 'nejednoznačnost je zaznamenána');
    });

    test('telefon-native záznam s platným indexem se spáruje s direktivou', () {
      final targets = buildStopMarkTargets(
        content: content,
        dbMarks: [_db(1, lineIndex: 2, lineText: 'Refrén', bars: 2)],
      );
      expect(targets, hasLength(1), reason: 'tutéž pozice už direktiva spouští');
      expect(targets.single.lineIndex, 1);
    });

    test('skutečně odlišná zarážka na třetím výskytu zůstává samostatná', () {
      final targets = buildStopMarkTargets(
        content: content,
        dbMarks: [_db(1, lineIndex: 4, lineText: 'Refrén', bars: 3)],
      );
      expect(targets, hasLength(2));
      expect(targets[0].lineIndex, 1, reason: 'direktiva před druhým výskytem');
      expect(targets[1].lineIndex, 4, reason: 'DB zarážka před třetím výskytem');
      expect(targets[1].bars, 3);
    });
  });

  group('T-4F starší export v3 (před B1) – lineIndex = index direktivy', () {
    // Reprezentativní dokument PC exportu v3 vytvořený PŘED opravou B1:
    // starý extract_stop_marks_from_content ukládal lineIndex = index
    // DIRECTIVY v prostoru ordered_lines (dirty, vč. řádků pauz, 0-based)
    // a lineText = první textový řádek za direktivou (ověřeno proti HEAD
    // verzi playlist_backend.py).
    const packageJson = r'''
{
  "type": "playlist",
  "version": 3,
  "name": "Setlist – starý export",
  "exportedAt": "2026-05-10T12:00:00+00:00",
  "totalDuration": 240,
  "unknownCount": 0,
  "songs": [
    {
      "title": "Píseň",
      "artist": "Autor",
      "duration": 120,
      "tempo": 120,
      "content": "Verse\n{stop:2}\nRefrén\n{stop:4}\nKonec",
      "stopMarks": [
        {"lineText": "Refrén", "lineIndex": 1, "bars": 2},
        {"lineText": "Konec", "lineIndex": 3, "bars": 4}
      ]
    }
  ]
}
''';
    // dirty: [Verse(0), Pauza(1), Refrén(2), Pauza(3), Konec(4)]

    test('zachová se zamýšlená pozice a nevznikne dvojitá pauza', () {
      final marks = _marksFromPackageJson(packageJson);
      expect(marks, hasLength(2), reason: 'JSON obsahuje 2 zarážky');

      final targets = buildStopMarkTargets(
        content: jsonDecode(packageJson)['songs'][0]['content'] as String,
        dbMarks: marks,
      );
      expect(targets, hasLength(2),
          reason: 'dvě logické zarážky = dvě pauzy, ne čtyři');
      expect(targets[0].lineIndex, 1, reason: 'pauza před „Refrén“ (řádek direktivy)');
      expect(targets[0].visualAnchor, 2);
      expect(targets[0].bars, 2);
      expect(targets[1].lineIndex, 3, reason: 'pauza před „Konec“ (řádek direktivy)');
      expect(targets[1].visualAnchor, 4);
      expect(targets[1].bars, 4);
      expect(targets.map((t) => t.dbMark?.id), [1, 2],
          reason: 'oba DB záznamy navázány (správa pauz funguje)');
    });
  });

  group('T-4G nový export po B1 – lineIndex = čistý index řádku', () {
    // Reprezentativní dokument PC exportu v3 vytvořený PO opravě B1:
    // nový extract_stop_marks_from_content ukládá lineIndex = index cílového
    // řádku v CLEAN prostoru (bez direktiv; playlist_backend.py: „lineIndex:
    // clean_count“) a lineText = text tohoto řádku. Soubor textu je shodný
    // jako v T-4F, liší se jen význam lineIndex.
    const packageJson = r'''
{
  "type": "playlist",
  "version": 3,
  "name": "Setlist – nový export",
  "exportedAt": "2026-10-17T12:00:00+00:00",
  "totalDuration": 240,
  "unknownCount": 0,
  "songs": [
    {
      "title": "Píseň",
      "artist": "Autor",
      "duration": 120,
      "tempo": 120,
      "content": "Verse\n{stop:2}\nRefrén\n{stop:4}\nKonec",
      "stopMarks": [
        {"lineText": "Refrén", "lineIndex": 1, "bars": 2},
        {"lineText": "Konec", "lineIndex": 2, "bars": 4}
      ]
    }
  ]
}
''';
    // clean: [Verse(0), Refrén(1), Konec(2)]

    test('správná pozice a právě jeden cíl na zarážku', () {
      final marks = _marksFromPackageJson(packageJson);
      expect(marks.map((m) => m.lineIndex), [1, 2],
          reason: 'nový export používá čisté indexy');

      final targets = buildStopMarkTargets(
        content: jsonDecode(packageJson)['songs'][0]['content'] as String,
        dbMarks: marks,
      );
      expect(targets, hasLength(2));
      expect(targets[0].lineIndex, 1);
      expect(targets[0].bars, 2);
      expect(targets[1].lineIndex, 3);
      expect(targets[1].bars, 4);
      expect(targets.map((t) => t.dbMark?.id), [1, 2], reason: 'oba záznamy navázány');
    });

    test('starý i nový export dávají totožný výsledek', () {
      const oldJson = r'''
{"type":"playlist","version":3,"songs":[{"content":"Verse\n{stop:2}\nRefrén\n{stop:4}\nKonec","stopMarks":[{"lineText":"Refrén","lineIndex":1,"bars":2},{"lineText":"Konec","lineIndex":3,"bars":4}]}]}
''';
      const newJson = r'''
{"type":"playlist","version":3,"songs":[{"content":"Verse\n{stop:2}\nRefrén\n{stop:4}\nKonec","stopMarks":[{"lineText":"Refrén","lineIndex":1,"bars":2},{"lineText":"Konec","lineIndex":2,"bars":4}]}]}
''';
      final content =
          jsonDecode(newJson)['songs'][0]['content'] as String;
      List<List<Object?>> sig(List<StopMarkTarget> ts) => [
            for (final t in ts) [t.lineIndex, t.bars, t.visualAnchor, t.fromDirective],
          ];
      final old = buildStopMarkTargets(
          content: content, dbMarks: _marksFromPackageJson(oldJson));
      final neu = buildStopMarkTargets(
          content: content, dbMarks: _marksFromPackageJson(newJson));
      expect(sig(neu), sig(old),
          reason: 'kompatibilita starých i nových v3 exportů po B1');
    });
  });

  group('T-4H idempotence a determinismus', () {
    test('opakované rozřešení stejných dat je totožné', () {
      const content = 'Verse\n{stop:2}\nRefrén\n{stop:4}\nKonec';
      final marks = [
        _db(1, lineIndex: 1, lineText: 'Refrén', bars: 2),
        _db(2, lineIndex: 2, lineText: 'Konec', bars: 4),
      ];
      List<List<Object?>> sig(List<StopMarkTarget> ts) => [
            for (final t in ts) [t.lineIndex, t.bars, t.visualAnchor, t.fromDirective, t.dbMark?.id],
          ];
      final a = buildStopMarkTargets(content: content, dbMarks: marks);
      final b = buildStopMarkTargets(content: content, dbMarks: marks);
      expect(sig(b), sig(a), reason: 'deterministický výsledek');
      expect(a, hasLength(2), reason: 'opakování netvoří další cíle');
    });

    test('T-4H prázdné řádky a direktivy {c:...}, {soc}, {eoc}', () {
      // {soc}/{eoc} a prázdné řádky nevstupují do prostoru řádků.
      // dirty: [Verše(0), pozn(1), Pauza(2), Refrén(3), Konec(4)]
      // clean: [Verše(0), pozn(1), Refrén(2), Konec(3)]
      const content =
          '{soc}\nVerše jedou\n\n{c:pozn}\n{stop:2}\nRefrén\n{eoc}\nKonec';
      final targets = buildStopMarkTargets(
        content: content,
        dbMarks: [_db(1, lineIndex: 2, lineText: 'Refrén', bars: 2)],
      );
      expect(targets, hasLength(1), reason: 'pauza jen jednou');
      expect(targets.single.lineIndex, 2, reason: 'řádek direktivy (po komentáři)');
      expect(targets.single.visualAnchor, 3, reason: 'ikona na řádku Refrén');
    });
  });

  group('T-4I chybějící a nejednoznačná kotva – žádné svévolné přemístění', () {
    test('kotva míří na neexistující text → žádný cíl, žádná pauza na začátku', () {
      final warnings = <String>[];
      final targets = buildStopMarkTargets(
        content: 'A\nB\nC',
        dbMarks: [_db(1, lineIndex: 99, lineText: 'Neexistuje', bars: 2)],
        onWarning: warnings.add,
      );
      expect(targets, isEmpty, reason: 'bez cíle, ne pauza na začátku (ratio 0)');
      expect(warnings, hasLength(1));
    });

    test('index v rozsahu, ale text nesedí a nikde neexistuje → bez cíle', () {
      // Dříve by zarážka skončila na náhodném (uloženém) indexu.
      final targets = buildStopMarkTargets(
        content: 'A\nB\nC',
        dbMarks: [_db(1, lineIndex: 0, lineText: 'X', bars: 2)],
      );
      expect(targets, isEmpty);
    });

    test('nejednoznačný text bez direktivy → bez cíle, ne první shoda', () {
      final warnings = <String>[];
      final targets = buildStopMarkTargets(
        content: 'R\nA\nR\nB\nR',
        dbMarks: [_db(1, lineIndex: 9, lineText: 'R', bars: 2)],
        onWarning: warnings.add,
      );
      expect(targets, isEmpty, reason: 'nepřesouvá se na první „R“');
      expect(warnings.single, contains('nejednoznačný'));
    });

    test('resolveStopMarkAnchor rozliší všechny čtyři stavy', () {
      final lines = ChordProParser.orderedLines('A\n{stop:2}\nB\nB');
      // platný index + shodný text
      expect(
        resolveStopMarkAnchor(lineIndex: 2, lineText: 'B', lines: lines).kind,
        StopMarkAnchorKind.resolved,
      );
      // jen procento
      expect(
        resolveStopMarkAnchor(lineIndex: null, lineText: null, lines: lines).kind,
        StopMarkAnchorKind.byRatio,
      );
      // unikátní text jako záloha
      final r = resolveStopMarkAnchor(lineIndex: 99, lineText: 'A', lines: lines);
      expect(r.kind, StopMarkAnchorKind.resolved);
      expect(r.index, 0);
      // nejednoznačný text
      expect(
        resolveStopMarkAnchor(lineIndex: 99, lineText: 'B', lines: lines).kind,
        StopMarkAnchorKind.unresolvedAmbiguous,
      );
      // neexistující text
      expect(
        resolveStopMarkAnchor(lineIndex: null, lineText: 'X', lines: lines).kind,
        StopMarkAnchorKind.unresolvedMissing,
      );
    });
  });
}
