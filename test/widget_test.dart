import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:posouvac_textu/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Song doplní neznámého interpreta u starého JSONu', () {
    final song = Song.fromJson({'title': 'Test', 'content': 'Text'});

    expect(song.artist, Song.unknownArtist);
    expect(song.toJson()['artist'], Song.unknownArtist);
  });

  test('Song rozpozná interpreta a název z importovaného souboru', () {
    final song = Song.fromImportedTextFile(
      fileName: 'Ellie - Párty v domě hrůzy.txt',
      content: 'Text písně',
    );

    expect(song.artist, 'Ellie');
    expect(song.title, 'Párty v domě hrůzy');
  });

  test('Song ponechá celý název souboru, když neobsahuje oddělovač', () {
    final song = Song.fromImportedTextFile(
      fileName: 'Samostatný název.txt',
      content: 'Text písně',
    );

    expect(song.artist, Song.unknownArtist);
    expect(song.title, 'Samostatný název');
  });

  testWidgets('Aplikace načte píseň a zobrazí tlačítko Spustit', (
    WidgetTester tester,
  ) async {
    final longText = List.filled(80, 'První řádek').join('\n');

    SharedPreferences.setMockInitialValues({
      'playlist': [
        jsonEncode({
          'title': 'Testovací píseň',
          'content': longText,
          'artist': 'Testovací interpret',
        }),
      ],
      'currentSongIndex': 0,
      'defaultStartDelay': 0,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(LyricScrollerApp(prefs: prefs));
    await tester.pump();

    expect(find.text('Testovací píseň'), findsOneWidget);
    expect(find.text('Spustit'), findsOneWidget);

    await tester.tap(find.text('Spustit'));
    await tester.pump();

    expect(find.text('Zastavit'), findsOneWidget);
  });
}
