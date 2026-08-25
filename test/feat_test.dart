import 'package:flutter_test/flutter_test.dart';
import 'package:posouvac_textu/database.dart';

void main() {
  test('feat diacritic repairs', () async {
    final db = AppDatabase.forTesting();
    // Seed slovnik
    final csv = '''
bezDiakritiky,sDiakritikou
Ivan Mladek,Ivan Mládek
Ludek Sobota,Luděk Sobota
Rychlik jede do Prahy,Rychlík jede do Prahy
''';
    final res = await db.importDiacriticCsv(csv);
    expect(res.imported, 3);
    expect(res.skipped, 0);

    // lookup artist with feat paren
    final a1 = await db.lookupDiacritic('Ivan Mladek (feat. Ludek Sobota)');
    expect(a1, 'Ivan Mládek (feat. Luděk Sobota)');
    final a2 = await db.lookupDiacritic('Ivan Mladek feat. Ludek Sobota');
    expect(a2, 'Ivan Mládek feat. Luděk Sobota');
    final a3 = await db.lookupDiacritic('Ivan Mladek ft. Ludek Sobota');
    expect(a3, 'Ivan Mládek ft. Luděk Sobota');
    final t1 = await db.lookupDiacritic('Rychlik jede do Prahy');
    expect(t1, 'Rychlík jede do Prahy');

    // insert song with wrong diacritics and check findDiacriticRepairs
    await db.into(db.songs).insert(SongsCompanion.insert(
      filePath: '/tmp/a.txt',
      artist: 'Ivan Mladek (feat. Ludek Sobota)',
      title: 'Rychlik jede do Prahy',
    ));
    final reps = await db.findDiacriticRepairs();
    expect(reps.length, 1);
    expect(reps.first.newArtist, 'Ivan Mládek (feat. Luděk Sobota)');
    expect(reps.first.newTitle, 'Rychlík jede do Prahy');

    await db.close();
  });

  test('vypis vsech - 23 -> 21', () async {
    final db = AppDatabase.forTesting();
    final csv = '''
bezDiakritiky,sDiakritikou
Ivan Mladek,Ivan Mládek
Ludek Sobota,Luděk Sobota
Rychlik jede do Prahy,Rychlík jede do Prahy
''';
    await db.importDiacriticCsv(csv);
    // 3 pisne: 1 opravitelna, 1 uz spravne, 1 chybi ve slovniku
    await db.into(db.songs).insert(SongsCompanion.insert(filePath: '/tmp/1.txt', artist: 'Ivan Mladek', title: 'Rychlik jede do Prahy'));
    await db.into(db.songs).insert(SongsCompanion.insert(filePath: '/tmp/2.txt', artist: 'Ivan Mládek', title: 'Rychlík jede do Prahy'));
    await db.into(db.songs).insert(SongsCompanion.insert(filePath: '/tmp/3.txt', artist: 'Neznamy Interpret', title: 'Neznama Pisnicka'));
    final reps = await db.findDiacriticRepairs();
    expect(reps.length, 1);
    final unrepaired = await db.getDiacriticUnrepairedWithReason();
    expect(unrepaired.length, 2);
    final reasons = unrepaired.map((e) => e.reason).toSet();
    expect(reasons.contains('alreadyCorrect'), true);
    expect(reasons.contains('missingInMap'), true);
    await db.close();
  });
}
